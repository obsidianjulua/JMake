#!/usr/bin/env julia
# Bridge_LLVM.jl - UnifiedBridge-powered LLVM compiler orchestrator
# Complete integration: UnifiedBridge + LLVMake + JuliaWrapItUp
# NOTE: This file is meant to be included from JMake.jl which handles module loading

using Pkg
using TOML
using JSON
using Dates

# Use already-loaded modules from parent JMake module
# (UnifiedBridge, LLVMake, JuliaWrapItUp are loaded by JMake.jl)

"""
Enhanced compiler configuration with UnifiedBridge integration
"""
mutable struct BridgeCompilerConfig
    # Project settings
    project_name::String
    project_root::String

    # Paths
    source_dir::String
    output_dir::String
    build_dir::String
    include_dirs::Vector{String}

    # Bridge settings
    auto_discover::Bool
    enable_learning::Bool
    cache_tools::Bool

    # Discovered tools (populated by UnifiedBridge)
    tools::Dict{String,String}

    # Compilation settings
    compile_flags::Vector{String}
    defines::Dict{String,String}
    walk_dependencies::Bool
    max_depth::Int

    # Target settings
    target_triple::String
    target_cpu::String
    opt_level::String
    enable_lto::Bool

    # Workflow stages
    stages::Vector{String}
    parallel::Bool

    # Cache settings
    cache_enabled::Bool
    cache_dir::String

    function BridgeCompilerConfig(config_file::String="jmake.toml")
        if !isfile(config_file)
            error("Config file not found: $config_file")
        end

        data = TOML.parsefile(config_file)

        # Parse configuration
        project = get(data, "project", Dict())
        paths = get(data, "paths", Dict())
        bridge = get(data, "bridge", Dict())
        compile = get(data, "compile", Dict())
        target = get(data, "target", Dict())
        workflow = get(data, "workflow", Dict())
        cache = get(data, "cache", Dict())

        config = new(
            get(project, "name", "MyProject"),
            get(project, "root", "."),
            get(paths, "source", "src"),
            get(paths, "output", "julia"),
            get(paths, "build", "build"),
            get(paths, "include", String[]),
            get(bridge, "auto_discover", true),
            get(bridge, "enable_learning", true),
            get(bridge, "cache_tools", true),
            Dict{String,String}(),  # tools - populated later
            get(compile, "flags", String[]),
            get(compile, "defines", Dict{String,String}()),
            get(compile, "walk_dependencies", true),
            get(compile, "max_depth", 10),
            get(target, "triple", ""),
            get(target, "cpu", "generic"),
            get(target, "opt_level", "O2"),
            get(target, "lto", false),
            get(workflow, "stages", String[]),
            get(workflow, "parallel", true),
            get(cache, "enabled", true),
            get(cache, "directory", ".bridge_cache")
        )

        return config
    end
end

"""
Discover LLVM toolchain using UnifiedBridge
"""
function discover_tools!(config::BridgeCompilerConfig)
    println("🔍 Discovering LLVM tools via UnifiedBridge...")

    required_tools = [
        "clang", "clang++", "llvm-config", "llvm-link",
        "opt", "nm", "objdump", "llvm-ar"
    ]

    for tool in required_tools
        if command_exists(tool)
            path = find_executable(tool)
            if !isempty(path)
                config.tools[tool] = path
                println("  ✅ $tool → $path")
            end
        else
            println("  ⚠️  $tool not found")
        end
    end

    if !haskey(config.tools, "clang++")
        error("❌ clang++ is required but not found")
    end

    println("  📊 Found $(length(config.tools)) tools")
end

"""
Walk dependency tree using clang -M via UnifiedBridge
"""
function walk_dependencies(config::BridgeCompilerConfig, entry_file::String)
    println("📂 Walking dependencies from: $entry_file")

    deps = Set{String}([entry_file])
    to_process = [entry_file]
    processed = Set{String}()
    depth = 0

    while !isempty(to_process) && depth < config.max_depth
        current_batch = copy(to_process)
        empty!(to_process)
        depth += 1

        for current in current_batch
            if current in processed
                continue
            end
            push!(processed, current)

            # Build include flags
            includes = ["-I$dir" for dir in config.include_dirs]

            # Execute clang -M via UnifiedBridge
            cmd_args = ["-M", "-MF", "/dev/null", includes..., current]

            (output, _) = execute_with_learning("clang++", cmd_args)

            if !startswith(output, "Error:")
                # Parse Make-style dependency output
                for line in split(output, "\n")
                    # Extract header files
                    for m in eachmatch(r"([^\s:]+\.h(?:pp)?)", line)
                        dep = String(m.captures[1])
                        if isfile(dep) && !(dep in processed)
                            push!(deps, dep)
                            push!(to_process, dep)
                        end
                    end
                end
            end
        end
    end

    println("  📊 Found $(length(deps)) dependencies (depth: $depth)")
    return collect(deps)
end

