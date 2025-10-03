#!/usr/bin/env julia
"""
JobQueue.jl - TOML-driven job execution system for JMake daemons

This is the conductor that:
1. Reads job definitions from TOML
2. Resolves dependencies (DAG)
3. Dispatches to daemons via DaemonMode
4. Tracks state in ConfigurationManager
5. Persists progress to disk

Integration: ConfigurationManager → JobQueue → Daemons → ConfigurationManager
"""

module JobQueue

using TOML
using Dates
using DaemonMode

# Import ConfigurationManager for state management
include("ConfigurationManager.jl")
using .ConfigurationManager

export Job, JobQueueManager, load_jobs, execute_job_queue, job_status

# Job structure
mutable struct Job
    id::String
    type::Symbol
    daemon::String
    port::Int
    priority::Int
    status::Symbol  # :pending, :running, :completed, :failed
    depends_on::Vector{String}
    target_section::String  # Where to write result in TOML
    callback::String
    args::Dict{String,Any}
    result::Any
    error::Union{String,Nothing}
    started_at::Union{DateTime,Nothing}
    completed_at::Union{DateTime,Nothing}
end

# Job queue manager
mutable struct JobQueueManager
    jobs::Dict{String,Job}
    config::ConfigurationManager.JMakeConfig
    job_file::String
    state_file::String
end

"""
Load jobs from TOML file
"""
function load_jobs(job_file::String, config::ConfigurationManager.JMakeConfig)
    job_toml = TOML.parsefile(job_file)
    jobs = Dict{String,Job}()

    if !haskey(job_toml, "jobs")
        @warn "No jobs defined in $job_file"
        return JobQueueManager(jobs, config, job_file, "")
    end

    for job_def in job_toml["jobs"]
        job = Job(
            job_def["id"],
            Symbol(job_def["type"]),
            job_def["daemon"],
            job_def["port"],
            get(job_def, "priority", 5),
            Symbol(get(job_def, "status", "pending")),
            get(job_def, "depends_on", String[]),
            job_def["target_section"],
            job_def["callback"],
            get(job_def, "args", Dict()),
            nothing,
            nothing,
            nothing,
            nothing
        )
        jobs[job.id] = job
    end

    state_file = joinpath(dirname(config.config_file), ".jmake_cache", "job_state.toml")

    JobQueueManager(jobs, config, job_file, state_file)
end

"""
Resolve template variables in job args (e.g., {{project.root}})
"""
function resolve_templates(args::Dict, config::ConfigurationManager.JMakeConfig)
    resolved = copy(args)

    for (key, value) in resolved
        if value isa String && occursin("{{", value)
            # Parse template: {{section.field}}
            template = match(r"\{\{(.+?)\}\}", value)
            if !isnothing(template)
                path = split(template.captures[1], ".")

                # Resolve from config
                if length(path) == 2
                    section = path[1]
                    field = path[2]

                    if section == "project"
                        if field == "root"
                            resolved[key] = config.project_root
                        elseif field == "name"
                            resolved[key] = config.project_name
                        end
                    elseif section == "config"
                        if field == "path"
                            resolved[key] = config.config_file
                        end
                    else
                        # Get from stage config
                        stage_config = ConfigurationManager.get_stage_config(config, Symbol(section))
                        if haskey(stage_config, field)
                            resolved[key] = stage_config[field]
                        end
                    end
                end
            end
        end
    end

    return resolved
end

"""
Execute job on daemon
"""
function execute_job(job::Job, manager::JobQueueManager)
    println("\n[JOB] $(job.id)")
    println("  Type: $(job.type)")
    println("  Daemon: $(job.daemon) (port $(job.port))")
    println("  Callback: $(job.callback)")

    job.status = :running
    job.started_at = now()

    try
        # Resolve template variables
        args = resolve_templates(job.args, manager.config)

        # Build daemon command that writes to ConfigurationManager
        # Daemons write results to config, so we just need to trigger execution
        args_str = string(Dict(args))
        cmd_call = "$(job.callback)($(args_str))"

        # Wrap command to import JMake and save to config
        cmd = """
        push!(LOAD_PATH, "/home/grim/.julia/julia/JMake/src")
        include("/home/grim/.julia/julia/JMake/src/ConfigurationManager.jl")
        using .ConfigurationManager

        # Load config
        config = ConfigurationManager.load_config("$(manager.config.config_file)")

        # Execute daemon function
        result = $cmd_call

        # Write result to config if daemon didn't already
        if result isa Dict && haskey(result, :success) && result[:success]
            section_parts = split("$(job.target_section)", ".")
            if length(section_parts) == 2
                section = section_parts[1]
                field = section_parts[2]

                value = if haskey(result, :results)
                    result[:results]
                elseif haskey(result, :tools)
                    result[:tools]
                elseif haskey(result, :output)
                    result[:output]
                elseif haskey(result, :created_dirs)
                    first(result[:created_dirs], "build/ir")
                else
                    result
                end

                if section == "discovery"
                    config.discovery[field] = value
                elseif section == "compile"
                    config.compile[field] = value
                elseif section == "llvm"
                    config.llvm[field] = value
                elseif section == "binary"
                    config.binary[field] = value
                end

                ConfigurationManager.save_config(config)
            end
        end

        result
        """

        println("  Executing daemon job...")

        # Call daemon via DaemonMode (fire and forget - daemon handles persistence)
        runexpr(cmd, port=job.port)

        # Reload config to see what daemon wrote
        sleep(0.5)  # Give daemon time to write
        updated_config = ConfigurationManager.load_config(manager.config.config_file)

        # Check if target section was populated
        section_parts = split(job.target_section, ".")
        if length(section_parts) == 2
            section_name = section_parts[1]
            field_name = section_parts[2]

            section_dict = if section_name == "discovery"
                updated_config.discovery
            elseif section_name == "compile"
                updated_config.compile
            elseif section_name == "llvm"
                updated_config.llvm
            elseif section_name == "binary"
                updated_config.binary
            else
                Dict()
            end

            if haskey(section_dict, field_name) && !isempty(get(section_dict, field_name, ""))
                job.status = :completed
                job.result = section_dict[field_name]
                job.completed_at = now()

                # Update our config reference
                manager.config = updated_config

                println("  ✅ Completed in $(job.completed_at - job.started_at)")
                println("  💾 Result written to: $(job.target_section)")
            else
                job.status = :failed
                job.error = "Daemon executed but target section not populated"
                job.completed_at = now()
                println("  ❌ Failed: $(job.error)")
            end
        else
            job.status = :failed
            job.error = "Invalid target section format"
            job.completed_at = now()
            println("  ❌ Failed: $(job.error)")
        end

    catch e
        job.status = :failed
        job.error = string(e)
        job.completed_at = now()
        println("  ❌ Error: $e")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
    end

    # Save state
    save_state(manager)
