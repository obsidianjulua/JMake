# JMake.jl

> A TOML-based build system leveraging LLVM/Clang for automatic Julia bindings generation

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Julia 1.11+](https://img.shields.io/badge/julia-1.11+-blue.svg)](https://julialang.org)

## Overview

JMake is a comprehensive build system that bridges C++ and Julia by automatically generating high-quality Julia bindings from C++ source code or binary libraries. It leverages LLVM/Clang tooling to provide a seamless workflow for Julia developers who need to interface with C++ code.

## Key Features

- 🚀 **Automatic Bindings Generation**: Convert C++ source code or binary libraries to Julia bindings
- 📦 **CMake Integration**: Import existing CMake projects without running CMake
- 🔧 **LLVM Toolchain**: Isolated LLVM environment with 137+ tools for advanced workflows
- 🎯 **Smart Discovery**: Automatic project structure analysis and configuration
- 📊 **Error Learning**: SQLite-backed error tracking and learning system
- ⚡ **Daemon Architecture**: High-performance background build system with job queue
- 🔄 **Incremental Builds**: Efficient recompilation with dependency tracking

## Quick Start

### Installation

```julia
using Pkg
Pkg.add(url="https://github.com/yourusername/JMake.jl")
```

### Simple Example

```julia
using JMake

# Initialize a new C++ project
JMake.init("myproject")
cd("myproject")

# Add your C++ files to src/
# Configure jmake.toml

# Compile to Julia bindings
JMake.compile()

# Use the generated bindings
include("julia/MyProject.jl")
using .MyProject
```

## Documentation

Full documentation is available at [https://yourusername.github.io/JMake.jl](https://yourusername.github.io/JMake.jl) or build locally:

```bash
cd docs
julia --project
```

```julia
using Pkg
Pkg.instantiate()
include("make.jl")
```

### Quick Links

- [Installation Guide](docs/src/guides/installation.md)
- [Quick Start Tutorial](docs/src/guides/quickstart.md)
- [API Reference](docs/src/api/jmake.md)
- [Examples](docs/src/examples/basic_cpp.md)
- [Architecture](docs/src/architecture/overview.md)

## Features in Detail

### C++ Source Compilation

Compile C++ source code directly to Julia-compatible shared libraries:

```julia
# Initialize C++ project
JMake.init("mathlib")

# Add C++ sources to src/
# Configure jmake.toml

# Compile
JMake.compile()
```

### Binary Wrapping

Wrap existing binary libraries without source code:

```julia
# Initialize wrapper project
JMake.init("ssl_wrapper", type=:binary)

# Wrap library
JMake.wrap_binary("/usr/lib/libssl.so")
```

### CMake Project Import

Import CMake projects without needing CMake installed:

```julia
# Import CMake project
JMake.import_cmake("third_party/CMakeLists.txt")

# Compile imported project
JMake.compile()
```

### Error Learning System

Automatically learn from compilation errors:

```julia
# Errors are automatically logged and analyzed
JMake.compile()  # May fail with error

# View similar past errors and solutions
JMake.get_error_stats()

# Export error log
JMake.export_errors("errors.md")
```

### Daemon System

Background build system for continuous compilation:

```bash
cd daemons
./start_all.sh  # Start daemon system
./status.sh     # Check status
./stop_all.sh   # Stop daemons
```

## Project Structure

```
JMake/
├── src/                    # Core modules
│   ├── JMake.jl           # Main module
│   ├── LLVMEnvironment.jl # LLVM toolchain management
│   ├── LLVMake.jl         # C++ compiler
│   ├── JuliaWrapItUp.jl   # Binary wrapper generator
│   ├── Discovery.jl       # Project discovery
│   ├── ASTWalker.jl       # C++ AST analysis
│   ├── CMakeParser.jl     # CMake parsing
│   ├── BuildBridge.jl     # Command execution
│   └── ErrorLearning.jl   # Error intelligence
├── daemons/               # Daemon system
│   ├── servers/          # Daemon servers
│   ├── clients/          # Client utilities
│   └── handlers/         # Event handlers
├── docs/                  # Documentation
├── test/                  # Test suite
└── examples/             # Example projects
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

## Requirements

- Julia 1.11.7 or later
- LLVM/Clang toolchain (optional - can use bundled version)
- Git (for repository management)

## Examples

### Basic Math Library

```cpp
// src/math.cpp
extern "C" {
    double add(double a, double b) { return a + b; }
    double multiply(double a, double b) { return a * b; }
}
```

```julia
# Compile
JMake.compile()

# Use
include("julia/MathLib.jl")
using .MathLib
result = add(5.0, 3.0)  # 8.0
```

See [examples/](examples/) for more comprehensive examples.

## Testing

Run the test suite:

```julia
using Pkg
Pkg.test("JMake")
```

Or manually:

```julia
include("test/runtests.jl")
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
git clone https://github.com/yourusername/JMake.jl.git
cd JMake.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. test/runtests.jl
```

## Roadmap

- [ ] Plugin system for custom backends
- [ ] Distributed compilation support
- [ ] Cloud-based LLVM toolchain
- [ ] Support for Rust, Go bridges
- [ ] GUI configuration tool
- [ ] Package registry integration

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on top of [Clang.jl](https://github.com/JuliaInterop/Clang.jl)
- Uses [CxxWrap.jl](https://github.com/JuliaInterop/CxxWrap.jl) for C++ wrapping
- LLVM project for the amazing toolchain

## Citation

If you use JMake in your research, please cite:

```bibtex
@software{jmake2024,
  title = {JMake.jl: LLVM-based Build System for Julia-C++ Interop},
  author = {Your Name},
  year = {2024},
  url = {https://github.com/yourusername/JMake.jl}
}
```

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/JMake.jl/issues)
- **Documentation**: [Online Docs](https://yourusername.github.io/JMake.jl)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/JMake.jl/discussions)

---

Made with ❤️ for the Julia community