"""
Parse C++ AST using clang via UnifiedBridge
"""
function parse_ast_bridge(config::BridgeCompilerConfig, cpp_file::String)
    println("🔍 Parsing AST: $(basename(cpp_file))")

    # Build command
    includes = ["-I$dir" for dir in config.include_dirs]
    flags = config.compile_flags

    cmd_args = [
        "-Xclang", "-ast-dump=json",
        "-fsyntax-only",
        flags...,
        includes...,
        cpp_file
    ]

    (output, learned) = execute_with_learning("clang++", cmd_args)

    if startswith(output, "Error:")
        @warn "  ❌ AST parsing failed: $output"
        return nothing
    end

    try
        ast = JSON.parse(output)
        functions = extract_functions_from_ast(ast)
        println("  ✅ Found $(length(functions)) functions (pattern: $learned args)")
        return functions
    catch e
        @warn "  ❌ Failed to parse AST JSON: $e"
        return nothing
    end
end

"""
Extract function declarations from AST
"""
function extract_functions_from_ast(ast::Dict)
    functions = []

    function visit_node(node::Dict)
        if get(node, "kind", "") == "FunctionDecl"
            if get(node, "isImplicit", false)
                return
            end

            func_info = Dict{String,Any}(
                "name" => get(node, "name", ""),
                "return_type" => get(get(node, "type", Dict()), "qualType", "void"),
                "params" => []
            )

            # Extract parameters
            if haskey(node, "inner")
                for inner in node["inner"]
                    if get(inner, "kind", "") == "ParmVarDecl"
                        param = Dict(
                            "name" => get(inner, "name", ""),
                            "type" => get(get(inner, "type", Dict()), "qualType", "")
                        )
                        push!(func_info["params"], param)
                    end
                end
            end

            push!(functions, func_info)
        end

        if haskey(node, "inner")
            for child in node["inner"]
                if isa(child, Dict)
                    visit_node(child)
                end
            end
        end
    end

    if haskey(ast, "inner")
        for node in ast["inner"]
            if isa(node, Dict)
                visit_node(node)
            end
        end
    end

    return functions
end

"""
Compile C++ to LLVM IR via UnifiedBridge
"""
function compile_to_ir(config::BridgeCompilerConfig, cpp_files::Vector{String})
    println("🔧 Compiling to LLVM IR...")

    mkpath(config.build_dir)
    ir_files = String[]

    for cpp_file in cpp_files
        base = basename(cpp_file)
        ir_file = joinpath(config.build_dir, "$base.ll")

        # Build command
        includes = ["-I$dir" for dir in config.include_dirs]
        defines = ["-D$k=$v" for (k, v) in config.defines]

        cmd_args = [
            "-S", "-emit-llvm",
            config.compile_flags...,
            includes...,
            defines...,
            "-o", ir_file,
            cpp_file
        ]

        (output, learned) = execute_with_learning("clang++", cmd_args)

        if isfile(ir_file)
            push!(ir_files, ir_file)
            println("  ✅ $(basename(cpp_file)) → $(basename(ir_file))")
        else
            @warn "  ❌ Failed: $cpp_file"
        end
    end

    println("  📊 Generated $(length(ir_files)) IR files")
    return ir_files
end

"""
Link and optimize IR files via UnifiedBridge
"""
function link_optimize_ir(config::BridgeCompilerConfig, ir_files::Vector{String}, output_name::String)
    println("🔗 Linking and optimizing IR...")

    # Link
    linked_ir = joinpath(config.build_dir, "$output_name.linked.ll")
    cmd_args = ["-S", "-o", linked_ir, ir_files...]

    (output, _) = execute_with_learning("llvm-link", cmd_args)

    if !isfile(linked_ir)
        @warn "  ❌ Linking failed"
        return nothing
    end

    println("  ✅ Linked $(length(ir_files)) files")

    # Optimize
    optimized_ir = joinpath(config.build_dir, "$output_name.opt.ll")
    opt_level = replace(config.opt_level, "O" => "")

    cmd_args = ["-S", "-O$opt_level", "-o", optimized_ir, linked_ir]

    (output, _) = execute_with_learning("opt", cmd_args)

    if isfile(optimized_ir)
        println("  ✅ Optimized with -O$opt_level")
        return optimized_ir
    end

    return linked_ir
end

"""
Create shared library via UnifiedBridge
"""
function create_library(config::BridgeCompilerConfig, ir_file::String, lib_name::String)
    println("📦 Creating shared library...")

    mkpath(config.output_dir)
    lib_path = joinpath(config.output_dir, "lib$lib_name.so")

    cmd_args = [
        "-shared",
        "-o", lib_path,
        ir_file
    ]

    if config.enable_lto
        push!(cmd_args, "-flto")
    end

    (output, _) = execute_with_learning("clang++", cmd_args)

    if isfile(lib_path)
        println("  ✅ Created: $lib_path")
        return lib_path
    end

    @warn "  ❌ Library creation failed"
    return nothing
end

