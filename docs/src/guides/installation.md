# Installation

## Requirements

- Julia 1.11.7 or later
- LLVM/Clang toolchain (optional - JMake can use system LLVM or bundled version)
- Git (for repository management)

## Installing JMake

### From Julia Package Manager

```julia
using Pkg
Pkg.add(url="https://github.com/yourusername/JMake.jl")
```

### Development Installation

```bash
git clone https://github.com/yourusername/JMake.jl.git
cd JMake.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Dependencies

JMake automatically manages the following dependencies:

- **Clang.jl**: For C++ parsing and binding generation
- **CxxWrap.jl**: For C++ wrapper infrastructure
- **PackageCompiler.jl**: For sysimage creation
- **SQLite.jl**: For error learning database
- **TOML.jl**: For configuration management

## LLVM Toolchain

JMake can work with:

1. **System LLVM**: Uses your system's LLVM installation
2. **Bundled LLVM**: Ships with a pre-configured LLVM toolchain
3. **Custom LLVM**: Point to your own LLVM build directory

### Verifying LLVM Installation

```julia
using JMake
JMake.LLVMEnvironment.print_toolchain_info()
```

## Post-Installation

Verify your installation:

```julia
using JMake
JMake.info()  # Display JMake information
JMake.help()  # Show command reference
```

## Building Documentation Locally

```bash
cd docs
julia --project
```

```julia
using Pkg
Pkg.instantiate()
include("make.jl")
```

The documentation will be built in `docs/build/`.
