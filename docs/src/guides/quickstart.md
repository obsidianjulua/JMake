# Quick Start Guide

This guide will get you up and running with JMake in 5 minutes.

## Creating Your First Project

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
├── jmake.toml          # Project configuration
├── src/                # C++ source files
├── include/            # C++ header files
├── julia/              # Generated Julia bindings (output)
├── build/              # Build artifacts
└── test/               # Test files
```

### 2. Add C++ Source Code

Create `src/math_ops.cpp`:

```cpp
extern "C" {
    double add(double a, double b) {
        return a + b;
    }

    double multiply(double a, double b) {
        return a * b;
    }
}
```

### 3. Configure Your Project

Edit `jmake.toml`:

```toml
[project]
name = "MyMath"
version = "0.1.0"

[compiler]
standard = "c++17"
optimization = "O2"

[sources]
files = ["src/math_ops.cpp"]

[output]
julia_module = "MyMath"
```

### 4. Compile to Julia Bindings

```julia
JMake.compile()
```

### 5. Use Your Bindings

```julia
include("julia/MyMath.jl")
using .MyMath

result = add(5.0, 3.0)  # Returns 8.0
println("5 + 3 = $result")
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