end

"""
Write job result to ConfigurationManager
"""
function write_result_to_config!(manager::JobQueueManager, job::Job, result::Dict)
    section_path = split(job.target_section, ".")

    if length(section_path) != 2
        @warn "Invalid target section: $(job.target_section)"
        return
    end

    section = section_path[1]
    field = section_path[2]

    # Determine what to write
    value = if haskey(result, :results)
        result[:results]
    elseif haskey(result, :tools)
        result[:tools]
    elseif haskey(result, :output)
        result[:output]
    else
        result
    end

    # Write to appropriate section
    if section == "discovery"
        manager.config.discovery[field] = value
    elseif section == "compile"
        manager.config.compile[field] = value
    elseif section == "link"
        manager.config.link[field] = value
    elseif section == "binary"
        manager.config.binary[field] = value
    elseif section == "llvm"
        manager.config.llvm[field] = value
    end

    # Save config
    ConfigurationManager.save_config(manager.config)

    println("  💾 Saved to: $(job.target_section)")
end

"""
Execute job queue with dependency resolution
"""
function execute_job_queue(manager::JobQueueManager)
    println("="^70)
    println("JMake Job Queue - Executing $(length(manager.jobs)) jobs")
    println("="^70)

    # Topological sort by dependencies
    sorted_jobs = topological_sort(manager)

    println("\nExecution order ($(length(sorted_jobs)) jobs):")
    for (i, job) in enumerate(sorted_jobs)
        deps_str = isempty(job.depends_on) ? "none" : join(job.depends_on, ", ")
        println("  $i. $(job.id) (depends on: $deps_str)")
    end

    # Execute in order
    for job in sorted_jobs
        # Check dependencies
        deps_ready = all(manager.jobs[dep_id].status == :completed for dep_id in job.depends_on)

        if !deps_ready
            println("\n[SKIP] $(job.id) - dependencies not ready")
            job.status = :failed
            job.error = "Dependency failed"
            continue
        end

        # Execute job
        execute_job(job, manager)
    end

    # Print summary
    print_summary(manager)
end

"""
Topological sort for dependency resolution
"""
function topological_sort(manager::JobQueueManager)
    sorted = Job[]
    visited = Set{String}()

    function visit(job_id::String)
        if job_id in visited
            return
        end

        job = manager.jobs[job_id]

        # Visit dependencies first
        for dep_id in job.depends_on
            if haskey(manager.jobs, dep_id)
                visit(dep_id)
            end
        end

        push!(visited, job_id)
        push!(sorted, job)
    end

    # Sort by priority first
    priority_order = sort(collect(values(manager.jobs)), by = j -> -j.priority)

    for job in priority_order
        visit(job.id)
    end

    return sorted
end

"""
Save job queue state to disk
"""
function save_state(manager::JobQueueManager)
    mkpath(dirname(manager.state_file))

    state = Dict(
        "jobs" => [
            begin
                job_dict = Dict(
                    "id" => job.id,
                    "status" => string(job.status)
                )

                # Only add non-nothing values
                if !isnothing(job.error)
                    job_dict["error"] = job.error
                end
                if !isnothing(job.started_at)
                    job_dict["started_at"] = string(job.started_at)
                end
                if !isnothing(job.completed_at)
                    job_dict["completed_at"] = string(job.completed_at)
                end
                # Note: result is not serialized to avoid complex types

                job_dict
            end
            for job in values(manager.jobs)
        ]
    )

    open(manager.state_file, "w") do io
        TOML.print(io, state)
    end
end

"""
Print job execution summary
"""
function print_summary(manager::JobQueueManager)
    println("\n" * "="^70)
    println("Job Queue Summary")
    println("="^70)

    completed = count(j -> j.status == :completed, values(manager.jobs))
    failed = count(j -> j.status == :failed, values(manager.jobs))
    pending = count(j -> j.status == :pending, values(manager.jobs))

    println("Total jobs: $(length(manager.jobs))")
    println("✅ Completed: $completed")
    println("❌ Failed: $failed")
    println("⏳ Pending: $pending")

    if failed > 0
        println("\nFailed jobs:")
        for job in values(manager.jobs)
            if job.status == :failed
                println("  • $(job.id): $(job.error)")
            end
        end
    end

    println("="^70)
end

"""
Get job status
"""
function job_status(manager::JobQueueManager, job_id::String)
    if haskey(manager.jobs, job_id)
        job = manager.jobs[job_id]
        return Dict(
            "id" => job.id,
            "status" => string(job.status),
            "type" => string(job.type),
            "result" => job.result,
            "error" => job.error
        )
    else
        return Dict("error" => "Job not found: $job_id")
    end
end

end # module JobQueue
