#!/usr/bin/env julia
# Integration example: UnifiedBridge + JMake LLVM compiler
# Shows how to use UnifiedBridge to wrap clang AST traversal and build automation

using Pkg
Pkg.activate(dirname(@__DIR__))

# Load UnifiedBridge for bash command wrapping
push!(LOAD_PATH, "/home/grim/.julia/julia/UnifiedBridge/src")
using UnifiedBridge

# Load LLVM compiler
include("llvm_julia.jl")
include("JuliaWrapItUp.jl")

"""
Enhanced LLVM compiler using UnifiedBridge for system calls
"""
module BridgedCompiler

using ..UnifiedBridge

"""
Use UnifiedBridge to call clang with AST dump
"""
function parse_cpp_with_bridge(cpp_file::String, include_dirs::Vector{String}=[])
    # Build clang command dynamically
    includes = join(["-I$dir" for dir in include_dirs], " ")
    cmd = "clang++ -Xclang -ast-dump=json -fsyntax-only $includes $cpp_file"

    # Execute via UnifiedBridge with learning
    (output, arg_count) = execute_with_learning("clang++",
        ["-Xclang", "-ast-dump=json", "-fsyntax-only", includes..., cpp_file])

    return output
end

"""
Discover compiler tools using UnifiedBridge
"""
function discover_llvm_tools()
    tools = Dict{String,String}()

    # Use UnifiedBridge to find tools
    for tool in ["clang", "clang++", "llvm-config", "llvm-link", "opt", "nm", "objdump"]
        if command_exists(tool)
            path = find_executable(tool)
            if !isempty(path)
                tools[tool] = path
                println("✅ Found $tool: $path")
            end
        end
    end

    return tools
end

"""
Walk dependency tree using clang and bridge
"""
function walk_dependency_tree(entry_file::String, include_dirs::Vector{String}=[])
    deps = Set{String}([entry_file])
    to_process = [entry_file]
    processed = Set{String}()

    while !isempty(to_process)
        current = pop!(to_process)

        if current in processed
            continue
        end

        println("📂 Processing: $current")
        push!(processed, current)

        # Use clang to get includes via bridge
        includes = join(["-I$dir" for dir in include_dirs], " ")
        cmd_parts = ["-M", "-MF", "/dev/null", includes, current]

        # Execute with bridge
        result = execute_auto_command("clang++", Dict(
            "options" => Dict("M" => true, "MF" => "/dev/null"),
            "positional" => [includes, current]
        ))

        # Parse dependencies from Make-style output
        if !startswith(result, "Error:")
            for line in split(result, "\n")
                # Extract .h, .hpp files
                matches = eachmatch(r"(\S+\.h(?:pp)?)", line)
                for m in matches
                    dep = String(m.captures[1])
                    if isfile(dep) && !(dep in processed)
                        push!(deps, dep)
                        push!(to_process, dep)
                    end
                end
            end
        end
    end

    return collect(deps)
end

"""
Compile project using UnifiedBridge for all tool invocations
"""
function compile_with_bridge(source_files::Vector{String},
                             output_name::String="output",
                             options::Dict=Dict())

    println("🚀 Bridge-based LLVM Compilation")
    println("=" ^ 50)

    # Auto-discover tools
    tools = discover_llvm_tools()

    if !haskey(tools, "clang++")
        error("❌ clang++ not found via UnifiedBridge")
    end

    # Compile each file to LLVM IR via bridge
    ir_files = String[]

    for src in source_files
        base = basename(src)
        ir_file = "$base.ll"

        # Build compile command
        flags = get(options, "flags", ["-O2", "-fPIC", "-std=c++17"])
        includes = get(options, "includes", String[])

        cmd_args = [
            "-S", "-emit-llvm",
            flags...,
            ["-I$inc" for inc in includes]...,
            "-o", ir_file,
            src
        ]

        println("  🔧 Compiling: $src → $ir_file")

        # Execute via bridge with learning
        (result, learned) = execute_with_learning("clang++", cmd_args)

        if !isempty(result) && !startswith(result, "Error:")
            push!(ir_files, ir_file)
            println("    ✅ Success (learned pattern: $learned args)")
        else
            @warn "    ❌ Failed: $result"
        end
    end

    # Link IR files
    if !isempty(ir_files)
        linked = "$output_name.linked.ll"
        link_args = ["-S", "-o", linked, ir_files...]

        println("  🔗 Linking $(length(ir_files)) IR files...")
        (result, _) = execute_with_learning("llvm-link", link_args)

        if isfile(linked)
            println("    ✅ Linked: $linked")

            # Optimize
            optimized = "$output_name.opt.ll"
            opt_level = get(options, "opt_level", "2")

            (result, _) = execute_with_learning("opt",
                ["-S", "-O$opt_level", "-o", optimized, linked])

            if isfile(optimized)
                println("    ✅ Optimized: $optimized")

                # Create shared library
                lib_file = "lib$output_name.so"
                (result, _) = execute_with_learning("clang++",
                    ["-shared", "-o", lib_file, optimized])

                if isfile(lib_file)
                    println("  📦 Created library: $lib_file")
                    return lib_file
                end
            end
        end
    end

    return nothing
