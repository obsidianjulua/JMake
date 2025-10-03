#!/usr/bin/env julia
# JMake.jl - Main module for the JMake build system
# A TOML-based build system leveraging LLVM/Clang for Julia bindings generation

module JMake

# Version
const VERSION = v"0.1.0"

# Load all submodules in the correct order
include("LLVMEnvironment.jl")  # Load LLVM environment first for toolchain isolation
include("ConfigurationManager.jl")  # Configuration management
include("ASTWalker.jl")  # AST dependency analysis
include("Discovery.jl")  # Discovery pipeline
include("ErrorLearning.jl")  # Error learning system
include("BuildBridge.jl")
include("CMakeParser.jl")
include("LLVMake.jl")
include("JuliaWrapItUp.jl")
include("ClangJLBridge.jl")
include("DaemonManager.jl")  # Integrated daemon lifecycle management

# Re-export submodules
using .LLVMEnvironment
using .ConfigurationManager
using .ASTWalker
using .Discovery
using .ErrorLearning
using .BuildBridge
using .CMakeParser
using .LLVMake
using .JuliaWrapItUp
using .ClangJLBridge
using .DaemonManager

# Load Bridge_LLVM helper functions after modules are available
# (Bridge_LLVM uses the already-loaded modules above)
include("Bridge_LLVM.jl")

# Export submodules themselves
export LLVMEnvironment, ConfigurationManager, ASTWalker, Discovery, ErrorLearning, BuildBridge, CMakeParser, LLVMake, JuliaWrapItUp, ClangJLBridge, DaemonManager

# Export key types from LLVMake
export LLVMJuliaCompiler, CompilerConfig, TargetConfig

# Export key types from JuliaWrapItUp
export BinaryWrapper, WrapperConfig, BinaryInfo

# Export key functions from BuildBridge
export execute, capture, find_executable, command_exists
export discover_llvm_tools, compile_with_learning
export get_error_db, export_error_log, get_error_stats

# Export key functions from CMakeParser
export parse_cmake_file, CMakeProject, CMakeTarget
export to_jmake_config, write_jmake_config

# Export JMake high-level functions
export init, compile, wrap, wrap_binary, discover_tools
export import_cmake, export_errors, info, help, scan, analyze

# Export daemon management functions
export start_daemons, stop_daemons, daemon_status, ensure_daemons

# Export Discovery pipeline
export discover

# Export LLVM environment functions
export get_toolchain, verify_toolchain, print_toolchain_info, with_llvm_env

# Export key functions from LLVMake
export compile_project

# Export key functions from JuliaWrapItUp
export generate_wrappers, scan_binaries

# Export key functions from ClangJLBridge
export generate_bindings_clangjl, generate_from_config

"""
    init(project_dir::String="."; type::Symbol=:cpp)

Initialize a new JMake project with the appropriate directory structure.

# Arguments
- `project_dir::String`: Directory to initialize (default: current directory)
- `type::Symbol`: Project type - `:cpp` for C++ source, `:binary` for binary wrapping

# Examples
```julia
JMake.init("myproject")  # C++ project
JMake.init("mybindings", type=:binary)  # Binary wrapping project
```
"""
function init(project_dir::String="."; type::Symbol=:cpp)
    mkpath(project_dir)

    if type == :cpp
        # C++ source project
        println("🚀 Initializing JMake C++ project in: $project_dir")

        # Create directory structure
        for dir in ["src", "include", "julia", "build", "test"]
            mkpath(joinpath(project_dir, dir))
        end

        # Create jmake.toml config
        config_file = joinpath(project_dir, "jmake.toml")
        LLVMake.create_default_config(config_file)

        println("✅ C++ project initialized")
        println("📝 Edit $config_file to configure your project")
        println("📁 Put C++ sources in: $(joinpath(project_dir, "src"))")
        println("📁 Put headers in: $(joinpath(project_dir, "include"))")

    elseif type == :binary
        # Binary wrapping project
        println("🚀 Initializing JMake binary wrapping project in: $project_dir")

        # Create directory structure
        for dir in ["lib", "bin", "julia_wrappers"]
            mkpath(joinpath(project_dir, dir))
        end

        # Create wrapper config
        config_file = joinpath(project_dir, "wrapper_config.toml")
        config = JuliaWrapItUp.create_default_wrapper_config()
        JuliaWrapItUp.save_wrapper_config(config, config_file)

        println("✅ Binary wrapping project initialized")
        println("📝 Edit $config_file to configure wrapper generation")
        println("📁 Put binary files in: $(joinpath(project_dir, "lib"))")

    else
        error("Unknown project type: $type. Use :cpp or :binary")
    end
end

"""
    compile(config_file::String="jmake.toml")

Compile a C++ project to Julia bindings using the JMake system.

# Arguments
- `config_file::String`: Path to jmake.toml configuration file

# Examples
```julia
JMake.compile()  # Use default jmake.toml
JMake.compile("custom_config.toml")
```
"""
function compile(config_file::String="jmake.toml")
    println("🚀 JMake - Compiling project")
    config = BridgeCompilerConfig(config_file)
    compile_project(config)
