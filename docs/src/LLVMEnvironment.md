# LLVMEnvironment Module

**Complete LLVM Toolchain Environment Manager**

The `LLVMEnvironment` module provides isolated, project-specific LLVM 20.1.2 toolchain management for JMake. It ensures all compilation operations use a controlled LLVM installation without polluting the system environment, supporting both in-tree LLVM installations and LLVM_full_assert_jll artifacts.

## Overview

JMake requires precise control over its LLVM/Clang toolchain to ensure reproducible builds and avoid conflicts with system-installed compilers. `LLVMEnvironment` solves this by:

- **Isolating toolchain paths**: Maintains a complete LLVM 20.1.2 installation separate from system tools
- **Dual-source support**: Can use either JMake's in-tree LLVM or LLVM_full_assert_jll artifact
- **Environment variable management**: Temporarily sets PATH, LD_LIBRARY_PATH, and other variables only when needed
- **Tool discovery**: Automatically discovers 40+ LLVM tools and libraries
- **Verification**: Validates toolchain integrity and functionality

This isolation prevents issues like:
- Version conflicts with system LLVM
- Missing tools or incompatible versions
- Undefined behavior from mixed toolchain versions
- Environment pollution affecting other projects

## Key Concepts

### Toolchain Isolation

The module implements **scoped environment isolation** using the `with_llvm_env()` pattern:

```julia
# System environment is unchanged
run(`clang++ --version`)  # Uses system clang

# LLVM environment is active only inside this block
LLVMEnvironment.with_llvm_env() do
    run(`clang++ --version`)  # Uses JMake's LLVM 20.1.2
end

# System environment restored
run(`clang++ --version`)  # Back to system clang
```

### Dual-Source Architecture

The toolchain can be sourced from two locations:

1. **In-tree LLVM** (default): `/home/grim/.julia/julia/JMake/LLVM/`
   - Complete LLVM 20.1.2 installation
   - Tools located in `LLVM/tools/`
   - Libraries in `LLVM/lib/`

2. **LLVM_full_assert_jll**: Julia artifact package
   - Managed by BinaryBuilder
   - Tools located in `bin/`
   - Automatic version updates via Pkg

The module auto-detects availability and prefers JLL when available for easier deployment.

### Tool Management

Over 40 LLVM tools are tracked and made available:

**Compilers**: clang, clang++, clang-20
**Core Tools**: llvm-config, llvm-link, llvm-as, llvm-dis, opt, llc, lli
**Analysis**: llvm-nm, llvm-objdump, llvm-ar, llvm-ranlib, llvm-readobj
**Optimization**: llvm-extract, llvm-split, llvm-reduce, llvm-lto
**Debugging**: llvm-debuginfod, llvm-dwarfdump, llvm-symbolizer
**Clang Tools**: clang-format, clang-tidy, clang-check, clangd

## Architecture

### Initialization Flow

```
User calls get_toolchain()
         ↓
Check GLOBAL_LLVM_TOOLCHAIN
         ↓
    [Not initialized?]
         ↓
    init_toolchain()
         ↓
  ┌──────┴──────┐
  ↓             ↓
JLL Available?  In-tree LLVM
  ↓             ↓
get_jll_root   get_jmake_root
  ↓             ↓
  └──────┬──────┘
         ↓
  discover_llvm_tools()
         ↓
  discover_llvm_libraries()
         ↓
  query_llvm_config()
         ↓
  build_environment_vars()
         ↓
  Return LLVMToolchain struct
```

### Environment Variable Management

When `with_llvm_env()` is called:

1. **Save** current environment variables (PATH, LD_LIBRARY_PATH, CPATH, etc.)
2. **Modify** environment to prepend LLVM paths
3. **Execute** user function in modified environment
4. **Restore** original environment variables
5. **Return** function result

This ensures zero pollution of the global environment.

## API Reference

### Types

#### `LLVMToolchain`

Complete LLVM toolchain configuration.