end

"""
Extract symbols from binary using UnifiedBridge
"""
function extract_symbols_bridge(binary_path::String)
    println("🔍 Extracting symbols: $binary_path")

    # Try nm first
    if command_exists("nm")
        (output, _) = execute_with_learning("nm", ["-DC", binary_path])

        symbols = String[]
        for line in split(output, "\n")
            parts = split(strip(line))
            if length(parts) >= 3 && parts[2] in ["T", "t"]
                push!(symbols, parts[3])
            end
        end

        println("  Found $(length(symbols)) function symbols")
        return symbols
    end

    # Fallback to objdump
    if command_exists("objdump")
        (output, _) = execute_with_learning("objdump", ["-TC", binary_path])
        return parse_objdump_symbols(output)
    end

    return String[]
end

"""
Complete pipeline: source → IR → library → bindings
"""
function build_project(project_dir::String=".")
    cd(project_dir)

    println("🏗️  Building project: $project_dir")
    println("=" ^ 50)

    # Find C++ sources
    cpp_files = String[]
    for (root, dirs, files) in walkdir(".")
        for f in files
            if endswith(f, ".cpp") || endswith(f, ".cc")
                push!(cpp_files, joinpath(root, f))
            end
        end
    end

    println("📊 Found $(length(cpp_files)) source files")

    if isempty(cpp_files)
        println("❌ No C++ files found")
        return nothing
    end

    # Compile via bridge
    lib_file = compile_with_bridge(cpp_files, "myproject", Dict(
        "flags" => ["-O2", "-fPIC", "-std=c++17"],
        "includes" => ["./include"],
        "opt_level" => "2"
    ))

    if isnothing(lib_file)
        println("❌ Compilation failed")
        return nothing
    end

    # Extract symbols
    symbols = extract_symbols_bridge(lib_file)

    # Generate Julia bindings
    println("\n📝 Generating Julia bindings...")
    generate_simple_bindings(symbols, lib_file, "MyProject")

    println("\n🎉 Build complete!")

    # Show learning statistics
    println("\n📊 UnifiedBridge Learning Stats:")
    stats = get_learning_stats()
    for (cmd, data) in stats
        println("  $cmd: $(data["predicted_args"]) args (confidence: $(round(data["confidence"], digits=2)))")
    end

    return lib_file
end

"""
Generate simple Julia bindings from symbol list
"""
function generate_simple_bindings(symbols::Vector{String}, lib_path::String, module_name::String)
    content = """
    module $module_name

    const _lib = "$lib_path"

    """

    for sym in symbols
        julia_name = replace(sym, r"[^a-zA-Z0-9_]" => "_")
        content *= """
        function $julia_name(args...)
            ccall((:$sym, _lib), Cvoid, (Vararg{Any},), args...)
        end

        """
    end

    content *= """
    export $(join([replace(s, r"[^a-zA-Z0-9_]" => "_") for s in symbols], ", "))

    end # module
    """

    open("$(module_name).jl", "w") do f
        write(f, content)
    end

    println("  ✅ Generated: $(module_name).jl")
end

end # module BridgedCompiler

# ============================================================================
# CLI INTERFACE
# ============================================================================

function main()
    if length(ARGS) == 0
        println("""
        UnifiedBridge + LLVM Compiler Integration

        Usage:
            julia integration_example.jl discover    # Find LLVM tools
            julia integration_example.jl deps <file> # Walk dependency tree
            julia integration_example.jl build [dir] # Build project
            julia integration_example.jl stats       # Show learning stats

        Examples:
            julia integration_example.jl discover
            julia integration_example.jl deps src/main.cpp
            julia integration_example.jl build ./myproject
        """)
        return
    end

    command = ARGS[1]

    if command == "discover"
        BridgedCompiler.discover_llvm_tools()

    elseif command == "deps"
        if length(ARGS) < 2
            println("Usage: deps <cpp_file>")
            return
        end

        file = ARGS[2]
        deps = BridgedCompiler.walk_dependency_tree(file)

        println("\n📦 Dependencies for $file:")
        for dep in deps
            println("  • $dep")
        end

    elseif command == "build"
        project_dir = length(ARGS) >= 2 ? ARGS[2] : "."
        BridgedCompiler.build_project(project_dir)

    elseif command == "stats"
        stats = get_learning_stats()

        println("📊 UnifiedBridge Learning Statistics")
        println("=" ^ 50)

        for (cmd, data) in stats
            println("\n🔧 Command: $cmd")
            println("  Patterns: $(data["patterns"])")
            println("  Confidence: $(round(data["confidence"], digits=2))")
            println("  Predicted args: $(data["predicted_args"])")
        end

    else
        println("Unknown command: $command")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
