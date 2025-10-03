#!/usr/bin/env julia
"""
JMake Build Client - Simple interface to daemon-based build system

Usage:
    julia jmake_build.jl [path]                    # Full build
    julia jmake_build.jl [path] --quick            # Quick compile (skip discovery)
    julia jmake_build.jl [path] --incremental      # Incremental build (cache enabled)
    julia jmake_build.jl [path] --clean            # Clean build (clear caches)
    julia jmake_build.jl [path] --watch            # Watch mode (auto-rebuild)
    julia jmake_build.jl --status                  # Check daemon status
    julia jmake_build.jl --stats                   # Get build statistics

Requires: All JMake daemons running (./start_all.sh)
"""

using DaemonMode

const ORCHESTRATOR_PORT = 3004

function main()
    if length(ARGS) == 0 || ARGS[1] == "--help"
        println("""
        JMake Build Client - Daemon-based build system

        Usage:
            julia jmake_build.jl [path] [options]

        Options:
            --quick         Quick compile (skip discovery, use existing config)
            --incremental   Incremental build (only rebuild changed files)
            --clean         Clean build (clear all caches, force rebuild)
            --watch         Watch mode (auto-rebuild on file changes)
            --status        Check if all daemons are running
            --stats         Get build statistics from all daemons

        Examples:
            # Full build of current directory
            julia jmake_build.jl .

            # Full build of specific project
            julia jmake_build.jl /path/to/project

            # Quick incremental rebuild
            julia jmake_build.jl . --incremental

            # Clean build (force everything)
            julia jmake_build.jl . --clean

            # Watch mode for development
            julia jmake_build.jl . --watch

        Note: Daemons must be running. Start with:
            cd daemons && ./start_all.sh
        """)
        return
    end

    # Parse arguments
    project_path = "."
    mode = :full

    for arg in ARGS
        if arg == "--quick"
            mode = :quick
        elseif arg == "--incremental"
            mode = :incremental
        elseif arg == "--clean"
            mode = :clean
        elseif arg == "--watch"
            mode = :watch
        elseif arg == "--status"
            mode = :status
        elseif arg == "--stats"
            mode = :stats
        elseif !startswith(arg, "--")
            project_path = arg
        end
    end

    # Execute requested operation
    try
        if mode == :status
            check_daemon_status()
        elseif mode == :stats
            get_build_stats()
        elseif mode == :full
            full_build(project_path)
        elseif mode == :quick
            quick_build(project_path)
        elseif mode == :incremental
            incremental_build(project_path)
        elseif mode == :clean
            clean_build(project_path)
        elseif mode == :watch
            watch_mode(project_path)
        end
    catch e
        if isa(e, Base.IOError) || contains(string(e), "Connection refused")
            println("❌ Error: Cannot connect to orchestrator daemon")
            println("   Make sure daemons are running:")
            println("   cd daemons && ./start_all.sh")
            exit(1)
        else
            println("❌ Error: $e")
            exit(1)
        end
    end
end

function check_daemon_status()
    println("Checking daemon status...")

    result = runexpr("check_daemons(Dict())", port=ORCHESTRATOR_PORT)

    if result[:all_running]
        println("✅ All daemons are running!")
        for (daemon, status) in result[:daemons]
            if status
                println("  ✓ $daemon")
            end
        end
    else
        println("⚠️  Some daemons are not running:")
        for (daemon, status) in result[:daemons]
            if status
                println("  ✓ $daemon: running")
            else
                println("  ✗ $daemon: NOT RUNNING")
            end
        end
        println("\nStart daemons with: cd daemons && ./start_all.sh")
    end
end

function get_build_stats()
    println("Gathering build statistics...")

    result = runexpr(:(get_stats(Dict())), port=ORCHESTRATOR_PORT)

    if result[:success]
        stats = result[:stats]

        println("\n" * "="^70)
        println("Build Statistics")
        println("="^70)

        if haskey(stats, "discovery")
            discovery = stats["discovery"]
            if discovery[:success]
                println("\nDiscovery Daemon:")
                for (key, value) in discovery[:stats]
                    println("  $key: $value")
                end
            end
        end

        if haskey(stats, "setup")
            setup = stats["setup"]
            if setup[:success]
                println("\nSetup Daemon:")
                for (key, value) in setup[:stats]
                    println("  $key: $value")
                end
            end
        end

        if haskey(stats, "compilation")
            compilation = stats["compilation"]
            if compilation[:success]
                println("\nCompilation Daemon:")
                for (key, value) in compilation[:stats]
                    println("  $key: $value")
                end
            end
        end

        println("="^70)
    else
        println("❌ Failed to get statistics: $(result[:error])")
    end
end

function full_build(project_path::String)
    println("Starting full build: $project_path")

    result = runexpr(:(build_project(Dict(
        "path" => $project_path,
        "force_discovery" => false,
        "force_compile" => false
    ))), port=ORCHESTRATOR_PORT)

    handle_build_result(result)
end

function quick_build(project_path::String)
    println("Starting quick build: $project_path")

    result = runexpr(:(quick_compile(Dict(
        "path" => $project_path,
        "force" => false
    ))), port=ORCHESTRATOR_PORT)

    handle_build_result(result)
end

function incremental_build(project_path::String)
    println("Starting incremental build: $project_path")

    result = runexpr(:(incremental_build(Dict(
        "path" => $project_path
    ))), port=ORCHESTRATOR_PORT)

    handle_build_result(result)
end

function clean_build(project_path::String)
    println("Starting clean build: $project_path")
    println("(clearing all caches...)")

    result = runexpr(:(clean_build(Dict(
        "path" => $project_path
    ))), port=ORCHESTRATOR_PORT)

    handle_build_result(result)
end

function watch_mode(project_path::String)
    println("Starting watch mode: $project_path")
    println("Press Ctrl+C to stop")

    result = runexpr(:(watch_and_build(Dict(
        "path" => $project_path,
        "interval" => 2.0
    ))), port=ORCHESTRATOR_PORT)

    # Watch mode runs indefinitely until interrupted
    if haskey(result, :stopped) && result[:stopped]
        println("Watch mode stopped")
    else
        handle_build_result(result)
    end
end

function handle_build_result(result::Dict)
    if result[:success]
        println("\n" * "="^70)
        println("✅ BUILD SUCCESSFUL")
        if haskey(result, :library_path)
            println("📦 Output: $(result[:library_path])")
        end
        if haskey(result, :elapsed_time)
            println("⏱️  Time: $(round(result[:elapsed_time], digits=2))s")
        end
        println("="^70)
    else
        println("\n" * "="^70)
        println("❌ BUILD FAILED")
        if haskey(result, :stage)
            println("Failed at stage: $(result[:stage])")
        end
        if haskey(result, :error)
            println("Error: $(result[:error])")
        end
        if haskey(result, :elapsed_time)
            println("Time: $(round(result[:elapsed_time], digits=2))s")
        end
        println("="^70)
        exit(1)
    end
end

# Run main
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
