# Project Structure

Understanding JMake's project layout and organization.

## Standard C++ Project

```
myproject/
├── jmake.toml              # Main configuration file
├── src/                    # C++ source files
│   ├── main.cpp
│   └── utils.cpp
├── include/                # C++ header files
│   └── myproject/
│       ├── main.h
│       └── utils.h
├── julia/                  # Generated Julia bindings (output)
│   ├── MyProject.jl
│   └── libmyproject.so
├── build/                  # Build artifacts
│   ├── *.o
│   └── *.bc
└── test/                   # Test files
    └── test_myproject.jl
```

## Binary Wrapping Project

```
mybindings/
├── wrapper_config.toml     # Wrapper configuration
├── lib/                    # Binary libraries to wrap
│   └── libexternal.so
├── bin/                    # Binary executables (optional)
├── julia_wrappers/         # Generated wrappers (output)
│   └── ExternalLib.jl
└── test/
    └── test_wrappers.jl
```

## Configuration Files

### jmake.toml

Main configuration for C++ compilation projects:

```toml
[project]
name = "MyProject"
version = "0.1.0"
authors = ["Your Name"]

[compiler]
standard = "c++17"
optimization = "O2"
warnings = ["all", "error"]

[sources]
files = ["src/*.cpp"]
include_dirs = ["include"]
defines = ["MY_DEFINE=1"]

[output]
julia_module = "MyProject"
output_dir = "julia"
library_name = "libmyproject"

[dependencies]
system_libs = ["pthread", "m"]
```

### wrapper_config.toml

Configuration for binary wrapping:

```toml
[wrapper]
name = "MyLibWrapper"
library_path = "/path/to/libmylib.so"
output_dir = "julia_wrappers"

[scanning]
include_symbols = ["public_*"]
exclude_symbols = ["internal_*"]

[generation]
module_name = "MyLib"
```

## Generated Files

### Julia Bindings

JMake generates:

- **Module file**: Main Julia module (`MyProject.jl`)
- **Shared library**: Compiled C++ library (`libmyproject.so`)
- **Metadata**: Compilation metadata (`compilation_metadata.json`)

### Build Artifacts

Intermediate files in `build/`:

- **Object files**: `.o` files
- **LLVM IR**: `.bc`, `.ll` files (if enabled)
- **Assembly**: `.s` files (if enabled)

## JMake Repository Structure

The JMake package itself has this structure:

```
JMake/
├── Project.toml            # Package manifest
├── src/                    # Source modules
│   ├── JMake.jl           # Main module
│   ├── LLVMEnvironment.jl
│   ├── ConfigurationManager.jl
│   ├── Discovery.jl
│   ├── ASTWalker.jl
│   ├── CMakeParser.jl
│   ├── LLVMake.jl
│   ├── JuliaWrapItUp.jl
│   ├── BuildBridge.jl
│   └── ClangJLBridge.jl
├── daemons/                # Daemon system
│   ├── servers/           # Daemon servers
│   ├── clients/           # Client utilities
│   └── handlers/          # Event handlers
├── docs/                   # Documentation
│   ├── make.jl
│   └── src/
├── test/                   # Test suite
│   └── runtests.jl
└── examples/               # Example projects
```
