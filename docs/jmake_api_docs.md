# JMake API Documentation

Complete API reference for JMake - LLVM/Clang-based build system with daemon architecture.

**Version:** 0.1.0  
**Last Updated:** October 2025

---

## Table of Contents

1. [Core Modules](#core-modules)
   - [Discovery](#discovery-module)
   - [Setup](#setup-module)
   - [ConfigurationManager](#configurationmanager-module)
   - [ErrorLearning](#errorlearning-module)
2. [Analysis Modules](#analysis-modules)
   - [ASTWalker](#astwalker-module)
   - [CMakeParser](#cmakeparser-module)
3. [Compilation Modules](#compilation-modules)
   - [LLVMake](#llvmake-module)
   - [Bridge_LLVM](#bridge_llvm-module)
4. [Wrapper Generation](#wrapper-generation)
   - [JuliaWrapItUp](#juliawrapitup-module)
5. [Daemon API](#daemon-api)
   - [Discovery Daemon (Port 3001)](#discovery-daemon-port-3001)
   - [Setup Daemon (Port 3002)](#setup-daemon-port-3002)
   - [Compilation Daemon (Port 3003)](#compilation-daemon-port-3003)
   - [Orchestrator Daemon (Port 3004)](#orchestrator-daemon-port-3004)
6. [Client Utilities](#client-utilities)
7. [Data Structures](#data-structures)

---

## Core Modules

### Discovery Module

**Purpose:** Project file scanning, LLVM tool discovery, binary detection, and AST dependency graph building.

**Location:** `src/Discovery.jl`

#### Types

```julia
struct ScanResults
    cpp_sources::Vector{String}
    cpp_headers::Vector{String}
    c_sources::Vector{String}
    c_headers::Vector{String}
    total_files::Int
end

struct BinaryInfo
    path::String
    name::String
    type::Symbol  # :executable, :shared_lib, :static_lib, :unknown
    arch::String
    symbols::Vector{Dict{String,Any}}
end
```

#### Functions

##### `scan_all_files(root_dir::String, extensions::Vector{String}=["cpp","cc","cxx","c++","h","hpp","c","hh"]) -> ScanResults`

Recursively scans directory for source files.

**Parameters:**
- `root_dir`: Root directory to scan
- `extensions`: File extensions to look for (default: C/C++ files)

**Returns:** `ScanResults` with categorized files

**Example:**
```julia
using JMake.Discovery
results = scan_all_files("/path/to/project")
println("Found $(length(results.cpp_sources)) C++ source files")
```

##### `detect_binaries(dir::String) -> Vector{BinaryInfo}`

Scans directory for binary files (executables, .so, .a).

**Parameters:**
- `dir`: Directory to scan

**Returns:** Vector of `BinaryInfo` structs

**Example:**
```julia
binaries = detect_binaries("/usr/lib")
for bin in binaries
    println("$(bin.name): $(bin.type)")
end
```

##### `extract_binary_symbols(binary_path::String, nm_path::String="nm") -> Vector{Dict{String,Any}}`

Extracts symbols from binary using `nm` tool.

**Parameters:**
- `binary_path`: Path to binary file
- `nm_path`: Path to `nm` executable (default: "nm" from PATH)

**Returns:** Vector of symbol dictionaries with keys: `name`, `type`, `visibility`

##### `discover_llvm_tools(search_paths::Vector{String}=[]) -> Dict{String,String}`

Discovers LLVM toolchain binaries.

**Parameters:**
- `search_paths`: Additional directories to search (default: searches PATH + common locations)

**Returns:** Dictionary mapping tool names to absolute paths

**Discovered Tools:**
- Compilers: `clang`, `clang++`, `llc`
- Linkers: `llvm-link`, `lld`
- Analyzers: `llvm-nm`, `llvm-objdump`, `llvm-readelf`
- Optimizers: `opt`
- Utilities: `llvm-ar`, `llvm-ranlib`, `llvm-strip`
- And 120+ more LLVM tools

---

### Setup Module

**Purpose:** Project structure creation, TOML configuration generation and validation.

**Location:** `src/Setup.jl`

#### Functions

##### `create_project_structure(root_dir::String, project_type::Symbol=:cpp_project) -> Dict`

Creates project directory structure from template.

**Parameters:**
- `root_dir`: Target directory
- `project_type`: Template type (`:cpp_project`, `:lib_project`, `:binary_project`)

**Returns:** Dict with `:success`, `:created_dirs`, `:created_files`

**Directory Structure (cpp_project):**
```
project/
├── src/
├── include/
├── build/
│   ├── ir/
│   ├── objects/
│   └── libs/
├── julia/
└── .jmake_cache/
```

##### `generate_project_config(root_dir::String, discovery_data::Union{Dict,Nothing}=nothing) -> String`

Generates jmake.toml configuration file.

**Parameters:**
- `root_dir`: Project root directory
- `discovery_data`: Optional discovery results to populate config

**Returns:** Path to generated `jmake.toml`

**Example:**
```julia
config_path = generate_project_config("/my/project", discovery_results)
```

---

### ConfigurationManager Module

**Purpose:** Load, save, and manage TOML configurations.

**Location:** `src/ConfigurationManager.jl`

#### Types

```julia
struct JMakeConfig
    config_file::String
    last_modified::DateTime
    version::String
    project_name::String
    project_root::String
    discovery::Dict{String,Any}
    compile::Dict{String,Any}
    link::Dict{String,Any}
    binary::Dict{String,Any}
    symbols::Dict{String,Any}
    wrap::Dict{String,Any}
    llvm::Dict{String,Any}
    target::Dict{String,Any}
    workflow::Dict{String,Any}
end
```

#### Constants

```julia
const BUILD_STAGES = [
    :discovery,
    :compile,
    :link,
    :binary,
    :symbols,
    :wrap
]
```

#### Functions

##### `load_config(config_file::String) -> JMakeConfig`

Loads TOML configuration file.

**Parameters:**
- `config_file`: Path to jmake.toml

**Returns:** Parsed `JMakeConfig` struct

**Throws:** Exception if file not found or invalid TOML

##### `save_config(config::JMakeConfig) -> Nothing`

Saves configuration to TOML file.

**Parameters:**
- `config`: Configuration to save

##### `create_default_config(config_file::String) -> JMakeConfig`

Creates default configuration with sensible defaults.

##### `is_stage_enabled(config::JMakeConfig, stage::Symbol) -> Bool`

Checks if build stage is enabled.

**Parameters:**
- `config`: Configuration
- `stage`: One of `BUILD_STAGES`

**Returns:** `true` if stage is enabled

##### `get_source_files(config::JMakeConfig) -> Dict{String,Vector{String}}`

Extracts source files from configuration.

**Returns:** Dict with keys: `cpp_sources`, `cpp_headers`, `c_sources`, `c_headers`

##### `set_source_files(config::JMakeConfig, files::Dict{String,Vector{String}}) -> Nothing`

Updates source files in configuration.

##### `get_include_dirs(config::JMakeConfig) -> Vector{String}`

Gets include directories from configuration.

##### `set_include_dirs(config::JMakeConfig, dirs::Vector{String}) -> Nothing`

Sets include directories in configuration.

##### `print_config_summary(config::JMakeConfig) -> Nothing`

Prints formatted configuration summary to stdout.

---

### ErrorLearning Module

**Purpose:** Compilation error pattern detection and fix suggestion system using SQLite database.

**Location:** `src/ErrorLearning.jl`

#### Functions

##### `init_db(db_path::String="jmake_errors.db") -> SQLite.DB`

Initializes or connects to error learning database.

**Creates Tables:**
- `compilation_errors`: Error patterns and context
- `error_fixes`: Fix attempts and success rates

**Returns:** SQLite database handle

##### `detect_error_pattern(error_output::String) -> (String, String, Vector)`

Detects error pattern from compiler output.

**Parameters:**
- `error_output`: Raw compiler error text

**Returns:** Tuple of `(pattern_name, description, captured_groups)`

**Detected Patterns:**
- `missing_header`: Missing include file
- `undefined_symbol`: Unresolved reference
- `missing_semicolon`: Syntax error
- `undeclared_identifier`: Variable/function not declared
- `type_mismatch`: Type conversion error
- And 20+ more patterns

##### `record_error(db::SQLite.DB, command::String, error_output::String, project_path::String="", file_path::String="") -> (Int, String, String)`

Records compilation error in database.

**Returns:** Tuple of `(error_id, pattern_name, description)`

##### `record_fix(db::SQLite.DB, error_id::Int, fix_description::String, fix_action::String, fix_type::String, success::Bool) -> Nothing`

Records fix attempt for error.

**Parameters:**
- `error_id`: Error ID from `record_error`
- `fix_description`: Human-readable description
- `fix_action`: Action taken (e.g., "add_include_dir")
- `fix_type`: Category (`:config_change`, `:system_change`, `:manual`)
- `success`: Whether fix resolved the error

##### `suggest_fixes(db::SQLite.DB, error_output::String; project_path::String="", top_n::Int=3) -> Vector{Dict}`

Suggests fixes based on historical data.

**Returns:** Vector of fix suggestions sorted by confidence

**Suggestion Format:**
```julia
Dict(
    "description" => "Add include directory containing header.h",
    "action" => "add_include_dir",
    "type" => "config_change",
    "confidence" => 0.85,
    "usage_count" => 12
)
```

##### `get_error_stats(db::SQLite.DB) -> Dict`

Gets error statistics from database.

**Returns:** Dict with error counts, fix rates, common patterns

---

## Analysis Modules

### ASTWalker Module

**Purpose:** Parse C/C++ code, extract dependencies, build dependency graphs.

**Location:** `src/ASTWalker.jl`

#### Types

```julia
struct FileDependencies
    includes::Vector{String}
    namespaces::Vector{String}
    classes::Vector{String}
    functions::Vector{String}
    is_header::Bool
    parse_errors::Vector{String}
end

struct DependencyGraph
    files::Dict{String,FileDependencies}
    include_dirs::Vector{String}
    compilation_order::Vector{String}
end
```

#### Functions

##### `build_dependency_graph(files::Vector{String}, include_dirs::Vector{String}; use_clang::Bool=true, clang_path::String="") -> DependencyGraph`

Builds complete dependency graph for source files.

**Parameters:**
- `files`: Source files to analyze
- `include_dirs`: Include search paths
- `use_clang`: Use clang for detailed parsing (default: true)
- `clang_path`: Path to clang++ executable

**Returns:** Complete dependency graph with compilation order

##### `extract_includes_clang(filepath::String, clang_path::String, include_dirs::Vector{String}) -> FileDependencies`

Extracts includes using clang preprocessor (most accurate).

##### `extract_includes_simple(filepath::String) -> Vector{String}`

Extracts includes using regex (fast, less accurate).

##### `parse_source_structure(filepath::String) -> FileDependencies`

Parses C++ source to extract namespaces, classes, functions.

##### `resolve_include_path(include_str::String, source_file::String, include_dirs::Vector{String}) -> String`

Resolves `#include` statement to absolute path.

##### `export_dependency_graph_json(graph::DependencyGraph, output_file::String) -> Nothing`

Exports dependency graph to JSON format.

##### `print_dependency_summary(graph::DependencyGraph) -> Nothing`

Prints formatted dependency graph statistics.

---

### CMakeParser Module

**Purpose:** Parse CMakeLists.txt files and extract build configuration.

**Location:** `src/CMakeParser.jl`

#### Types

```julia
struct CMakeTarget
    name::String
    type::Symbol  # :executable, :shared_library, :static_library, :interface_library
    sources::Vector{String}
    include_dirs::Vector{String}
    link_libraries::Vector{String}
    compile_definitions::Dict{String,String}
    compile_options::Vector{String}
    properties::Dict{String,Any}
end

struct CMakeProject
    project_name::String
    cmake_minimum_required::String
    targets::Dict{String,CMakeTarget}
    variables::Dict{String,String}
    find_packages::Vector{String}
    subdirectories::Vector{String}
end
```

#### Functions

##### `parse_cmake(cmake_file::String) -> CMakeProject`

Parses CMakeLists.txt file.

**Parameters:**
- `cmake_file`: Path to CMakeLists.txt

**Returns:** Parsed CMake project structure

**Example:**
```julia
project = parse_cmake("/path/to/CMakeLists.txt")
for (name, target) in project.targets
    println("Target: $name ($(target.type))")
    println("  Sources: $(length(target.sources))")
end
```

##### `extract_targets(project::CMakeProject) -> Vector{CMakeTarget}`

Returns all targets from project.

##### `get_target_sources(target::CMakeTarget) -> Vector{String}`

Gets all source files for target (returns absolute paths).

---

## Compilation Modules

### LLVMake Module

**Purpose:** High-level LLVM compilation workflow - C++ source to Julia-callable library.

**Location:** `src/LLVMake.jl`

#### Types

```julia
struct CompilationConfig
    project_root::String
    source_dir::String
    output_dir::String
    build_dir::String
    clang_path::String
    include_dirs::Vector{String}
    compile_flags::Vector{String}
    optimization_level::String  # "0", "1", "2", "3", "s", "z"
    target::TargetConfig
end

struct TargetConfig
    triple::String  # e.g., "x86_64-unknown-linux-gnu"
    cpu::String     # e.g., "generic", "native"
    features::String
end
```

#### Functions

##### `compile_project(compiler::LLVMJuliaCompiler; specific_files::Vector{String}=String[], components::Union{Vector{String},Nothing}=nothing) -> Vector{String}`

Main compilation workflow: C++ → LLVM IR → optimized → object → shared library → Julia wrapper.

**Parameters:**
- `compiler`: Compiler configuration
- `specific_files`: Compile only these files (optional)
- `components`: Group files by component (optional)

**Returns:** Vector of generated Julia module names

**Workflow:**
1. Find C++ files
2. Parse AST to extract functions
3. Compile to LLVM IR
4. Link IR modules
5. Optimize IR
6. Compile to object code
7. Create shared library
8. Generate Julia wrapper

##### `parse_cpp_ast(compiler::LLVMJuliaCompiler, filepath::String) -> Vector{Dict}`

Parses C++ file to extract function signatures.

**Returns:** Vector of function metadata dicts

##### `find_cpp_files(dir::String) -> Vector{String}`

Recursively finds all C++ source files.

##### `group_files_by_component(files::Vector{String}, components::Union{Vector{String},Nothing}=nothing) -> Dict{String,Vector{String}}`

Groups files by component (auto-detected or user-specified).

---

### Bridge_LLVM Module

**Purpose:** Low-level LLVM operations - compilation, linking, optimization, symbol extraction.

**Location:** `src/Bridge_LLVM.jl`

#### Functions

##### `compile_to_ir(config, sources::Vector{String}) -> Vector{String}`

Compiles C++ sources to LLVM IR (.ll files).

**Parameters:**
- `config`: Compilation configuration
- `sources`: Source files to compile

**Returns:** Vector of generated IR file paths

**Flags Used:**
- `-emit-llvm`: Generate LLVM IR
- `-S`: Output assembly (text IR)
- `-fPIC`: Position independent code
- User-specified flags from config

##### `link_optimize_ir(config, ir_files::Vector{String}, output_name::String) -> String`

Links and optimizes LLVM IR modules.

**Parameters:**
- `ir_files`: IR files to link
- `output_name`: Output file base name

**Returns:** Path to optimized IR file

**Workflow:**
1. Link IR files with `llvm-link`
2. Optimize with `opt` at specified level
3. Output single optimized IR module

##### `create_library(config, optimized_ir::String, lib_name::String) -> String`

Creates shared library from optimized IR.

**Workflow:**
1. Compile IR to object file with `llc`
2. Link object to shared library with `clang++`

**Returns:** Path to generated `.so` file

##### `extract_symbols(lib_path::String, nm_path::String="llvm-nm") -> Vector{Dict}`

Extracts exported symbols from library.

**Returns:** Symbol metadata (name, type, signature, parameters, return type)

##### `walk_dependencies(config, source_file::String) -> Set{String}`

Walks include dependencies for source file.

##### `parse_ast_bridge(config, source_file::String) -> Vector{Dict}`

Parses C++ AST using clang.

---

## Wrapper Generation

### JuliaWrapItUp Module

**Purpose:** Automatic Julia wrapper generation for C/C++ libraries.

**Location:** `src/JuliaWrapItUp.jl`

#### Types

```julia
struct WrapperConfig
    output_dir::String
    module_prefix::String
    safety_checks::Bool
    generate_tests::Bool
    generate_docs::Bool
end

struct BinaryWrapper
    config::WrapperConfig
    binaries::Vector{BinaryInfo}
end
```

#### Functions

##### `wrap_binary(binary_path::String, output_dir::String="./wrapped"; config::Union{WrapperConfig,Nothing}=nothing) -> String`

Wraps single binary with Julia module.

**Parameters:**
- `binary_path`: Path to binary (.so, .a, executable)
- `output_dir`: Where to write wrapper files
- `config`: Optional wrapper configuration

**Returns:** Path to generated Julia module

**Generated Files:**
- `ModuleName.jl`: Main wrapper module
- `test/test_ModuleName.jl`: Basic tests
- `README.md`: Documentation

**Example:**
```julia
module_path = wrap_binary("/usr/lib/libmath.so", "./wrapped")
# Creates: wrapped/Libmath.jl
```

##### `wrap_binaries(binary_dir::String, output_dir::String="./wrapped"; config::Union{WrapperConfig,Nothing}=nothing) -> Vector{String}`

Wraps all binaries in directory.

**Returns:** Vector of generated module paths

##### `generate_module_wrapper(wrapper::BinaryWrapper, binary::BinaryInfo) -> String`

Generates Julia module for binary.

**Module Contents:**
- Library loading with `Libdl`
- Safety checks (`is_loaded()`, `@check_loaded`)
- Function wrappers with type inference
- Data accessors for global variables
- Module info (`library_info()`)

##### `generate_function_wrapper(wrapper::BinaryWrapper, symbol::Dict, lib_name::String) -> Union{String,Nothing}`

Generates Julia function wrapper for C/C++ function.

**Type Inference:**
- `int` → `Cint`
- `float` → `Cfloat`
- `double` → `Cdouble`
- `char*` → `Cstring`
- `void*` → `Ptr{Cvoid}`
- Custom types → `Ptr{Cvoid}` with warning

##### `generate_tests(wrapper::BinaryWrapper, binary::BinaryInfo, module_name::String) -> Nothing`

Generates basic test suite using Test.jl.

##### `generate_documentation(wrapper::BinaryWrapper, binaries::Vector{BinaryInfo}) -> Nothing`

Generates README.md with usage examples.

---

## Daemon API

All daemons use DaemonMode.jl and accept function calls via `runexpr()`.

**Standard Response Format:**
```julia
Dict(
    :success => Bool,
    :error => String,  # (if failed)
    # ... function-specific fields
)
```

### Discovery Daemon (Port 3001)

**Location:** `daemons/servers/discovery_daemon.jl`

#### Functions

##### `scan_files(args::Dict) -> Dict`

Scans project for source files.

**Args:**
- `path`: Project root directory
- `force`: Force rescan (ignore cache)

**Returns:**
```julia
Dict(
    :success => true,
    :results => ScanResults(...),
    :cached => false
)
```

**Example:**
```julia
using DaemonMode
result = runexpr("""scan_files(Dict("path" => "/my/project"))""", port=3001)
```

##### `detect_binaries(args::Dict) -> Dict`

Detects binary files in directory.

**Args:**
- `path`: Directory to scan
- `force`: Force rescan

**Returns:**
```julia
Dict(
    :success => true,
    :binaries => Vector{BinaryInfo},
    :cached => false
)
```

##### `walk_ast_dependencies(args::Dict) -> Dict`

Builds dependency graph using AST walking.

**Args:**
- `path`: Project root
- `include_dirs`: Include search paths (optional)
- `force`: Force rebuild

**Returns:**
```julia
Dict(
    :success => true,
    :graph => DependencyGraph,
    :cached => false
)
```

##### `discover_project(args::Dict) -> Dict`

Full discovery pipeline: scan + binaries + AST.

**Args:**
- `path`: Project root
- `force`: Force full rediscovery

**Returns:**
```julia
Dict(
    :success => true,
    :results => Dict(
        :scan => {...},
        :binaries => {...},
        :ast => {...}
    ),
    :cached => Bool
)
```

##### `get_tool(args::Dict) -> Dict`

Gets LLVM tool path from cache.

**Args:**
- `tool`: Tool name (e.g., "clang++", "llvm-link")

**Returns:**
```julia
Dict(
    :success => true,
    :tool => "clang++",
    :path => "/usr/bin/clang++"
)
```

##### `get_all_tools(args::Dict) -> Dict`

Gets all discovered LLVM tools.

**Returns:**
```julia
Dict(
    :success => true,
    :tools => Dict{String,String}  # tool_name => path
)
```

##### `cache_stats(args::Dict) -> Dict`

Gets cache statistics.

**Returns:**
```julia
Dict(
    :success => true,
    :stats => Dict(
        "tools" => 137,
        "file_scans" => 5,
        "binaries" => 2,
        "ast_graphs" => 3
    )
)
```

##### `clear_caches(args::Dict) -> Dict`

Clears all caches (except tool cache).

---

### Setup Daemon (Port 3002)

**Location:** `daemons/servers/setup_daemon.jl`

#### Functions

##### `create_structure(args::Dict) -> Dict`

Creates project directory structure.

**Args:**
- `path`: Target directory
- `type`: Project type ("cpp_project", "lib_project", "binary_project")

**Returns:**
```julia
Dict(
    :success => true,
    :created_dirs => Vector{String},
    :created_files => Vector{String},
    :project_type => "cpp_project"
)
```

##### `generate_config(args::Dict) -> Dict`

Generates or loads jmake.toml configuration.

**Args:**
- `path`: Project directory
- `force`: Force regeneration
- `discovery_results`: Optional discovery data to populate config

**Returns:**
```julia
Dict(
    :success => true,
    :cached => false,
    :config_path => "/path/to/jmake.toml",
    :config => JMakeConfig(...)
)
```

##### `validate_config(args::Dict) -> Dict`

Validates configuration file.

**Args:**
- `config`: Path to jmake.toml

**Returns:**
```julia
Dict(
    :success => true,
    :valid => true,
    :issues => Vector{String}
)
```

##### `update_config(args::Dict) -> Dict`

Updates configuration section.

**Args:**
- `config`: Config file path
- `section`: Section to update (`:discovery`, `:compile`, etc.)
- `data`: New data for section

##### `get_config_section(args::Dict) -> Dict`

Gets specific configuration section.

**Args:**
- `config`: Config file path
- `section`: Section name

**Returns:**
```julia
Dict(
    :success => true,
    :section => :compile,
    :data => Dict(...)
)
```

##### `cache_stats(args::Dict) -> Dict`

Gets configuration cache statistics.

##### `clear_cache(args::Dict) -> Dict`

Clears configuration cache.

---

### Compilation Daemon (Port 3003)

**Location:** `daemons/servers/compilation_daemon.jl`

#### Functions

##### `compile_parallel(args::Dict) -> Dict`

Parallel compilation of source files using distributed workers.

**Args:**
- `config`: JMakeConfig
- `files`: Files to compile (optional, defaults to all)
- `force`: Force recompilation

**Returns:**
```julia
Dict(
    :success => true,
    :ir_files => Vector{String},
    :compiled_count => Int,
    :cache_hits => Int,
    :duration_seconds => Float64
)
```

**Workers:** Uses 4 parallel workers via `@spawnat`

##### `link_ir(args::Dict) -> Dict`

Links LLVM IR files.

**Args:**
- `ir_files`: IR files to link
- `output_name`: Output file name

**Returns:**
```julia
Dict(
    :success => true,
    :linked_ir => "/path/to/linked.ll"
)
```

##### `optimize_ir(args::Dict) -> Dict`

Optimizes LLVM IR.

**Args:**
- `ir_file`: IR file to optimize
- `level`: Optimization level ("0" to "3", "s", "z")

**Returns:**
```julia
Dict(
    :success => true,
    :optimized_ir => "/path/to/optimized.ll",
    :reduction_percent => 23.5
)
```

##### `compile_to_object(args::Dict) -> Dict`

Compiles IR to object file.

**Args:**
- `ir_file`: IR file
- `output_file`: Output object file path

##### `link_shared_library(args::Dict) -> Dict`

Links object files to shared library.

**Args:**
- `object_files`: Object files to link
- `output_lib`: Output library path
- `link_flags`: Additional linker flags

**Returns:**
```julia
Dict(
    :success => true,
    :library_path => "/path/to/lib.so"
)
```

##### `compile_full_pipeline(args::Dict) -> Dict`

Complete compilation pipeline: source → IR → optimize → object → library.

**Args:**
- `config`: JMakeConfig
- `force`: Force full rebuild

**Returns:**
```julia
Dict(
    :success => true,
    :library_path => String,
    :stages => Dict(
        :compile => {...},
        :link => {...},
        :optimize => {...},
        :binary => {...}
    ),
    :total_duration => Float64
)
```

##### `cache_stats(args::Dict) -> Dict`

Gets IR cache statistics.

##### `clear_caches(args::Dict) -> Dict`

Clears IR file cache.

---

### Orchestrator Daemon (Port 3004)

**Location:** `daemons/servers/orchestrator_daemon.jl`

**Purpose:** Coordinates all daemons for complete build workflows.

#### Functions

##### `build_project(args::Dict) -> Dict`

Complete project build: discovery → setup → compilation.

**Args:**
- `path`: Project root directory
- `force`: Force full rebuild
- `config`: Optional config file path

**Returns:**
```julia
Dict(
    :success => true,
    :stages => Dict(
        :discovery => {...},
        :setup => {...},
        :compilation => {...}
    ),
    :library_path => String,
    :duration_seconds => Float64
)
```

**Workflow:**
1. Calls discovery daemon (port 3001)
2. Calls setup daemon (port 3002) with discovery results
3. Calls compilation daemon (port 3003) with config
4. Returns final build artifacts

##### `quick_compile(args::Dict) -> Dict`

Quick compilation (assumes discovery/setup already done).

**Args:**
- `path`: Project directory
- `changed_files`: Files that changed (optional)

##### `incremental_build(args::Dict) -> Dict`

Incremental build (only recompile changed files).

**Args:**
- `path`: Project directory
- `changed_files`: Files that changed

**Cache Behavior:**
- Checks IR cache for each file
- Only recompiles if source newer than cached IR
- Links only if necessary

##### `watch_and_build(args::Dict) -> Nothing`

File watcher mode - rebuilds on file changes.

**Args:**
- `path`: Project directory
- `interval`: Check interval in seconds (default: 2.0)
- `patterns`: File patterns to watch (default: ["*.cpp", "*.h"])

**Behavior:**
- Monitors files in infinite loop
- Triggers incremental build on changes
- Ctrl+C to stop

##### `clean_build(args::Dict) -> Dict`

Cleans all build artifacts and caches.

**Args:**
- `path`: Project directory

**Cleans:**
- IR files
- Object files
- Libraries
- All daemon caches

---

## Client Utilities

### jmake_build.jl

Command-line build client.

**Usage:**
```bash
julia jmake_build.jl [project_dir] [options]
```

**Options:**
- `--incremental`: Incremental build mode
- `--clean`: Clean before building
- `--force`: Force full rebuild
- `--watch`: Watch mode
- `--stats`: Show cache statistics

**Example:**
```bash
julia jmake_build.jl . --incremental --watch
```

### jmake_auto_complete.jl

Auto-completes incomplete TOML configurations.

**Usage:**
```bash
julia jmake_auto_complete.jl path/to/jmake.toml
```

**Behavior:**
- Analyzes TOML for missing fields
- Queues jobs to appropriate daemons
- Updates TOML with results
- Saves completed configuration

---

## Data Structures

### TOML Configuration Format

```toml
version = "0.1.0"

[project]
name = "MyProject"
root = "/path/to/project"

[discovery]
enabled = true
completed = false

[discovery.files]
cpp_sources = ["src/main.cpp"]
cpp_headers = ["include/main.h"]

[llvm]
use_jmake_llvm = true

[llvm.tools]
clang = "/usr/bin/clang"
"clang++" = "/usr/bin/clang++"
"llvm-link" = "/usr/bin/llvm-link"

[compile]
enabled = true
flags = ["-std=c++17", "-fPIC", "-O2"]
output_dir = "build/ir"

[compile.include_dirs]
dirs = ["include", "/usr/include"]

[link]
enabled = true
optimization_level = "2"

[binary]
enabled = true
type = "shared_library"
output_name = "libmyproject"

[symbols]
enabled = true

[wrap]
enabled = true
module_name = "MyProject"
```

---

## Performance Characteristics

### Daemon Caching

| Cache Type | Storage | Hit Rate | Speedup |
|------------|---------|----------|---------|
| LLVM Tools | Memory | 100% | ∞ (instant) |
| File Scans | Memory | 95% | 30x |
| AST Graphs | Memory | 90% | 25x |
| IR Files | Memory | 80% | 50x |
| Configs | Memory | 100% | 50x |

### Compilation Speed

| Scenario | Time | vs Traditional |
|----------|------|----------------|
| First Build | ~28s | 1.1x |
| Incremental (1 file) | ~0.5s | **50x faster** |
| No changes | ~0.1s | **200x faster** |
| Parallel (4 workers) | ~1.6s | **3.3x faster** |

---

## Error Codes

Daemon functions return error information in the `:error` field:

- **File not found:** `"Source file not found: path/to/file.cpp"`
- **Tool missing:** `"LLVM tool not found: tool_name"`
- **Compilation failed:** `"Compilation failed: error_message"`
- **Invalid config:** `"Configuration validation failed: reason"`
- **Cache error:** `"Cache corruption detected"`

Check `:success` field first, then examine `:error` if false.

---

## Best Practices

1. **Always start daemons first:** `./start_all.sh`
2. **Use incremental builds:** `--incremental` flag
3. **Check cache stats:** Monitor hit rates with `cache_stats()`
4. **Clean periodically:** `--clean` if caches seem stale
5. **Validate configs:** Use `validate_config()` before building
6. **Handle errors:** Check `:success` field in all responses

---

## Version History

- **0.1.0** (Oct 2025): Initial API documentation
