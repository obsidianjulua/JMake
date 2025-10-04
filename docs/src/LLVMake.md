# LLVMake Module

**Complete C++ to Julia Compiler via LLVM IR**

The `LLVMake` module is JMake's core compilation engine that transforms C++ code into Julia-callable shared libraries. It orchestrates the entire compilation pipeline: C++ → LLVM IR → optimization → shared library → Julia bindings, with full control over target configuration, optimization passes, and binding generation.

## Overview

LLVMake provides a **project-based compiler** that:

- **Compiles C++ to LLVM IR**: Uses clang++ to generate LLVM intermediate representation
- **Optimizes IR**: Applies LLVM optimization passes (O0/O1/O2/O3/Os/Oz)
- **Links IR modules**: Combines multiple .ll files into unified IR
- **Generates shared libraries**: Creates .so files with proper symbol export
- **Produces Julia bindings**: Auto-generates ccall wrappers with type mappings
- **AST-based function extraction**: Parses Clang AST (JSON) to discover functions
- **Error learning integration**: Records and learns from compilation errors
- **Multi-component support**: Groups files into logical components

This is not just a wrapper around clang - it's a complete build system specialized for C++/Julia interop.

## Key Concepts

### Compilation Pipeline

```
C++ Source Files
      ↓
  Parse AST (Clang -ast-dump=json)
      ↓
Extract Functions → Filter patterns
      ↓
Compile to IR (.cpp → .ll)
      ↓
Link IR modules (llvm-link)
      ↓
Optimize IR (opt -O2)
      ↓
Compile to shared lib (.ll → .so)
      ↓
Generate Julia bindings (.jl)
      ↓
Julia Module Ready
```

### Project-Based Configuration

LLVMake uses `jmake.toml` for project configuration:

```toml
[paths]
source = "src"
output = "julia"
build = "build"

[target]
cpu = "generic"
opt_level = "O2"
debug = false

[compile]
include_dirs = ["include"]
libraries = ["mylib"]

[bindings]
style = "simple"
exclude_patterns = ["^internal_"]
```

### Component Organization

Large projects are split into components (auto-detected or manual):

```
project/
  src/
    core/         → Component: "core"
      math.cpp
      utils.cpp
    graphics/     → Component: "graphics"
      render.cpp
    test/         → Component: "test" (excluded)
```

Each component becomes a separate Julia module.

## Architecture

### Type Hierarchy

```
CompilerConfig
  ├─ project_root, source_dir, output_dir, build_dir
  ├─ llvm_root, clang_path, llvm_link_path, opt_path
  ├─ target: TargetConfig
  ├─ include_dirs, lib_dirs, libraries
  └─ binding_style, type_mappings, patterns

TargetConfig
  ├─ triple (e.g., "x86_64-unknown-linux-gnu")
  ├─ cpu ("generic", "native", "haswell")
  ├─ features (["+avx2", "-sse4.2"])
  ├─ opt_level ("O0", "O1", "O2", "O3", "Os", "Oz")
  ├─ debug, lto
  └─ sanitizers (["address", "thread"])

LLVMJuliaCompiler
  ├─ config: CompilerConfig
  └─ metadata: Dict{String,Any}
```

### AST Parsing Strategy

LLVMake uses two methods for extracting functions:

1. **Clang AST (preferred)**: `clang++ -Xclang -ast-dump=json`
   - Accurate type information
   - Handles templates and overloads
   - Parses parameters with full types

2. **Regex fallback**: Pattern matching on source
   - Used if AST parsing fails
   - Less accurate but more robust
   - Handles non-standard code

## API Reference

### Types

#### `TargetConfig`

Compilation target configuration.

**Constructor**:
```julia
TargetConfig(;
    triple::String="",           # Target triple (empty = host)
    cpu::String="generic",       # Target CPU
    features::Vector{String}=[], # CPU features
    opt_level::String="O2",      # Optimization level
    debug::Bool=false,           # Debug symbols
    lto::Bool=false,             # Link-time optimization
    sanitizers::Vector{String}=[]  # Sanitizers
)
```