end

"""
    wrap(config_file::String="wrapper_config.toml")

Generate Julia wrappers for existing binary files.

# Arguments
- `config_file::String`: Path to wrapper configuration file

# Examples
```julia
JMake.wrap()  # Use default wrapper_config.toml
JMake.wrap("custom_wrapper.toml")
```
"""
function wrap(config_file::String="wrapper_config.toml")
    println("🚀 JMake - Generating binary wrappers")
    wrapper = JuliaWrapItUp.BinaryWrapper(config_file)
    JuliaWrapItUp.generate_wrappers(wrapper)
end

"""
    wrap_binary(binary_path::String; config_file::String="wrapper_config.toml")

Wrap a specific binary file to Julia bindings.

# Arguments
- `binary_path::String`: Path to the binary file (.so, .dll, .dylib, etc.)
- `config_file::String`: Path to wrapper configuration file

# Examples
```julia
JMake.wrap_binary("/usr/lib/libmath.so")
JMake.wrap_binary("./build/libmylib.so")
```
"""
function wrap_binary(binary_path::String; config_file::String="wrapper_config.toml")
    println("🚀 JMake - Wrapping binary: $binary_path")
    wrapper = JuliaWrapItUp.BinaryWrapper(config_file)
    JuliaWrapItUp.generate_wrappers(wrapper, specific_binary=binary_path)
end

"""
    discover_tools(config_file::String="jmake.toml")

Discover LLVM/Clang tools available on the system using BuildBridge.

# Arguments
- `config_file::String`: Path to jmake.toml configuration file

# Examples
```julia
JMake.discover_tools()
```
"""
function discover_tools(config_file::String="jmake.toml")
    println("🔍 JMake - Discovering LLVM tools")
    config = BridgeCompilerConfig(config_file)
    discover_tools!(config)
end

"""
    import_cmake(cmake_file::String="CMakeLists.txt"; target::String="", output::String="jmake.toml")

Import a CMake project and generate jmake.toml configuration.

# Arguments
- `cmake_file::String`: Path to CMakeLists.txt file
- `target::String`: Specific target to import (empty = first target)
- `output::String`: Output path for jmake.toml

# Examples
```julia
# Import first target from CMake project
JMake.import_cmake("path/to/CMakeLists.txt")

# Import specific target
JMake.import_cmake("opencv/CMakeLists.txt", target="opencv_core")
```
"""
function import_cmake(cmake_file::String="CMakeLists.txt"; target::String="", output::String="jmake.toml")
    println("📦 Importing CMake project: $cmake_file")

    # Parse CMakeLists.txt
    cmake_project = CMakeParser.parse_cmake_file(cmake_file)

    println("✅ Found CMake project: $(cmake_project.project_name)")
    println("   Targets: $(join(keys(cmake_project.targets), ", "))")

    # Determine target
    target_name = target
    if isempty(target_name)
        if isempty(cmake_project.targets)
            error("No targets found in CMake project")
        end
        target_name = first(keys(cmake_project.targets))
        println("   Using target: $target_name")
    end

    # Generate jmake.toml
    CMakeParser.write_jmake_config(cmake_project, target_name, output)

    println("🎉 CMake import complete!")
    println("   Generated: $output")
    println("   Run: JMake.compile(\"$output\")")

    return cmake_project
end

"""
    export_errors(output_path::String="error_log.md")

Export error learning database to Obsidian-friendly markdown.

# Examples
```julia
JMake.export_errors("docs/errors.md")
```
"""
function export_errors(output_path::String="error_log.md")
    BuildBridge.export_error_log("jmake_errors.db", output_path)
end

"""
    scan(path="."; generate_config=true, output="jmake.toml")

Scan a directory and analyze its structure for JMake compilation.
Auto-generates jmake.toml if generate_config=true.

# Examples
```julia
JMake.scan()  # Scan current directory
JMake.scan("path/to/project")  # Scan specific directory
JMake.scan(".", generate_config=false)  # Just analyze, don't generate config
JMake.scan(".", output="my_config.toml")  # Custom output name
```
"""
function scan(path="."; generate_config=true, output="jmake.toml")
    println("🔍 Scanning project: $path")

    # Use Discovery module to scan project
    result = Discovery.discover(path, force=true)

    if generate_config && haskey(result, :scan_results)
        println("📝 Generating configuration: $output")
        # The discover function already generates config, just make sure it exists
        config_path = joinpath(path, "jmake.toml")
        if isfile(config_path) && output != "jmake.toml"
            # Copy to requested output name
            cp(config_path, joinpath(path, output), force=true)
        end
    end

    return result
end

