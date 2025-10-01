#!/usr/bin/env julia
# JMake.jl - Main module for the JMake build system
# A TOML-based build system leveraging LLVM/Clang for Julia bindings generation

module JMake

# Version
const VERSION = v"0.1.0"

# Load all submodules in the correct order
include("BuildBridge.jl")
include("CMakeParser.jl")
include("LLVMake.jl")
include("JuliaWrapItUp.jl")

# Re-export submodules
using .BuildBridge
using .CMakeParser
using .LLVMake
using .JuliaWrapItUp

# Load Bridge_LLVM helper functions after modules are available
# (Bridge_LLVM uses the already-loaded modules above)
include("Bridge_LLVM.jl")

# Export submodules themselves
export BuildBridge, CMakeParser, LLVMake, JuliaWrapItUp

# Export key types from LLVMake
export LLVMJuliaCompiler, CompilerConfig, TargetConfig

# Export key types from JuliaWrapItUp
export BinaryWrapper, WrapperConfig, BinaryInfo

# Export key functions from BuildBridge
export execute, capture, find_executable, command_exists
export discover_llvm_tools, compile_with_analysis

# Export key functions from CMakeParser
export parse_cmake_file, CMakeProject, CMakeTarget

# Export key functions from LLVMake
export compile_project

# Export key functions from JuliaWrapItUp
export generate_wrappers, scan_binaries

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
    compile_bridge_project(config)
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

Discover LLVM/Clang tools available on the system using UnifiedBridge.

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
    discover_bridge_tools!(config)
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
    • BuildBridge     - Simple command execution and tool discovery
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

# Show info on module load
function __init__()
    # Optional: Show a brief message when loaded
    # println("JMake v$VERSION loaded. Type JMake.help() for usage information.")
end

end # module JMake
