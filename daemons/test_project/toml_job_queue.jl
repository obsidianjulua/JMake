#!/usr/bin/env julia
"""
TOML Job Queue System - Auto-complete jmake.toml by queueing jobs for missing fields

Usage:
    julia toml_job_queue.jl path/to/jmake.toml

    Scans TOML, finds missing fields, queues jobs to fill them.
"""

using TOML
using Dates

# Load JMake modules directly
include(joinpath(@__DIR__, "..", "src", "ConfigurationManager.jl"))
include(joinpath(@__DIR__, "..", "src", "Discovery.jl"))
include(joinpath(@__DIR__, "..", "src", "LLVMEnvironment.jl"))

using .ConfigurationManager
using .Discovery
using .LLVMEnvironment

# Job structure
mutable struct TOMLJob
    id::String
    type::Symbol
    section::String  # TOML path (e.g., "discovery.files")
    description::String
    callback::Function
    priority::Int
    dependencies::Vector{String}
    status::Symbol  # :pending, :running, :completed, :failed
    result::Any
    error::Union{String, Nothing}
end

# Global job registry
const JOB_REGISTRY = Dict{String, TOMLJob}()
const JOB_QUEUE = TOMLJob[]

"""
Parse TOML and generate jobs for missing fields
"""
function analyze_toml(config_path::String)
    config = ConfigurationManager.load_config(config_path)
    jobs = TOMLJob[]

    println("📋 Analyzing TOML: $config_path")
    println("="^70)

    # Discovery section
    if !haskey(config.discovery, "files") || isempty(get(config.discovery, "files", Dict()))
        push!(jobs, create_job(
            "scan_files",
            :scan_files,
            "discovery.files",
            "Scan project for source files",
            scan_files_callback,
            priority = 10,
            deps = []
        ))
    end

    if !haskey(config.discovery, "include_dirs") || isempty(get(config.discovery, "include_dirs", []))
        push!(jobs, create_job(
            "find_includes",
            :find_includes,
            "discovery.include_dirs",
            "Discover include directories",
            find_includes_callback,
            priority = 9,
            deps = ["scan_files"]
        ))
    end

    if !haskey(config.discovery, "binaries") || isempty(get(config.discovery, "binaries", Dict()))
        push!(jobs, create_job(
            "find_binaries",
            :find_binaries,
            "discovery.binaries",
            "Detect binary files",
            find_binaries_callback,
            priority = 8,
            deps = ["scan_files"]
        ))
    end

    # LLVM section
    if !haskey(config.llvm, "tools") || isempty(get(config.llvm, "tools", Dict()))
        push!(jobs, create_job(
            "discover_llvm",
            :discover_llvm,
            "llvm.tools",
            "Discover LLVM toolchain",
            discover_llvm_callback,
            priority = 10,  # High priority, no deps
            deps = []
        ))
    end

    # Compile section
    if !haskey(config.compile, "output_dir") || isempty(get(config.compile, "output_dir", ""))
        push!(jobs, create_job(
            "setup_build_dir",
            :setup_build_dir,
            "compile.output_dir",
            "Create build directory structure",
            setup_build_dir_callback,
            priority = 7,
            deps = []
        ))
    end

    # Binary section
    if !haskey(config.binary, "library_name") || isempty(get(config.binary, "library_name", ""))
        push!(jobs, create_job(
            "generate_lib_name",
            :generate_lib_name,
            "binary.library_name",
            "Generate library name",
            generate_lib_name_callback,
            priority = 5,
            deps = []
        ))
    end

    return jobs
end

"""
Create a job
"""
function create_job(id, type, section, desc, callback; priority=5, deps=[])
    job = TOMLJob(
        id, type, section, desc, callback,
        priority, deps, :pending, nothing, nothing
    )
    JOB_REGISTRY[id] = job
    return job
end

"""
Build dependency graph and execute jobs in order
"""
function execute_jobs(jobs::Vector{TOMLJob}, config_path::String)
    config = ConfigurationManager.load_config(config_path)

    # Sort by priority (higher first) and dependencies
    sorted_jobs = topological_sort(jobs)

    println("\n🚀 Executing $(length(sorted_jobs)) jobs...")
    println("="^70)

    for job in sorted_jobs
        execute_job(job, config, config_path)
    end

    println("\n✅ All jobs completed!")
    print_job_summary(sorted_jobs)
end

"""
Execute a single job
"""
function execute_job(job::TOMLJob, config, config_path::String)
    println("\n[$(job.id)] $(job.description)")
    println("  Section: $(job.section)")
    println("  Priority: $(job.priority)")

    # Check dependencies
    for dep_id in job.dependencies
        dep = JOB_REGISTRY[dep_id]
        if dep.status != :completed
            println("  ⏳ Waiting for dependency: $dep_id")
            execute_job(dep, config, config_path)
        end
    end

    # Execute job
    job.status = :running

    try
        result = job.callback(config)
        job.result = result
        job.status = :completed

        # Update TOML with result
        update_toml_section!(config, job.section, result)
        ConfigurationManager.save_config(config)

        println("  ✅ Result: $result")

    catch e
        job.status = :failed
        job.error = string(e)
        println("  ❌ Failed: $e")
    end
end

"""
Update TOML section with job result
"""
function update_toml_section!(config, section_path::String, value)
    parts = split(section_path, ".")

    if length(parts) == 2
        section_name = parts[1]
        field_name = parts[2]

        if section_name == "discovery"
            config.discovery[field_name] = value
        elseif section_name == "compile"
            config.compile[field_name] = value
        elseif section_name == "llvm"
            config.llvm[field_name] = value
        elseif section_name == "binary"
            config.binary[field_name] = value
        end
    end
