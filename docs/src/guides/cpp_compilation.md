# C++ Compilation Guide

Complete guide to compiling C++ source code to Julia bindings.

## Basic Workflow

### 1. Project Initialization

```julia
using JMake
JMake.init("myproject")
cd("myproject")
```

### 2. Add Source Files

Place your C++ files in `src/`:

```cpp
// src/calculator.cpp
#include <cmath>

extern "C" {
    double square(double x) {
        return x * x;
    }

    double sqrt_val(double x) {
        return std::sqrt(x);
    }
}
```

### 3. Configure Compilation

Edit `jmake.toml`:

```toml
[project]
name = "Calculator"
version = "1.0.0"

[compiler]
standard = "c++17"
optimization = "O3"

[sources]
files = ["src/calculator.cpp"]

[output]
julia_module = "Calculator"
```

### 4. Compile

```julia
JMake.compile()
```

## Advanced Configuration

### Compiler Options

```toml
[compiler]
standard = "c++20"              # C++ standard
optimization = "O3"              # Optimization level
warnings = ["all", "error"]      # Warning flags
extra_flags = ["-fPIC"]         # Additional compiler flags
```

### Source Management

```toml
[sources]
files = [
    "src/core/*.cpp",
    "src/utils/*.cpp"
]
include_dirs = [
    "include",
    "/usr/local/include/mylib"
]
defines = [
    "MY_DEFINE=1",
    "DEBUG"
]
exclude = ["src/experimental/*"]
```

### Dependencies

```toml
[dependencies]
system_libs = ["pthread", "m", "dl"]
pkg_config = ["opencv4"]
link_dirs = ["/usr/local/lib"]
```

### Output Configuration

```toml
[output]
julia_module = "MyModule"
output_dir = "julia"
library_name = "libmymodule"
generate_ir = true              # Generate LLVM IR files
generate_assembly = true        # Generate assembly files
```

## Compilation Features

### Error Learning

JMake automatically learns from compilation errors:

```julia
# View error statistics
JMake.get_error_stats()

# Export error log
JMake.export_errors("error_log.md")
```

### Incremental Builds

Only recompile changed files:

```julia
# Modify a single file
# ...

# Incremental recompilation
JMake.compile()  # Only rebuilds changed sources
```

### Discovery Mode

Auto-detect project structure:

```julia
# Scan and analyze project
result = JMake.scan(".")

# Auto-generate configuration
JMake.scan(".", generate_config=true)
```

## Using Generated Bindings

After compilation, use your bindings:

```julia
include("julia/Calculator.jl")
using .Calculator

result = square(5.0)        # Returns 25.0
root = sqrt_val(16.0)       # Returns 4.0
```

## Troubleshooting

### Missing Symbols

If functions aren't exported, ensure they use `extern "C"`:

```cpp
extern "C" {
    void my_function() { }
}
```

### Header Issues

Add include directories to `jmake.toml`:

```toml
[sources]
include_dirs = [
    "include",
    "/path/to/headers"
]
```

### Linking Errors

Specify required libraries:

```toml
[dependencies]
system_libs = ["pthread", "m"]
```

## Best Practices

1. **Use extern "C"**: Export functions with C linkage for Julia compatibility
2. **Organize headers**: Keep headers in `include/` directory
3. **Version control**: Commit `jmake.toml`, ignore `build/` and `julia/`
4. **Test thoroughly**: Write tests in `test/` directory
5. **Document exports**: Comment exported functions clearly
