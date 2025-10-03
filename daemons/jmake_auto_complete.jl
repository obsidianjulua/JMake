#!/usr/bin/env julia
"""
JMake Auto-Complete - Queue TOML jobs to daemons

Usage:
    julia jmake_auto_complete.jl path/to/jmake.toml

Flow:
    1. Analyze TOML for missing fields
    2. Queue jobs to appropriate daemons
    3. Daemons execute jobs and fill TOML
    4. Return completed TOML
"""

using DaemonMode
using TOML

const DAEMON_PORTS = Dict(
    "discovery" => 3001,
    "setup" => 3002,
    "compilation" => 3003,
    "orchestrator" => 3004
)

"""
Analyze TOML and create job queue
"""
function analyze_toml_for_jobs(toml_path::String)
    toml = TOML.parsefile(toml_path)
    jobs = []

    println("📋 Analyzing TOML: $toml_path")
    println("="^70)

    # Check discovery section
    if haskey(toml, "discovery")
        disc = toml["discovery"]

        if !haskey(disc, "files") || isempty(get(disc, "files", Dict()))
            push!(jobs, Dict(
                "daemon" => "discovery",
                "type" => "scan_files",
                "section" => "discovery.files",
                "description" => "Scan for source files"
            ))
        end

        if !haskey(disc, "include_dirs") || isempty(get(disc, "include_dirs", []))
            push!(jobs, Dict(
                "daemon" => "discovery",
                "type" => "discover_project",
                "section" => "discovery",
                "description" => "Full discovery (files, includes, binaries, AST)"
            ))
        end
    end

    # Check LLVM section
    if haskey(toml, "llvm")
        llvm = toml["llvm"]

        if !haskey(llvm, "tools") || isempty(get(llvm, "tools", Dict()))
            push!(jobs, Dict(
                "daemon" => "discovery",
                "type" => "get_all_tools",
                "section" => "llvm.tools",
                "description" => "Discover LLVM tools"
            ))
        end
    end

    # Check compile section
    if haskey(toml, "compile")
        comp = toml["compile"]

        if !haskey(comp, "output_dir") || isempty(get(comp, "output_dir", ""))
            push!(jobs, Dict(
                "daemon" => "setup",
                "type" => "create_structure",
                "section" => "compile.output_dir",
                "description" => "Create build directory"
            ))
        end
    end

    # Check binary section
    if haskey(toml, "binary")
        bin = toml["binary"]

        if !haskey(bin, "library_name") || isempty(get(bin, "library_name", ""))
            project_name = get(get(toml, "project", Dict()), "name", "mylib")
            push!(jobs, Dict(
                "daemon" => "setup",
                "type" => "generate_lib_name",
                "section" => "binary.library_name",
                "value" => "lib$(lowercase(project_name)).so",
                "description" => "Generate library name"
            ))
        end
    end

    return jobs
end

"""
Send job to daemon and get result
"""
function execute_daemon_job(job::Dict, project_path::String)
    daemon = job["daemon"]
    port = DAEMON_PORTS[daemon]

    println("\n[$(daemon)] $(job["description"])")
    println("  Type: $(job["type"])")
    println("  Section: $(job["section"])")

    try
        # Build daemon command
        if job["type"] == "scan_files"
            cmd = "scan_files(Dict(\"path\" => \"$project_path\"))"
        elseif job["type"] == "discover_project"
            cmd = "discover_project(Dict(\"path\" => \"$project_path\"))"
        elseif job["type"] == "get_all_tools"
            cmd = "get_all_tools(Dict())"
        elseif job["type"] == "create_structure"
            cmd = "create_structure(Dict(\"path\" => \"$project_path\", \"type\" => \"cpp_project\"))"
        elseif job["type"] == "generate_lib_name"
            # This is a simple value, no daemon call needed
            return job["value"]
        else
            @warn "Unknown job type: $(job["type"])"
            return nothing
        end

        # Execute on daemon
        result = runexpr(cmd, port=port)

        # Extract result
        if result isa Dict
            if haskey(result, :success) && result[:success]
                if haskey(result, :results)
                    return result[:results]
                elseif haskey(result, :tools)
                    return result[:tools]
                elseif haskey(result, :created_dirs)
                    return "build/ir"  # Return output dir
                else
                    return result
                end
            else
                @warn "Job failed: $(get(result, :error, "Unknown error"))"
                return nothing
            end
        else
            return result
        end

    catch e
        println("  ❌ Error: $e")
        return nothing
    end
end

"""
Update TOML with job results
"""
function update_toml_with_results!(toml::Dict, job::Dict, result)
    if isnothing(result)
        return
    end

    section_path = job["section"]
    parts = split(section_path, ".")

    if length(parts) == 2
        section = parts[1]
        field = parts[2]

        if !haskey(toml, section)
            toml[section] = Dict()
        end

        toml[section][field] = result
        println("  ✅ Updated: $section_path")
    end
end

"""
Main auto-completion flow
"""
function auto_complete_toml(toml_path::String)
    if !isfile(toml_path)
        println("❌ Error: File not found: $toml_path")
        return
    end

    # Load TOML
    toml = TOML.parsefile(toml_path)
    project_path = get(get(toml, "project", Dict()), "root", dirname(abspath(toml_path)))

    # Analyze for missing fields
    jobs = analyze_toml_for_jobs(toml_path)

    if isempty(jobs)
        println("✅ TOML is complete! No jobs needed.")
        return
    end

    println("\nFound $(length(jobs)) missing fields")
    println("Queueing jobs to daemons...")
    println("="^70)

    # Execute each job
    for job in jobs
        result = execute_daemon_job(job, project_path)

        if !isnothing(result)
            update_toml_with_results!(toml, job, result)
        end
    end

    # Save updated TOML
    println("\n" * "="^70)
    println("💾 Saving updated TOML...")

    open(toml_path, "w") do io
        TOML.print(io, toml)
    end

    println("✅ TOML auto-completion complete!")
    println("📄 Updated: $toml_path")

    # Print summary
    println("\n" * "="^70)
    println("Summary:")
    for job in jobs
        status = haskey(toml, split(job["section"], ".")[1]) ? "✅" : "❌"
        println("  $status $(job["section"]): $(job["description"])")
    end
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    if length(ARGS) == 0
        println("""
        JMake Auto-Complete - Queue TOML jobs to daemons

        Usage:
            julia jmake_auto_complete.jl path/to/jmake.toml

        Analyzes TOML for missing fields, queues jobs to appropriate
        daemons, and auto-fills the TOML with results.

        Requires: All daemons running (./start_all.sh)
        """)
        return
    end

    toml_path = ARGS[1]
    auto_complete_toml(toml_path)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
