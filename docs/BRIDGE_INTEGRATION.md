# UnifiedBridge + LLVM/Julia Integration

Complete toolchain for compiling C++ to Julia using UnifiedBridge for universal command wrapping.

## 🎯 What This Solves

**Problem:** C++ build systems are complex (CMake, Make, Bazel...) and interfacing with Julia requires multiple tools (clang, LLVM, nm, objdump, etc.).

**Solution:** Use **UnifiedBridge** as a universal bash wrapper that:
- ✅ Auto-discovers all LLVM tools
- ✅ Learns command patterns dynamically
- ✅ Walks dependency trees with `clang -M`
- ✅ Parses AST with `clang -Xclang -ast-dump=json`
- ✅ Wraps existing binaries without source
- ✅ No native build system required - **just TOML**

## 📁 Architecture

```
┌─────────────────────────────────────────┐
│     UnifiedBridge (Bash Wrapper)        │
│  • Auto-discover tools                  │
│  • Learn command patterns               │
│  • Dynamic symbol table                 │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│   bridge_compiler.jl (Orchestrator)     │
│  • TOML config only                     │
│  • Dependency walking                   │
│  • Pipeline management                  │
└──┬───────────────────────┬──────────────┘
   │                       │
   ▼                       ▼
┌──────────────┐   ┌──────────────────┐
│ llvm_julia.jl│   │ JuliaWrapItUp.jl │
│ (Stage 1)    │   │ (Stage 2)        │
│ C++ → Julia  │   │ Binary → Julia   │
└──────────────┘   └──────────────────┘
```

## 🚀 Quick Start

### 1. Discover Tools

```bash
cd /home/grim/.julia/julia/JMake
julia src/bridge_compiler.jl discover
```

**Output:**
```
🔍 Discovering LLVM tools via UnifiedBridge...
  ✅ clang → /usr/bin/clang
  ✅ clang++ → /usr/bin/clang++
  ✅ llvm-config → /usr/bin/llvm-config-15
  ✅ llvm-link → /usr/bin/llvm-link-15
  ✅ opt → /usr/bin/opt-15
  ✅ nm → /usr/bin/nm
  ✅ objdump → /usr/bin/objdump
  📊 Found 7 tools
```

### 2. Walk Dependencies

```bash
# Automatically find all includes from a C++ file
julia src/integration_example.jl deps src/main.cpp
```

**How it works:**
```julia
# Uses: clang++ -M -MF /dev/null -I./include src/main.cpp
# Output: main.o: main.cpp header1.h header2.h /usr/include/vector ...
# Parsed → ["main.cpp", "header1.h", "header2.h", ...]
```

### 3. Compile Project

```bash
julia src/bridge_compiler.jl compile bridge_llvm.toml
```

**Pipeline stages:**
1. **discover_tools** - UnifiedBridge finds clang/llvm tools
2. **walk_deps** - `clang -M` discovers all includes
3. **parse_ast** - `clang -ast-dump=json` extracts functions
4. **compile_to_ir** - Compile C++ → LLVM IR
5. **optimize_ir** - Run `opt -O2`
6. **link_ir** - Combine with `llvm-link`
7. **create_library** - Create `.so` file
8. **extract_symbols** - Get exports with `nm -DC`
9. **generate_bindings** - Create Julia wrappers

## 📝 Configuration (bridge_llvm.toml)

**Minimal config:**

```toml
[project]
name = "MyLib"

[bridge]
auto_discover = true  # UnifiedBridge finds tools

[paths]
source = "src"
output = "julia"
include = ["include"]

[compile]
flags = ["-O2", "-fPIC", "-std=c++17"]
walk_dependencies = true  # Auto-find includes

[workflow]
stages = ["discover_tools", "walk_deps", "compile_to_ir",
          "link_ir", "create_library", "generate_bindings"]
```

**No CMake/Makefile needed!**

## 🧠 UnifiedBridge Integration

### Automatic Tool Discovery

```julia
# UnifiedBridge discovers tools
tools = discover_llvm_tools()
# → {"clang++" => "/usr/bin/clang++", "opt" => "/usr/bin/opt-15", ...}

# Check if tool exists
if command_exists("clang++")
    path = find_executable("clang++")
end
```

### Dynamic Command Execution

```julia
# Execute with learning
(output, learned_args) = execute_with_learning("clang++",
    ["-S", "-emit-llvm", "-O2", "file.cpp"])

# UnifiedBridge learns: "clang++ typically uses 4 args"
```

### Dependency Walking

```julia
# Walk includes automatically
deps = walk_dependency_tree("main.cpp", ["./include"])

# Output: ["main.cpp", "header1.h", "vector", "string", ...]
```

### AST Parsing

```julia
# Parse C++ AST via UnifiedBridge
(ast_json, _) = execute_with_learning("clang++",
    ["-Xclang", "-ast-dump=json", "-fsyntax-only", "file.cpp"])

ast = JSON.parse(ast_json)
functions = extract_functions_from_ast(ast)
# → [{"name": "foo", "return_type": "int", "params": [...]}, ...]
```

## 🔄 Complete Workflow Example

### Step 1: Create C++ Project

```bash
mkdir -p myproject/src myproject/include

cat > myproject/src/math.cpp <<EOF
#include "math.h"
#include <cmath>

double fast_sqrt(double x) {
    return std::sqrt(x);
}
EOF

cat > myproject/include/math.h <<EOF
#pragma once
double fast_sqrt(double x);
EOF
```