**Example**:
```julia
# Generic portable build
target = TargetConfig()

# Native optimized build
target = TargetConfig(
    cpu="native",
    features=["+avx2", "+fma"],
    opt_level="O3",
    lto=true
)

# Debug build with sanitizers
target = TargetConfig(
    opt_level="O0",
    debug=true,
    sanitizers=["address", "undefined"]
)
```

---

#### `CompilerConfig`

Complete project compiler configuration.

**Fields**:
- `project_root::String` - Project root directory
- `source_dir::String` - C++ source directory
- `output_dir::String` - Julia output directory
- `build_dir::String` - Build artifacts directory
- `llvm_root::Union{String,Nothing}` - LLVM installation (nothing = system)
- `clang_path::String` - Path to clang++
- `llvm_link_path::String` - Path to llvm-link
- `opt_path::String` - Path to opt
- `target::TargetConfig` - Target configuration
- `include_dirs::Vector{String}` - Include directories
- `lib_dirs::Vector{String}` - Library directories
- `libraries::Vector{String}` - Libraries to link
- `defines::Dict{String,String}` - Preprocessor defines
- `extra_flags::Vector{String}` - Additional compiler flags
- `binding_style::Symbol` - :simple, :advanced, :cxxwrap
- `type_mappings::Dict{String,String}` - C++ → Julia type map
- `exclude_patterns::Vector{Regex}` - Function name exclusions
- `include_patterns::Vector{Regex}` - Function name inclusions

Typically loaded from `jmake.toml` via `load_config()`.

---

#### `LLVMJuliaCompiler`

Main compiler instance.

**Constructors**:
```julia
# From config file
compiler = LLVMJuliaCompiler("jmake.toml")

# From config object
compiler = LLVMJuliaCompiler(config::CompilerConfig)
```

**Fields**:
- `config::CompilerConfig` - Compiler configuration
- `metadata::Dict{String,Any}` - Compilation metadata

### Core Functions

#### `compile_project(compiler::LLVMJuliaCompiler; specific_files=[], components=nothing) -> Vector{String}`

Main compilation workflow - compiles entire project.

**Arguments**:
- `compiler::LLVMJuliaCompiler` - Compiler instance
- `specific_files::Vector{String}=[]` - Compile only these files
- `components::Union{Vector{String},Nothing}=nothing` - Component filter

**Returns**: Vector of generated module names

**Example**:
```julia
# Compile entire project
compiler = LLVMJuliaCompiler("jmake.toml")
modules = compile_project(compiler)

# Compile specific files
modules = compile_project(compiler,
    specific_files=["src/core/math.cpp"])

# Compile specific components
modules = compile_project(compiler,
    components=["core", "graphics"])
```

**Workflow**:
1. Find/filter C++ files
2. Group by component
3. Parse AST to extract functions
4. Compile to LLVM IR
5. Link and optimize IR
6. Create shared library
7. Generate Julia bindings
8. Save metadata

---

#### `load_config(config_file::String) -> CompilerConfig`

Load configuration from TOML file.

**Arguments**:
- `config_file::String` - Path to jmake.toml

**Returns**: `CompilerConfig` instance

**Example**:
```julia
config = load_config("jmake.toml")
println("Project: ", config.project_root)
println("Output: ", config.output_dir)
```

**Auto-creates** default config if file doesn't exist.

---

#### `create_default_config(config_file::String)`

Create default jmake.toml configuration file.

**Example**:
```julia
create_default_config("myproject/jmake.toml")
```

**Generated Config**:
```toml
project_root = "."

[paths]
source = "src"
output = "julia"
build = "build"

[llvm]
# Leave empty for system LLVM

[target]
cpu = "generic"
opt_level = "O2"

[compile]
include_dirs = ["include"]
libraries = []

[bindings]
style = "simple"
exclude_patterns = ["^test_", "^internal_"]
```