"""
    analyze(path=".")

Analyze project structure and return detailed analysis.

# Examples
```julia
result = JMake.analyze("path/to/project")
println("Found \$(length(result[:scan_results].cpp_sources)) C++ files")
```
"""
function analyze(path=".")
    # Return discovery results for analysis (always force scan for analysis)
    return Discovery.discover(path, force=true)
end

"""
    info()

Display information about the JMake build system.
"""
function info()
    println("""
    ╔══════════════════════════════════════════════════════════════╗
    ║                  JMake Build System v$VERSION                 ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  A TOML-based build system leveraging LLVM/Clang           ║
    ║  for automatic Julia bindings generation                    ║
    ╚══════════════════════════════════════════════════════════════╝

    Components:
    • BuildBridge     - Command execution with error learning
    • CMakeParser     - Import CMake projects without running CMake
    • LLVMake         - C++ source → Julia compiler
    • JuliaWrapItUp   - Binary → Julia wrapper generator
    • Bridge_LLVM     - Orchestrator integrating all components

    Quick Start:
    1. Initialize project:   JMake.init("myproject")
    2. Add C++ sources:      Put files in src/
    3. Configure:            Edit jmake.toml
    4. Compile:              JMake.compile()

    For binary wrapping:
    1. Initialize:           JMake.init("mybindings", type=:binary)
    2. Add binaries:         Put .so files in lib/
    3. Configure:            Edit wrapper_config.toml
    4. Wrap:                 JMake.wrap()

    Documentation: See README.md
    """)
end

"""
    help()

Display help information about JMake commands.
"""
function help()
    println("""
    JMake Build System - Command Reference

    Initialization:
      JMake.init([dir])              Initialize C++ project
      JMake.init(dir, type=:binary)  Initialize binary wrapping project

    Compilation:
      JMake.compile([config])        Compile C++ → Julia
      JMake.discover_tools([config]) Discover LLVM tools

    Binary Wrapping:
      JMake.wrap([config])           Wrap all binaries
      JMake.wrap_binary(path)        Wrap specific binary

    Information:
      JMake.info()                   Show JMake information
      JMake.help()                   Show this help

    Configuration Files:
      jmake.toml                     Main project configuration
      wrapper_config.toml            Binary wrapping configuration

    Examples:
      # Create and build C++ project
      JMake.init("mymath")
      cd("mymath")
      # ... add C++ files to src/ ...
      JMake.compile()

      # Wrap existing library
      JMake.init("wrappers", type=:binary)
      cd("wrappers")
      JMake.wrap_binary("/usr/lib/libcrypto.so")

    For detailed documentation, see the README.md file.
    """)
end

# ============================================================================
# DAEMON MANAGEMENT FUNCTIONS
# ============================================================================

# Global daemon system instance
const DAEMON_SYSTEM = Ref{Union{DaemonManager.DaemonSystem, Nothing}}(nothing)

"""
    start_daemons(;project_root=pwd())

Start all JMake daemon servers (discovery, setup, compilation, orchestrator).
Replaces manual shell script execution.

# Examples
```julia
JMake.start_daemons()  # Start in current directory
JMake.start_daemons(project_root="/path/to/project")
```
"""
function start_daemons(;project_root=pwd())
    if !isnothing(DAEMON_SYSTEM[])
        println("⚠ Daemons already running. Use stop_daemons() first to restart.")
        return DAEMON_SYSTEM[]
    end

    # Clean up stale PID files
    DaemonManager.cleanup_stale_pids(project_root)

    # Start daemon system
    DAEMON_SYSTEM[] = DaemonManager.start_all(project_root=project_root)

    return DAEMON_SYSTEM[]
end

"""
    stop_daemons()

Stop all running JMake daemons gracefully.

# Examples
```julia
JMake.stop_daemons()
```
"""
function stop_daemons()
    if isnothing(DAEMON_SYSTEM[])
        println("No daemons are running")
        return
    end

    DaemonManager.stop_all(DAEMON_SYSTEM[])
    DAEMON_SYSTEM[] = nothing
end

"""
    daemon_status()

Display status of all JMake daemons.

# Examples
```julia
JMake.daemon_status()
```
"""
function daemon_status()
    if isnothing(DAEMON_SYSTEM[])
        println("No daemons are running")
        println("\nStart daemons with: JMake.start_daemons()")
        return
    end

    DaemonManager.status(DAEMON_SYSTEM[])
end

"""
    ensure_daemons()

Check if all daemons are running and restart any that have crashed.
Returns true if all daemons are healthy.

# Examples
```julia
if !JMake.ensure_daemons()
    println("Some daemons failed to restart")
end
```
"""
function ensure_daemons()
    if isnothing(DAEMON_SYSTEM[])
        println("Starting daemons...")
        start_daemons()
        return true
    end

    return DaemonManager.ensure_running(DAEMON_SYSTEM[])
end

# Show info on module load
function __init__()
    # Optional: Show a brief message when loaded
    # println("JMake v$VERSION loaded. Type JMake.help() for usage information.")
end

end # module JMake