"""
Extract symbols from binary via UnifiedBridge
"""
function extract_symbols(config::BridgeCompilerConfig, binary_path::String)
    println("🔍 Extracting symbols...")

    # Try nm first
    if haskey(config.tools, "nm")
        (output, _) = execute_with_learning("nm", ["-DC", binary_path])

        symbols = Dict{String,Any}[]

        for line in split(output, "\n")
            parts = split(strip(line))
            if length(parts) >= 3 && parts[2] in ["T", "t"]
                push!(symbols, Dict(
                    "name" => parts[3],
                    "type" => "function",
                    "visibility" => parts[2] == "T" ? "global" : "local"
                ))
            end
        end

        println("  ✅ Found $(length(symbols)) symbols")
        return symbols
    end

    return Dict{String,Any}[]
end

"""
Main compilation pipeline
"""
function compile_project(config::BridgeCompilerConfig)
    println("🚀 JMake Bridge LLVM - Unified Build System")
    println("=" ^ 60)
    println("📁 Project: $(config.project_name)")
    println("📁 Source:  $(config.source_dir)")
    println("📁 Output:  $(config.output_dir)")
    println("=" ^ 60)

    # Stage 1: Discover tools
    if "discover_tools" in config.stages
        discover_tools!(config)
    end

    # Find C++ sources
    cpp_files = String[]
    for (root, dirs, files) in walkdir(config.source_dir)
        for file in files
            if endswith(file, ".cpp") || endswith(file, ".cc")
                push!(cpp_files, joinpath(root, file))
            end
        end
    end

    println("\n📊 Found $(length(cpp_files)) C++ files")

    if isempty(cpp_files)
        println("❌ No C++ files found")
        return nothing
    end

    # Stage 2: Walk dependencies
    all_deps = Set{String}()
    if "walk_deps" in config.stages && config.walk_dependencies
        for cpp in cpp_files
            deps = walk_dependencies(config, cpp)
            union!(all_deps, deps)
        end
        println("\n📦 Total dependencies: $(length(all_deps))")
    end

    # Stage 3: Parse AST
    all_functions = []
    if "parse_ast" in config.stages
        println("\n🔍 Parsing AST for all files...")
        for cpp in cpp_files
            functions = parse_ast_bridge(config, cpp)
            if !isnothing(functions)
                append!(all_functions, functions)
            end
        end
        println("  📊 Total functions: $(length(all_functions))")
    end

    # Stage 4: Compile to IR
    ir_files = String[]
    if "compile_to_ir" in config.stages
        ir_files = compile_to_ir(config, cpp_files)
    end

    if isempty(ir_files)
        println("❌ Compilation failed")
        return nothing
    end

    # Stage 5: Link and optimize
    optimized_ir = nothing
    if "link_ir" in config.stages || "optimize_ir" in config.stages
        optimized_ir = link_optimize_ir(config, ir_files, config.project_name)
    end

    if isnothing(optimized_ir)
        println("❌ Optimization failed")
        return nothing
    end

    # Stage 6: Create library
    lib_path = nothing
    if "create_library" in config.stages
        lib_path = create_library(config, optimized_ir, config.project_name)
    end

    if isnothing(lib_path)
        println("❌ Library creation failed")
        return nothing
    end

    # Stage 7: Extract symbols
    symbols = []
    if "extract_symbols" in config.stages
        symbols = extract_symbols(config, lib_path)
    end

    # Stage 8: Generate bindings
    if "generate_bindings" in config.stages
        println("\n📝 Generating Julia bindings...")
        # Use llvm_julia.jl's binding generator
        # (Implementation would call generate_julia_bindings)
    end

    # Show learning statistics
    if config.enable_learning
        println("\n📊 UnifiedBridge Learning Statistics:")
        stats = UnifiedBridge.get_learning_stats()
        for (cmd, data) in stats
            println("  $cmd: $(data["predicted_args"]) args (confidence: $(round(data["confidence"], digits=2)))")
        end
    end

    println("\n🎉 Compilation complete!")
    println("📦 Library: $lib_path")
    println("🔧 Symbols: $(length(symbols))")

    return lib_path
end

"""
CLI interface
"""
function main()
    if length(ARGS) == 0
        println("""
        JMake Bridge LLVM - UnifiedBridge + LLVM/Julia

        Usage:
            julia Bridge_LLVM.jl compile [config]
            julia Bridge_LLVM.jl discover [config]
            julia Bridge_LLVM.jl stats

        Examples:
            julia Bridge_LLVM.jl compile jmake.toml
            julia Bridge_LLVM.jl discover
        """)
        return
    end

    command = ARGS[1]

    if command == "compile"
        config_file = length(ARGS) >= 2 ? ARGS[2] : "jmake.toml"
        config = BridgeCompilerConfig(config_file)
        compile_project(config)

    elseif command == "discover"
        config_file = length(ARGS) >= 2 ? ARGS[2] : "jmake.toml"
        config = BridgeCompilerConfig(config_file)
        discover_tools!(config)

    elseif command == "stats"
        stats = UnifiedBridge.get_learning_stats()
        println("📊 UnifiedBridge Learning Statistics")
        println("=" ^ 50)
        for (cmd, data) in stats
            println("\n🔧 $cmd")
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
