#!/usr/bin/env julia
"""
File Watcher Daemon Server - Monitors source files and triggers reactive builds

Start with: julia watcher_daemon.jl
Port: 3003
"""

using DaemonMode
using JMake

const PORT = 3003
const WATCH_INTERVALS = Dict{String, Float64}()  # path => interval in seconds
const FILE_MTIMES = Dict{String, Float64}()      # path => last modified time

"""
Start watching a directory/file
"""
function start_watch(args::Dict)
    path = get(args, "path", "")
    interval = get(args, "interval", 1.0)
    patterns = get(args, "patterns", ["*.cpp", "*.h", "*.jl"])
    on_change = get(args, "on_change", "rebuild")

    println("[WATCHER DAEMON] Starting watch on: $path")

    try
        if !ispath(path)
            return Dict(
                :success => false,
                :error => "Path does not exist: $path"
            )
        end

        # Initialize watch
        WATCH_INTERVALS[path] = interval

        # Get initial file states
        files = collect_files(path, patterns)
        for file in files
            FILE_MTIMES[file] = mtime(file)
        end

        return Dict(
            :success => true,
            :watching => path,
            :files_count => length(files),
            :interval => interval
        )

    catch e
        return Dict(
            :success => false,
            :error => string(e)
        )
    end
end

"""
Check for file changes
"""
function check_changes(args::Dict)
    path = get(args, "path", "")
    patterns = get(args, "patterns", ["*.cpp", "*.h", "*.jl"])

    try
        changes = []
        files = collect_files(path, patterns)

        for file in files
            current_mtime = mtime(file)
            last_mtime = get(FILE_MTIMES, file, 0.0)

            if current_mtime > last_mtime
                push!(changes, Dict(
                    :file => file,
                    :type => haskey(FILE_MTIMES, file) ? "modified" : "new",
                    :mtime => current_mtime
                ))
                FILE_MTIMES[file] = current_mtime
            end
        end

        # Check for deleted files
        for (file, _) in FILE_MTIMES
            if !isfile(file)
                push!(changes, Dict(
                    :file => file,
                    :type => "deleted"
                ))
                delete!(FILE_MTIMES, file)
            end
        end

        return Dict(
            :success => true,
            :changes => changes,
            :count => length(changes)
        )

    catch e
        return Dict(
            :success => false,
            :error => string(e)
        )
    end
end

"""
Collect files matching patterns
"""
function collect_files(path::String, patterns::Vector)
    files = String[]

    if isfile(path)
        return [path]
    end

    for (root, dirs, filenames) in walkdir(path)
        for filename in filenames
            for pattern in patterns
                # Simple pattern matching (*.ext)
                if pattern == "*" || endswith(filename, pattern[2:end])
                    push!(files, joinpath(root, filename))
                    break
                end
            end
        end
    end

    return files
end

"""
Stop watching a path
"""
function stop_watch(args::Dict)
    path = get(args, "path", "")

    if haskey(WATCH_INTERVALS, path)
        delete!(WATCH_INTERVALS, path)
        return Dict(:success => true, :stopped => path)
    else
        return Dict(:success => false, :error => "Not watching: $path")
    end
end

"""
Main daemon serve function
"""
function main()
    println("="^60)
    println("JMake File Watcher Daemon Server")
    println("Port: $PORT")
    println("="^60)
    println("Ready to monitor file changes...")
    println()

    # Start the daemon server
    serve(PORT)
end

# Start the daemon if run directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
