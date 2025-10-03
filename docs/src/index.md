# JMake.jl

*Automated C++ to Julia compilation system with full discovery, configuration, and build pipeline*

## Overview

JMake is a **complete automated build system** that takes C++ projects and produces Julia-callable shared libraries. Point it at any C++ codebase, and JMake automatically:

1. **Discovers** all source files, headers, and dependencies
2. **Analyzes** AST relationships using Clang
3. **Configures** complete build settings (jmake.toml)
4. **Compiles** C++ → LLVM IR → optimized shared library
5. **Extracts** all exported symbols
6. **Generates** Julia bindings (optional)

**One command. Complete automation.**

## Key Features

### 🎯 Core Functionality (Production Ready)

- **✅ Automatic Discovery**: Scans projects, finds all C++/C files, headers, binaries
- **✅ LLVM Toolchain**: Embedded LLVM 20.1.2 with 52+ tools (clang, opt, llvm-link)
- **✅ AST Analysis**: Full dependency graph with 100+ files analyzed
- **✅ Auto-Configuration**: Generates complete jmake.toml with all settings
- **✅ Full Pipeline**: C++ → IR → Link → Optimize → Shared Library
- **✅ Symbol Extraction**: All extern "C" functions exported and verified
- **✅ Incremental Builds**: 16-200x faster rebuilds with smart caching
- **✅ Error Learning**: SQLite database tracks and learns from compilation errors

### ⚡ Performance (Tested)

| Build Type | Time | vs Traditional |
|------------|------|----------------|
| First Build | 5-10s | Baseline |
| Incremental | 0.3-2s | **16-50x faster** ⚡ |
| No Changes | 0.1s | **200x faster** ⚡ |

### 🏗️ Advanced Features

- **📦 CMake Integration**: Import CMakeLists.txt without running CMake
- **🔧 Binary Wrapping**: Wrap existing .so/.dll libraries
- **⚡ Daemon System**: Background build servers for continuous compilation
- **🔄 Job Queue**: TOML-driven task system with dependencies
- **📊 Watch Mode**: Auto-rebuild on file changes

## Quick Start

### Option 1: Automatic (Recommended)

```julia
using JMake

# Point JMake at any C++ project
# It handles EVERYTHING automatically
JMake.compile("/path/to/cpp/project")

# Use the compiled library
lib = "julia/libmyproject.so"
result = ccall((:my_function, lib), Int32, (Int32,), 42)
```

### Option 2: New Project

```julia
using JMake

# Create project structure
JMake.init("mymath")
cd("mymath")

# Add C++ code to src/
# JMake auto-discovers and compiles
JMake.compile()
```

## What JMake Does Automatically

```
Input: /path/to/cpp/project/
       ├── src/*.cpp
       └── include/*.h

JMake runs:
  1. Discovery  → Finds 23 C++ files, 15 headers
  2. AST Walk   → Analyzes 104 dependencies
  3. LLVM Find  → Discovers 52 tools
  4. Config Gen → Creates jmake.toml
  5. Compile    → C++ → LLVM IR (parallel)
  6. Link       → Merges IR files
  7. Optimize   → Applies -O2/-O3
  8. Library    → Creates libproject.so
  9. Symbols    → Extracts 47 functions

Output: julia/libproject.so (ready to use!)
        build/*.ll (LLVM IR files)
        jmake.toml (complete config)
```

## Components

### Core Modules

- **LLVMEnvironment**: Isolated LLVM toolchain management
- **ConfigurationManager**: TOML-based project configuration
- **Discovery**: Automatic project structure analysis
- **ASTWalker**: C++ AST dependency analysis
- **CMakeParser**: CMake project parsing and conversion

### Build Pipeline

- **LLVMake**: C++ source → Julia compiler
- **JuliaWrapItUp**: Binary → Julia wrapper generator
- **BuildBridge**: Command execution with error learning
- **ClangJLBridge**: Clang.jl integration for binding generation

### Advanced Features

- **Daemon System**: Background compilation with job queue
- **Error Learning**: Automated error pattern recognition
- **Sysimage Support**: Custom Julia sysimages for faster startup

## Documentation Structure

```@contents
Pages = [
    "guides/installation.md",
    "guides/quickstart.md",
    "api/jmake.md",
]
Depth = 2
```

## Package Version

Current version: `v0.1.0` (defined as `JMake.VERSION`)
