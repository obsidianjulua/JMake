# LLVMEnvironment

LLVM toolchain management and environment isolation.

## Overview

The LLVMEnvironment module provides isolated LLVM toolchain management, ensuring JMake uses the correct LLVM version without interfering with system installations.

## Functions

```@docs
JMake.LLVMEnvironment.get_toolchain
JMake.LLVMEnvironment.verify_toolchain
JMake.LLVMEnvironment.print_toolchain_info
JMake.LLVMEnvironment.with_llvm_env
```

## Usage Examples

### Get Toolchain Information

```julia
using JMake

# Get current toolchain
toolchain = JMake.LLVMEnvironment.get_toolchain()

# Verify it's working
JMake.LLVMEnvironment.verify_toolchain()

# Print detailed info
JMake.LLVMEnvironment.print_toolchain_info()
```

### Execute with LLVM Environment

```julia
# Run command with LLVM environment set
JMake.LLVMEnvironment.with_llvm_env() do
    # LLVM tools available here
    run(`clang++ --version`)
end
```

## Toolchain Detection

LLVMEnvironment searches for LLVM in:

1. Bundled LLVM (in `LLVM/` directory)
2. System LLVM (`/usr/lib/llvm-*`)
3. Custom path (via environment variable)

## Environment Variables

- `JMAKE_LLVM_PATH`: Override LLVM location
- `LLVM_CONFIG`: Path to llvm-config binary

## Available Tools

The LLVM toolchain provides 137+ tools including:

- **Compilers**: `clang`, `clang++`
- **Linkers**: `lld`, `ld.lld`
- **Utilities**: `llvm-config`, `llvm-ar`, `llvm-nm`
- **Optimization**: `opt`, `llc`
- **Analysis**: `llvm-dis`, `llvm-as`

Full tool list available via:

```julia
JMake.LLVMEnvironment.list_available_tools()
```
