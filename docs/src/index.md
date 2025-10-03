# JMake.jl

*A TOML-based build system leveraging LLVM/Clang for automatic Julia bindings generation*

## Overview

JMake is a comprehensive build system that bridges C++ and Julia by automatically generating high-quality Julia bindings from C++ source code or binary libraries. It leverages LLVM/Clang tooling to provide a seamless workflow for Julia developers who need to interface with C++ code.

## Key Features

- **🚀 Automatic Bindings Generation**: Convert C++ source code or binary libraries to Julia bindings
- **📦 CMake Integration**: Import existing CMake projects without running CMake
- **🔧 LLVM Toolchain**: Isolated LLVM environment with 137+ tools for advanced workflows
- **🎯 Smart Discovery**: Automatic project structure analysis and configuration
- **📊 Error Learning**: SQLite-backed error tracking and learning system
- **⚡ Daemon Architecture**: High-performance background build system with job queue
- **🔄 Incremental Builds**: Efficient recompilation with dependency tracking

## Quick Start

```julia
using JMake

# Initialize a new C++ project
JMake.init("myproject")
cd("myproject")

# Add your C++ source files to src/
# Configure jmake.toml as needed

# Compile to Julia bindings
JMake.compile()
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

```@docs
JMake.VERSION
```
