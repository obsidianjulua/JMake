#!/usr/bin/env julia
"""
Build Daemon Server - Handles compilation and build requests

Start with: julia build_daemon.jl
Port: 3001
"""

using DaemonMode
using JMake

const PORT = 3001
const BUILD_CACHE = Dict{String, Any}()

"""
Process a build request for a target
"""
function handle_build_request(args::Dict)
    target = get(args, "target", "")
    config_path = get(args, "config", "jmake.toml")
    force_rebuild = get(args, "force", false)

    println("[BUILD DAEMON] Processing build for target: $target")

    try
        # Check cache unless force rebuild
        cache_key = "$config_path:$target"
        if !force_rebuild && haskey(BUILD_CACHE, cache_key)
            println("[BUILD DAEMON] Using cached build")
            return BUILD_CACHE[cache_key]
        end

        # Perform actual build
        result = JMake.build_target(config_path, target)

        # Cache successful builds
        if result[:success]
            BUILD_CACHE[cache_key] = result
        end

        return result

    catch e
        return Dict(
            :success => false,
            :error => string(e),
            :stacktrace => sprint(showerror, e, catch_backtrace())
        )
    end
end

"""
Main daemon serve function
"""
function main()
    println("="^60)
    println("JMake Build Daemon Server")
    println("Port: $PORT")
    println("="^60)
    println("Ready to accept build requests...")
    println()

    # Start the daemon server
    serve(PORT)
end

# Start the daemon if run directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