**Fields**:
- `root::String` - LLVM installation root directory
- `bin_dir::String` - Tools directory (tools/ or bin/)
- `lib_dir::String` - Libraries directory
- `include_dir::String` - Headers directory
- `libexec_dir::String` - Helper executables
- `share_dir::String` - Shared resources
- `version::String` - Full version string (e.g., "20.1.2jl")
- `version_major::Int`, `version_minor::Int`, `version_patch::Int` - Parsed version
- `tools::Dict{String,String}` - Tool name → absolute path
- `libraries::Dict{String,String}` - Library name → absolute path
- `cxxflags::Vector{String}` - C++ compilation flags
- `ldflags::Vector{String}` - Linker flags
- `libs::String` - Required libraries
- `env_vars::Dict{String,String}` - Environment variables to set
- `isolated::Bool` - Whether toolchain is isolated
- `source::String` - Source type: "intree" or "jll"

### Core Functions

#### `get_toolchain() -> LLVMToolchain`

Get or initialize the global LLVM toolchain.

**Returns**: Singleton `LLVMToolchain` instance

**Example**:
```julia
using JMake.LLVMEnvironment

# Get toolchain (initializes on first call)
toolchain = get_toolchain()

println("LLVM Root: ", toolchain.root)
println("Version: ", toolchain.version)
println("Available tools: ", length(toolchain.tools))
```

**Behavior**:
- First call: Initializes and caches toolchain
- Subsequent calls: Returns cached instance
- Thread-safe via `Ref{Union{LLVMToolchain,Nothing}}`

---

#### `init_toolchain(; isolated::Bool=true, config=nothing, source::Symbol=:auto) -> LLVMToolchain`

Initialize LLVM toolchain with configuration options.

**Arguments**:
- `isolated::Bool=true` - Enable environment isolation
- `config=nothing` - Optional `JMakeConfig` with LLVM settings
- `source::Symbol=:auto` - Toolchain source
  - `:auto` - Prefer JLL, fallback to in-tree
  - `:jll` - Force LLVM_full_assert_jll (error if unavailable)
  - `:intree` - Force in-tree LLVM

**Returns**: Configured `LLVMToolchain` instance

**Example**:
```julia
# Auto-detect (prefer JLL)
toolchain = init_toolchain()

# Force in-tree LLVM
toolchain = init_toolchain(source=:intree)

# Initialize from config file
config = ConfigurationManager.load_config("jmake.toml")
toolchain = init_toolchain(config=config)
```

**Initialization Steps**:
1. Determine LLVM root (from config or auto-discover)
2. Verify critical directories (bin, lib, include)
3. Query llvm-config for version
4. Discover tools and libraries
5. Build environment variables
6. Return configured toolchain

---

#### `with_llvm_env(f::Function)`

Execute function with LLVM environment variables set.

**Arguments**:
- `f::Function` - Function to execute in LLVM environment

**Returns**: Result of `f()`

**Example**:
```julia
# Run clang with LLVM environment
with_llvm_env() do
    run(`clang++ --version`)
end

# Compile with isolated environment
output = with_llvm_env() do
    read(`clang++ -c myfile.cpp -o myfile.o`, String)
end

# Environment is restored after block
println(ENV["PATH"])  # Original PATH
```

**Modified Variables**:
- `PATH` - Prepended with LLVM bin directory
- `LD_LIBRARY_PATH` - Prepended with LLVM lib directory
- `LIBRARY_PATH` - For linking
- `CPATH` - For C/C++ includes
- `LLVM_ROOT` - LLVM installation root
- `LLVM_DIR` - For CMake find_package
- `Clang_DIR` - For CMake find_package

---

#### `verify_toolchain() -> Bool`

Verify LLVM toolchain is properly installed and functional.

**Returns**: `true` if verification passes, `false` otherwise

**Example**:
```julia
if verify_toolchain()
    println("Toolchain is ready!")
else
    error("Toolchain verification failed")
end
```

**Verification Steps**:
1. Check essential tools exist (clang++, llvm-config, llvm-link, opt, llc)
2. Test clang++ execution
3. Test llvm-config execution
4. Report results

---

#### `print_toolchain_info()`

Print detailed toolchain information.