### Compilation Functions

#### `compile_to_ir(compiler::LLVMJuliaCompiler, cpp_files::Vector{String}) -> Vector{String}`

Compile C++ files to LLVM IR (.ll files).

**Arguments**:
- `compiler::LLVMJuliaCompiler` - Compiler instance
- `cpp_files::Vector{String}` - C++ source files

**Returns**: Paths to generated .ll files

**Example**:
```julia
ir_files = compile_to_ir(compiler, [
    "src/math.cpp",
    "src/utils.cpp"
])
# Returns: ["build/math.cpp.ll", "build/utils.cpp.ll"]
```

**Process**:
1. Build compiler flags from config
2. For each .cpp file:
   - Run `clang++ -S -emit-llvm flags -o file.ll file.cpp`
   - Record errors in ErrorLearning database
   - Suggest fixes on failure

---

#### `optimize_and_link_ir(compiler::LLVMJuliaCompiler, ir_files::Vector{String}, output_name::String) -> String`

Link and optimize LLVM IR files.

**Arguments**:
- `compiler::LLVMJuliaCompiler` - Compiler instance
- `ir_files::Vector{String}` - IR files to link
- `output_name::String` - Output base name

**Returns**: Path to optimized IR file

**Example**:
```julia
linked_ir = optimize_and_link_ir(compiler, ir_files, "mylib")
# Returns: "build/mylib.opt.ll"
```

**Process**:
1. Link: `llvm-link -S -o linked.ll ir_files...`
2. Optimize: `opt -S -O2 -o optimized.ll linked.ll`

---

#### `compile_ir_to_shared_lib(compiler::LLVMJuliaCompiler, ir_file::String, lib_name::String) -> String`

Compile IR to shared library.

**Arguments**:
- `compiler::LLVMJuliaCompiler` - Compiler instance
- `ir_file::String` - Optimized IR file
- `lib_name::String` - Library name (without lib prefix)

**Returns**: Path to generated .so file

**Example**:
```julia
lib_path = compile_ir_to_shared_lib(compiler,
    "build/mylib.opt.ll", "mylib")
# Returns: "julia/libmylib.so"
```

**Process**:
1. Compile: `clang++ -shared flags -o libmylib.so mylib.ll`
2. Add library search paths (-L)
3. Link libraries (-l)

### AST and Binding Functions

#### `parse_cpp_ast(compiler::LLVMJuliaCompiler, cpp_file::String) -> Vector`

Parse C++ file using Clang AST.

**Arguments**:
- `compiler::LLVMJuliaCompiler` - Compiler instance
- `cpp_file::String` - C++ source file

**Returns**: Vector of function info dictionaries

**Example**:
```julia
functions = parse_cpp_ast(compiler, "src/math.cpp")

for func in functions
    println("Function: $(func["name"])")
    println("  Returns: $(func["return_type"])")
    for param in func["params"]
        println("  Param: $(param["name"]) :: $(param["type"])")
    end
end
```

**Function Info Structure**:
```julia
Dict(
    "name" => "calculate",
    "return_type" => "double",
    "params" => [
        Dict("name" => "x", "type" => "double"),
        Dict("name" => "y", "type" => "int")
    ]
)
```

**Fallback**: Uses `parse_cpp_simple()` if AST parsing fails.

---

#### `generate_julia_bindings(compiler::LLVMJuliaCompiler, lib_name::String, functions::Vector) -> String`

Generate Julia bindings for C++ functions.

**Arguments**:
- `compiler::LLVMJuliaCompiler` - Compiler instance
- `lib_name::String` - Library name
- `functions::Vector` - Function information from AST

**Returns**: Path to generated .jl file

**Example**:
```julia
binding_file = generate_julia_bindings(compiler, "mylib", functions)
# Returns: "julia/mylib.jl"
```

