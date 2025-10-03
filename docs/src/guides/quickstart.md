# Quick Start Guide

This guide will get you up and running with JMake in 5 minutes.

## Option 1: Automatic Discovery (Recommended)

Point JMake at any C++ project and let it handle everything automatically:

```julia
using JMake

# JMake automatically:
# 1. Discovers all C++ files
# 2. Finds LLVM toolchain
# 3. Generates configuration
# 4. Compiles to shared library
# 5. Extracts symbols
JMake.compile("/path/to/cpp/project")
```

**That's it!** JMake handles:
- File discovery (C++, headers)
- AST dependency analysis
- LLVM toolchain detection
- Configuration generation
- Full compilation pipeline
- Symbol extraction

## Option 2: Manual Project Creation

### 1. Initialize a C++ Project

```julia
using JMake

# Create a new C++ project
JMake.init("mymath")
cd("mymath")
```

This creates the following structure:
```
mymath/
├── jmake.toml          # Project configuration (auto-generated)
├── src/                # C++ source files
├── include/            # C++ header files
├── julia/              # Generated shared library (output)
├── build/              # Build artifacts (IR files)
└── test/               # Test files
```

### 2. Add C++ Source Code

Create `src/math_ops.cpp`:

```cpp
#include <cmath>

extern "C" {
    double add(double a, double b) {
        return a + b;
    }

    double multiply(double a, double b) {
        return a * b;
    }

    double fast_sqrt(double x) {
        return std::sqrt(x);
    }
}
```

### 3. Compile (Auto-Configuration)

```julia
# JMake will automatically:
# - Discover your source files
# - Generate jmake.toml configuration
# - Compile to shared library
JMake.compile()
```

### 4. Use Your Library

```julia
# The compiled library is in julia/
const LIB = "julia/libmymath.so"

# Call functions directly via ccall
result = ccall((:add, LIB), Float64, (Float64, Float64), 5.0, 3.0)
println("5 + 3 = $result")  # 8.0

sqrt_result = ccall((:fast_sqrt, LIB), Float64, (Float64,), 16.0)
println("sqrt(16) = $sqrt_result")  # 4.0
```

## Binary Wrapping Workflow

If you have an existing binary library:

### 1. Initialize Binary Project

```julia
JMake.init("mybindings", type=:binary)
cd("mybindings")
```

### 2. Configure Wrapper

Edit `wrapper_config.toml`:

```toml
[wrapper]
name = "MyLibWrapper"
library_path = "/usr/lib/libmylib.so"
output_dir = "julia_wrappers"
```

### 3. Generate Wrappers

```julia
# Wrap all configured binaries
JMake.wrap()

# Or wrap a specific binary
JMake.wrap_binary("/usr/lib/libmylib.so")
```

## CMake Project Import

Have an existing CMake project? Import it directly:

```julia
# Import CMake project
cmake_project = JMake.import_cmake("path/to/CMakeLists.txt")

# Compile the imported project
JMake.compile()
```

## Next Steps

- Read the [User Guide](../guides/cpp_compilation.md) for detailed workflows
- Explore [API Reference](../api/jmake.md) for all available functions
- Check out [Examples](../examples/basic_cpp.md) for real-world use cases
- Learn about the [Daemon System](../guides/daemon_system.md) for background builds