**Example**:
```julia
print_toolchain_info()
```

Output shows paths, version, available tools, libraries, environment variables, and isolation status.

### Tool Access Functions

#### `get_tool(tool_name::String) -> String`

Get absolute path to an LLVM tool.

**Arguments**:
- `tool_name::String` - Name of tool (e.g., "clang++", "opt")

**Returns**: Absolute path to tool, or empty string if not found

**Example**:
```julia
clang_path = get_tool("clang++")
if !isempty(clang_path)
    println("Found clang++: ", clang_path)
    run(`$clang_path --version`)
end
```

---

#### `has_tool(tool_name::String) -> Bool`

Check if an LLVM tool is available.

**Example**:
```julia
if has_tool("clang-tidy")
    run(`$(get_tool("clang-tidy")) myfile.cpp`)
else
    @warn "clang-tidy not available"
end
```

---

#### `get_library(lib_name::String) -> String`

Get absolute path to an LLVM library.

---

#### `get_include_flags() -> Vector{String}`

Get C++ include flags for LLVM headers.

**Returns**: Vector of `-I` flags

---

#### `get_link_flags() -> Vector{String}`

Get linker flags for LLVM libraries.

**Returns**: Vector of `-L` and `-rpath` flags

---

#### `run_tool(tool_name::String, args::Vector{String}; capture_output::Bool=true) -> Tuple{String, Int}`

Run an LLVM tool with isolated environment.

**Arguments**:
- `tool_name::String` - Tool name
- `args::Vector{String}` - Command arguments
- `capture_output::Bool=true` - Capture stdout/stderr

**Returns**: `(output, exitcode)` tuple

**Example**:
```julia
# Run opt with specific passes
(output, exitcode) = run_tool("opt", [
    "-S", "-O2", "-inline", "-mem2reg",
    "-o", "optimized.ll", "input.ll"
])

if exitcode == 0
    println("Optimization successful!")
end
```

### Path Discovery Functions

#### `get_jmake_llvm_root() -> String`

Get path to JMake's in-tree LLVM installation.

**Returns**: Absolute path to LLVM directory

**Throws**: Error if directory doesn't exist

---

#### `get_jll_llvm_root() -> Union{String, Nothing}`

Get path to LLVM_full_assert_jll artifact.

**Returns**: Absolute path to artifact, or `nothing` if unavailable

---

#### `get_llvm_root(source::Symbol=:auto) -> Tuple{String, String}`

Get LLVM root path based on source preference.

**Arguments**:
- `source::Symbol` - `:auto`, `:intree`, or `:jll`

**Returns**: `(root_path, source_type)` tuple

## Integration Examples

### Basic Compilation

```julia
using JMake.LLVMEnvironment

# Get toolchain
toolchain = get_toolchain()

# Compile C++ file with isolated environment
with_llvm_env() do
    clang = get_tool("clang++")
    run(`$clang -std=c++17 -c myfile.cpp -o myfile.o`)
end
```

### Custom Toolchain Configuration

```julia
# Initialize with specific source
toolchain = init_toolchain(source=:intree, isolated=true)

# Get compilation flags
include_flags = get_include_flags()
link_flags = get_link_flags()

# Compile and link
with_llvm_env() do
    run(`clang++ -c src.cpp $include_flags`)
    run(`clang++ -o app src.o $link_flags -lLLVM-20jl`)
end
```

### Integration with BuildBridge

```julia
using JMake.BuildBridge
using JMake.LLVMEnvironment

# BuildBridge automatically uses LLVMEnvironment
output, exitcode = BuildBridge.execute("clang++", [
    "-c", "file.cpp", "-o", "file.o"
])

# Equivalent to:
with_llvm_env() do
    run(`clang++ -c file.cpp -o file.o`)
end
```

## Related Documentation

- **[ConfigurationManager](ConfigurationManager.md)**: Manages LLVM configuration in jmake.toml
- **[BuildBridge](BuildBridge.md)**: Uses LLVMEnvironment for command execution
- **[LLVMake](LLVMake.md)**: Compilation pipeline using LLVM tools
