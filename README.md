# JMake

**A TOML-based build system leveraging LLVM/Clang for automatic Julia bindings generation**

JMake is a unique build system that doesn't replace traditional build systems like CMake or Make. Instead, it leverages the same tools they use (LLVM, Clang) directly from Julia to automatically generate type-safe Julia bindings for C++ code and existing binaries.

## Features

- 🚀 **Single TOML Configuration** - No complex CMakeLists.txt or Makefiles
- 🔍 **Auto-Discovery** - Automatically finds LLVM/Clang tools via UnifiedBridge
- 🧠 **Adaptive Learning** - Learns optimal command patterns over time
- 📦 **Dual Mode** - Compile C++ source OR wrap existing binaries
- 🎯 **Type-Safe** - AST-based parsing for accurate type mapping
- ⚡ **LLVM IR Pipeline** - Full control over optimization and linking
- 🔗 **No Boilerplate** - No manual `ccall` or wrapper code needed

## Architecture

JMake consists of four integrated components:

1. **UnifiedBridge** - Universal bash command wrapper with adaptive learning
2. **LLVMake** - C++ source → Julia compiler (Stage 1)
3. **JuliaWrapItUp** - Binary → Julia wrapper generator (Stage 2)
4. **Bridge_LLVM** - Orchestrator that integrates all components

```
C++ Source ──→ [LLVMake] ──→ LLVM IR ──→ Shared Library ──→ Julia Bindings
                   ↓                           ↓
              AST Parse              [JuliaWrapItUp]
                                           ↓
Binary/Library ─────────────────────→ Julia Wrappers
```

## Installation

```julia
julia> ] add /path/to/JMake  # Local development

# Or activate the project
julia> ] activate /path/to/JMake
julia> using JMake
```

## Quick Start

### Compile C++ to Julia

```julia
using JMake

# 1. Initialize a new C++ project
JMake.init("mymath")
cd("mymath")

# 2. Add your C++ code to src/
# src/math.cpp:
# double fast_sqrt(double x) { return std::sqrt(x); }

# 3. Configure (edit jmake.toml if needed)

# 4. Compile
JMake.compile()

# 5. Use the generated bindings
include("julia/mymath.jl")
result = fast_sqrt(16.0)  # → 4.0
```

### Wrap Existing Binary

```julia
using JMake

# 1. Initialize a binary wrapping project
JMake.init("crypto_bindings", type=:binary)
cd("crypto_bindings")

# 2. Wrap a shared library
JMake.wrap_binary("/usr/lib/libcrypto.so")

# 3. Use the generated wrappers
include("julia_wrappers/Crypto.jl")
```

## Configuration

### jmake.toml (Main Configuration)

```toml
[project]
name = "MyProject"
root = "."

[paths]
source = "src"
output = "julia"
build = "build"

[bridge]
auto_discover = true    # Let UnifiedBridge find tools
enable_learning = true  # Enable adaptive learning

[compile]
flags = ["-O2", "-fPIC", "-std=c++17"]
walk_dependencies = true  # Auto-discover includes

[target]
cpu = "native"
opt_level = "O2"
lto = true

[bindings]
style = "simple"  # simple, advanced, cxxwrap
generate_tests = true
generate_docs = true
```

See [jmake.toml](jmake.toml) for full configuration options.

## API Reference

### Project Management

```julia
JMake.init([dir]; type=:cpp)       # Initialize new project
JMake.info()                        # Show JMake information
JMake.help()                        # Show help
```

### C++ Compilation

```julia
JMake.compile([config])             # Compile entire project
JMake.discover_tools([config])      # Discover LLVM tools
```

### Binary Wrapping

```julia
JMake.wrap([config])                # Wrap all binaries
JMake.wrap_binary(path; config)     # Wrap specific binary
```

### Direct Module Access

```julia
using JMake

# Access submodules directly
compiler = LLVMake.LLVMJuliaCompiler("jmake.toml")
wrapper = JuliaWrapItUp.BinaryWrapper("wrapper_config.toml")

# Use UnifiedBridge for commands
result = UnifiedBridge.run_simple_bash("clang++ --version")
```

## Advanced Features

### Dependency Walking

JMake automatically walks your C++ dependency tree:

```julia
# Automatically finds all #include files
# Uses clang -M for accurate dependency detection
# Handles circular dependencies with max_depth limit
```

### AST-Based Parsing

```julia
# Extracts function signatures directly from Clang AST
# Accurate type information without manual parsing
# Supports C++ templates, namespaces, overloading
```

### Learning System

UnifiedBridge learns optimal command patterns:

```julia
# After multiple compilations...
JMake.discover_tools()  # Shows learned patterns

# Example output:
# clang++: 6 args (confidence: 0.85)
# opt: 5 args (confidence: 0.92)
```

### Parallel Compilation

```toml
[workflow]
parallel = true
jobs = 0  # Auto-detect CPU cores
```

### Custom Type Mappings

```toml
[bindings.type_mappings]
"std::string" = "String"
"std::vector<double>" = "Vector{Float64}"
"std::shared_ptr<T>" = "Ref{T}"
```

## Workflow Stages

JMake compilation pipeline:

1. **discover_tools** - Find LLVM/Clang via UnifiedBridge
2. **walk_deps** - Walk dependency tree with `clang -M`
3. **parse_ast** - Extract functions with `clang -ast-dump=json`
4. **compile_to_ir** - Compile C++ → LLVM IR
5. **optimize_ir** - Optimize with `opt`
6. **link_ir** - Link with `llvm-link`
7. **create_library** - Create `.so` with `clang++`
8. **extract_symbols** - Get exports with `nm`
9. **generate_bindings** - Create Julia wrappers
10. **generate_tests** - Create test suite
11. **generate_docs** - Generate documentation

## Comparison

### vs CMake/Make
- ✅ Single TOML config (not 1000 lines of CMakeLists.txt)
- ✅ No platform-specific conditionals
- ✅ Auto-discovers tools
- ✅ Direct Julia integration

### vs Manual ccall
- ✅ Automatic binding generation
- ✅ Type inference from AST
- ✅ Safety checks
- ✅ Documentation generation

### vs BinaryBuilder.jl
- ✅ Works with local development (not just distribution)
- ✅ Instant iteration (no Docker)
- ✅ Direct LLVM access

### vs CxxWrap.jl
- ✅ No C++ boilerplate (`JLCXX_MODULE`)
- ✅ Works with existing code
- ✅ Handles both C and C++

## Examples

See the [docs/](docs/) directory for detailed examples:

- [BRIDGE_INTEGRATION.md](docs/BRIDGE_INTEGRATION.md) - Complete integration guide
- Example projects coming soon!

## Requirements

- Julia 1.6+
- LLVM/Clang toolchain (auto-discovered)
- Linux/macOS (Windows support planned)

## Development

```bash
git clone <repo>
cd JMake
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using JMake; JMake.info()'
```

## License

[License information to be added]

## Contributing

[Contributing guidelines to be added]

## Acknowledgments

JMake leverages the incredible work of:
- The Julia Language team
- LLVM/Clang developers
- The Julia C/C++ interop ecosystem

---

**JMake** - Making C++/Julia interop as simple as a TOML file ✨