### Step 2: Create Config

```bash
cat > myproject/bridge_llvm.toml <<EOF
[project]
name = "Math"

[bridge]
auto_discover = true

[paths]
source = "src"
include = ["include"]
output = "julia"

[workflow]
stages = ["discover_tools", "walk_deps", "parse_ast",
          "compile_to_ir", "link_ir", "create_library",
          "generate_bindings"]
EOF
```

### Step 3: Compile

```bash
cd myproject
julia /home/grim/.julia/julia/JMake/src/bridge_compiler.jl compile
```

**Output:**
```
🚀 BridgeCompiler - LLVM + UnifiedBridge
============================================================
📁 Project: Math
📁 Source:  src
📁 Output:  julia
============================================================
🔍 Discovering LLVM tools via UnifiedBridge...
  ✅ clang++ → /usr/bin/clang++
  ✅ llvm-link → /usr/bin/llvm-link-15
  ✅ opt → /usr/bin/opt-15
  📊 Found 7 tools

📊 Found 1 C++ files

📂 Walking dependencies from: src/math.cpp
  📊 Found 3 dependencies (depth: 1)

🔍 Parsing AST for all files...
🔍 Parsing AST: math.cpp
  ✅ Found 1 functions (pattern: 6 args)
  📊 Total functions: 1

🔧 Compiling to LLVM IR...
  ✅ math.cpp → math.cpp.ll
  📊 Generated 1 IR files

🔗 Linking and optimizing IR...
  ✅ Linked 1 files
  ✅ Optimized with -O2

📦 Creating shared library...
  ✅ Created: julia/libMath.so

🔍 Extracting symbols...
  ✅ Found 1 symbols

📊 UnifiedBridge Learning Statistics:
  clang++: 6 args (confidence: 0.75)
  llvm-link: 4 args (confidence: 1.00)
  opt: 5 args (confidence: 1.00)

🎉 Compilation complete!
📦 Library: julia/libMath.so
🔧 Symbols: 1
```

### Step 4: Use from Julia

```julia
include("julia/Math.jl")
using .Math

result = fast_sqrt(16.0)  # → 4.0
println("√16 = $result")
```

## 🎓 Advanced Features

### 1. Wrap Existing Binary (No Source Needed)

```bash
# Use JuliaWrapItUp.jl for pre-compiled binaries
julia src/JuliaWrapItUp.jl wrap-binary /usr/lib/libcrypto.so.3
```

**Output:**
```
✓ Found: crypto (shared_lib)
   Symbols: 3127
✅ Generated: Crypto.jl
```

### 2. Learning System

UnifiedBridge learns command patterns:

```julia
# After running clang++ many times...
stats = get_learning_stats()

# Output:
# clang++:
#   patterns: {4 => 15, 6 => 32, 5 => 8}
#   predicted_args: 6  (used 32 times)
#   confidence: 0.58

# Next time: auto-suggest 6 arguments
```

### 3. Parallel Compilation

```toml
[workflow]
parallel = true
jobs = 0  # auto-detect cores
```

### 4. Caching

```toml
[cache]
enabled = true
directory = ".bridge_cache"
ttl = 86400  # 24 hours
```

## 🔧 Troubleshooting

### Tools Not Found

```bash
# Check UnifiedBridge discovery
julia -e 'using UnifiedBridge; discover_system_commands!()'
```

### Dependency Walking Fails

```toml
[compile]
walk_dependencies = false  # Disable auto-discovery
include_dirs = ["include", "/usr/include"]  # Manual includes
```

### AST Parsing Errors

```toml
[compile]
flags = ["-std=c++17", "-fPIC"]  # Try different C++ version
```

### Symbol Extraction Issues

```toml
[symbols]
use_nm = true
use_objdump = true
demangle_cpp = true  # Enable C++ name demangling
```

## 📚 Key Advantages

### vs CMake/Make
- ✅ Single TOML config (not 1000 lines of CMakeLists.txt)
- ✅ No platform-specific conditionals
- ✅ Auto-discovers tools

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
- ✅ Handles C and C++

## 🎯 Summary

**You now have:**
1. **UnifiedBridge** - Universal bash command wrapper with learning
2. **bridge_compiler.jl** - TOML-based orchestrator
3. **llvm_julia.jl** - C++ source → Julia
4. **JuliaWrapItUp.jl** - Binary → Julia

**Workflow:**
```
C++ source → [clang -M] → dependency tree
           → [clang AST] → function signatures
           → [clang IR]  → LLVM bitcode
           → [opt]       → optimized IR
           → [llvm-link] → linked module
           → [clang++]   → libname.so
           → [nm/objdump]→ symbols
           → [generator] → Julia bindings
```

**All controlled by:** One TOML file + UnifiedBridge's automatic tool discovery.

**No native build system required!**

## 📖 See Also

- `example_usage.sh` - Complete end-to-end example
- `integration_example.jl` - Code examples
- `bridge_llvm.toml` - Full config reference

## 🤝 Contributing

This toolchain bridges:
- Julia's metaprogramming
- LLVM's IR infrastructure
- Unix tool composability
- Adaptive learning

It's designed to be **extensible** - add new tools to UnifiedBridge, new stages to the pipeline, or new binding styles.