**Generated Bindings** (simple style):
```julia
module Mylib

using Libdl

const _lib_handle = Libdl.dlopen("libmylib.so")

const CppTypeMap = Dict{String, DataType}(
    "double" => Cdouble,
    "int" => Cint,
    ...
)

function calculate(x::Cdouble, y::Cint)
    ccall(
        (:calculate, _lib_handle),
        Cdouble,
        (Cdouble, Cint),
        x, y
    )
end

export calculate

end # module
```

### Utility Functions

#### `find_cpp_files(dir::String) -> Vector{String}`

Recursively find all C++ files in directory.

**Returns**: Vector of C++ file paths (.cpp, .cc, .cxx, .c++)

---

#### `group_files_by_component(files::Vector{String}, components=nothing) -> Dict{String,Vector{String}}`

Group files into components.

**Arguments**:
- `files::Vector{String}` - C++ files
- `components::Union{Vector{String},Nothing}` - Component names (nothing = auto-detect)

**Returns**: Dict mapping component name → files

**Example**:
```julia
# Auto-detect by directory
files = ["src/core/math.cpp", "src/graphics/render.cpp"]
groups = group_files_by_component(files, nothing)
# {"core" => ["src/core/math.cpp"], "graphics" => ["src/graphics/render.cpp"]}

# Manual grouping
groups = group_files_by_component(files, ["core"])
# {"core" => ["src/core/math.cpp"], "misc" => ["src/graphics/render.cpp"]}
```

---

#### `get_compiler_flags(compiler::LLVMJuliaCompiler) -> Vector{String}`

Get compiler flags from configuration.

**Returns**: Vector of clang++ flags

**Example**:
```julia
flags = get_compiler_flags(compiler)
# ["-std=c++17", "-fPIC", "-O2", "-mcpu=generic", "-Iinclude", "-DNDEBUG"]
```

## Integration Examples

### Complete Build Workflow

```julia
using JMake.LLVMake

# Initialize project
LLVMake.main(["init", "myproject"])

# Edit myproject/jmake.toml as needed

# Compile
cd("myproject")
compiler = LLVMJuliaCompiler("jmake.toml")
modules = compile_project(compiler)

# Use generated bindings
include("julia/mylib.jl")
using .Mylib

result = calculate(3.14, 42)
```

### Custom Configuration

```julia
# Create custom config
config = load_config("jmake.toml")

# Modify for optimized build
config.target.cpu = "native"
config.target.opt_level = "O3"
config.target.lto = true

# Apply custom type mappings
config.type_mappings["std::vector<double>"] = "Vector{Float64}"

# Rebuild with new config
compiler = LLVMJuliaCompiler(config)
compile_project(compiler)
```

### Multi-Component Project

```julia
compiler = LLVMJuliaCompiler("jmake.toml")

# Compile only core and math components
modules = compile_project(compiler,
    components=["core", "math"])

# Generated files:
# julia/core.jl
# julia/math.jl
# julia/CompiledCpp.jl (main module)

# Usage
include("julia/CompiledCpp.jl")
using .CompiledCpp
using .CompiledCpp.Core
using .CompiledCpp.Math
```

### Error Learning Integration

```julia
compiler = LLVMJuliaCompiler("jmake.toml")

# Compilation with error learning
modules = compile_project(compiler)

# If compilation fails, check suggestions
using JMake.BuildBridge
stats = BuildBridge.get_error_stats("build/jmake_errors.db")
println("Total errors: ", stats["total_errors"])
println("Success rate: ", stats["success_rate"])

# Export error log
BuildBridge.export_error_log("build/jmake_errors.db",
    "error_analysis.md")
```

### Advanced Binding Generation

```julia
# Configure advanced bindings
config = load_config("jmake.toml")
config.binding_style = :advanced

# Custom type mappings
config.type_mappings = Dict(
    "std::string" => "String",
    "std::vector<double>" => "Vector{Float64}",
    "Eigen::VectorXd" => "Vector{Float64}",
    "MyCustomType*" => "Ptr{Cvoid}"
)

# Exclude internal functions
config.exclude_patterns = [
    r"^_",              # Leading underscore
    r"^internal_",      # Internal prefix
    r"::operator",      # C++ operators
    r"^test_"           # Test functions
]

# Only include API functions
config.include_patterns = [
    r"^api_",           # Must start with api_
    r"^public_"         # Or public_
]

compiler = LLVMJuliaCompiler(config)
compile_project(compiler)
```