end

"""
Topological sort for dependency resolution
"""
function topological_sort(jobs::Vector{TOMLJob})
    sorted = TOMLJob[]
    visited = Set{String}()

    function visit(job::TOMLJob)
        if job.id in visited
            return
        end

        # Visit dependencies first
        for dep_id in job.dependencies
            if haskey(JOB_REGISTRY, dep_id)
                visit(JOB_REGISTRY[dep_id])
            end
        end

        push!(visited, job.id)
        push!(sorted, job)
    end

    # Sort by priority first
    priority_sorted = sort(jobs, by = j -> -j.priority)

    for job in priority_sorted
        visit(job)
    end

    return sorted
end

"""
Print job execution summary
"""
function print_job_summary(jobs::Vector{TOMLJob})
    println("\n" * "="^70)
    println("Job Execution Summary")
    println("="^70)

    completed = count(j -> j.status == :completed, jobs)
    failed = count(j -> j.status == :failed, jobs)

    println("Total jobs: $(length(jobs))")
    println("✅ Completed: $completed")
    println("❌ Failed: $failed")

    if failed > 0
        println("\nFailed jobs:")
        for job in jobs
            if job.status == :failed
                println("  • $(job.id): $(job.error)")
            end
        end
    end
end

# ============================================================================
# JOB CALLBACKS
# ============================================================================

"""
Scan project for source files
"""
function scan_files_callback(config)
    scan_result = Discovery.scan_all_files(config.project_root)

    files = Dict(
        "cpp_sources" => scan_result.cpp_sources,
        "cpp_headers" => scan_result.cpp_headers,
        "c_sources" => scan_result.c_sources,
        "c_headers" => scan_result.c_headers
    )

    println("    Found: $(length(scan_result.cpp_sources)) C++ sources, $(length(scan_result.cpp_headers)) headers")

    return files
end

"""
Find include directories
"""
function find_includes_callback(config)
    # Get scan results from discovery section
    files_dict = get(config.discovery, "files", Dict())

    # Build include dirs
    include_dirs = Set{String}()

    for header in get(files_dict, "cpp_headers", [])
        header_dir = dirname(header)
        if !isempty(header_dir) && header_dir != "."
            push!(include_dirs, abspath(joinpath(config.project_root, header_dir)))
        end
    end

    # Add standard locations
    push!(include_dirs, abspath(config.project_root))

    if isdir(joinpath(config.project_root, "include"))
        push!(include_dirs, abspath(joinpath(config.project_root, "include")))
    end

    result = sort(collect(include_dirs))
    println("    Found: $(length(result)) include directories")

    return result
end

"""
Find binaries
"""
function find_binaries_callback(config)
    scan_result = Discovery.scan_all_files(config.project_root)
    binaries = Discovery.detect_all_binaries(config.project_root, scan_result)

    result = Dict(
        "executables" => [b.path for b in binaries if b.type == :executable],
        "static_libs" => [b.path for b in binaries if b.type == :static_lib],
        "shared_libs" => [b.path for b in binaries if b.type == :shared_lib]
    )

    println("    Found: $(length(binaries)) binaries")

    return result
end

"""
Discover LLVM toolchain
"""
function discover_llvm_callback(config)
    # Use JMake's LLVM
    llvm_root = "/home/grim/.julia/julia/JMake/LLVM"

    tools = Dict(
        "clang" => joinpath(llvm_root, "tools", "clang"),
        "clang++" => joinpath(llvm_root, "tools", "clang++"),
        "llvm-config" => joinpath(llvm_root, "tools", "llvm-config"),
        "llvm-link" => joinpath(llvm_root, "tools", "llvm-link"),
        "opt" => joinpath(llvm_root, "tools", "opt"),
        "llc" => joinpath(llvm_root, "tools", "llc"),
        "llvm-nm" => joinpath(llvm_root, "tools", "llvm-nm"),
        "llvm-ar" => joinpath(llvm_root, "tools", "llvm-ar")
    )

    println("    Found: $(length(tools)) LLVM tools")

    return tools
end

"""
Setup build directory
"""
function setup_build_dir_callback(config)
    output_dir = joinpath(config.project_root, "build", "ir")
    mkpath(output_dir)

    println("    Created: $output_dir")

    return "build/ir"
end

"""
Generate library name
"""
function generate_lib_name_callback(config)
    lib_name = "lib$(lowercase(config.project_name)).so"

    println("    Generated: $lib_name")

    return lib_name
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    if length(ARGS) == 0
        println("""
        TOML Job Queue System - Auto-complete jmake.toml

        Usage:
            julia toml_job_queue.jl path/to/jmake.toml

        Analyzes TOML for missing fields and queues jobs to fill them.
        Jobs execute in dependency order, updating the TOML as they complete.
        """)
        return
    end

    config_path = ARGS[1]

    if !isfile(config_path)
        println("❌ Error: File not found: $config_path")
        return
    end

    # Analyze TOML and generate jobs
    jobs = analyze_toml(config_path)

    if isempty(jobs)
        println("✅ TOML is complete! No jobs needed.")
        return
    end

    println("\nFound $(length(jobs)) missing fields:")
    for job in jobs
        println("  • $(job.section): $(job.description)")
    end

    # Execute jobs
    execute_jobs(jobs, config_path)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