### Incremental Compilation

```julia
compiler = LLVMJuliaCompiler("jmake.toml")

# Compile single file
compile_project(compiler,
    specific_files=["src/math/vector.cpp"])

# Recompile modified component
compile_project(compiler,
    components=["math"])
```

## Command-Line Interface

LLVMake provides a CLI for standalone use:

```bash
# Initialize new project
julia src/LLVMake.jl init myproject

# Compile project
julia src/LLVMake.jl compile

# Compile specific file
julia src/LLVMake.jl compile-file src/math.cpp

# Show project info
julia src/LLVMake.jl info

# Clean build artifacts
julia src/LLVMake.jl clean
```

**CLI Commands**:

- `init [project_dir]` - Create project structure and jmake.toml
- `compile [config_file]` - Compile entire project
- `compile-file <file.cpp> [config_file]` - Compile single file
- `info [config_file]` - Display project information
- `clean [config_file]` - Remove build artifacts

## Design Patterns

### Pipeline Architecture

LLVMake uses a **pipeline pattern** for compilation:

```julia
C++ Files
    ↓ [parse_cpp_ast]
Functions
    ↓ [filter_functions]
Filtered Functions
    ↓ [compile_to_ir]
IR Files
    ↓ [optimize_and_link_ir]
Optimized IR
    ↓ [compile_ir_to_shared_lib]
Shared Library
    ↓ [generate_julia_bindings]
Julia Module
```

Each stage is independent and testable.

### Configuration Inheritance

```julia
# Project config (jmake.toml)
[target]
opt_level = "O2"

# Runtime override
config = load_config("jmake.toml")
config.target.opt_level = "O3"  # Override for this build
```

## Limitations and Edge Cases

### Template Functions

C++ templates require instantiation:

```cpp
template<typename T>
T add(T a, T b) { return a + b; }

// Explicit instantiation for Julia
template double add<double>(double, double);
template int add<int>(int, int);
```

Only explicitly instantiated templates are exported.

### Function Overloads

C++ overloads mangle to different symbols:

```cpp
void foo(int x);     // _Z3fooi
void foo(double x);  // _Z3food
```

Julia bindings generate separate functions or use manual symbol names.

### Complex Types

Advanced C++ types need manual mapping:

```julia
# Custom struct wrapper
config.type_mappings["MyClass*"] = "Ptr{Cvoid}"

# Manual conversion functions needed in Julia
function MyClass(ptr::Ptr{Cvoid})
    # Construct Julia wrapper
end
```

## Performance Considerations

### Optimization Levels

| Level | Speed | Size | Use Case |
|-------|-------|------|----------|
| O0 | Fast compile | Large | Debug |
| O1 | Balanced | Medium | Development |
| O2 | Optimized | Small | Production (default) |
| O3 | Maximum | Larger | Performance-critical |
| Os | Slower compile | Smallest | Size-constrained |
| Oz | Slowest compile | Minimal | Embedded |

### Link-Time Optimization

```julia
config.target.lto = true  # Enable LTO
```

**Pros**: Better optimization across translation units
**Cons**: Slower compile time, larger memory usage

### Parallel Compilation

```julia
# Files compiled in parallel automatically
# Control with: config.compile["parallel"] = true
```

## Related Documentation

- **[LLVMEnvironment](LLVMEnvironment.md)**: LLVM toolchain used by LLVMake
- **[BuildBridge](BuildBridge.md)**: Command execution and error learning
- **[ErrorLearning](ErrorLearning.md)**: Compilation error database
- **[ConfigurationManager](ConfigurationManager.md)**: jmake.toml management
