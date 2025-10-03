# JMake Examples

This directory contains example projects demonstrating JMake's capabilities.

## 🎮 Playground (Start Here!)

**New to JMake?** The `playground/` directory has simple, fun examples perfect for learning:

```bash
cd playground/01_hello_cpp
julia -e 'using JMake; JMake.discover(); JMake.compile()'
julia test_hello.jl
```

- `01_hello_cpp` - Your first build (literally just add two numbers)
- `02_sqlite_wrapper` - External library linking with SQLite
- `03_math_library` - Multi-file project with headers

Each example has:
- Commented C++ code explaining what's happening
- `.jmake_project` marker file
- Test script to verify it works
- Instructions in `playground/README.md`

**The playground is your sandbox.** Break things, modify code, learn by doing!

---

## 📚 Full Examples

### 1. Simple Math (`simple_math/`)

A minimal C++ project demonstrating basic JMake usage.

**Status**: ✅ Fully tested and verified

**What it does:**
- Defines 5 simple C++ math functions
- Compiles them to a Julia-callable library
- Demonstrates the complete JMake workflow

**Functions:**
- `fast_sqrt(x)` - Square root
- `fast_sin(x)` - Sine function
- `fast_pow(base, exp)` - Power function
- `add(a, b)` - Integer addition
- `multiply(a, b)` - Integer multiplication

**Try it:**
```bash
cd examples/simple_math

# Compile with JMake
julia --project=../.. -e 'using JMake; JMake.compile()'

# Test the compiled library
julia --project=../.. -e '
using Libdl
lib = Libdl.dlopen("./julia/libsrc.so")

println("Testing fast_sqrt(16.0):")
result = ccall(Libdl.dlsym(lib, :fast_sqrt), Cdouble, (Cdouble,), 16.0)
println("Result: $result")

Libdl.dlclose(lib)
'
```

**Expected output:**
```
🚀 JMake LLVMake - C++ to Julia Compiler
==================================================
📁 Project: .
📁 Source:  ./src
📁 Output:  ./julia
🔧 Clang:   /usr/bin/clang++
⚡ Target:  host
==================================================

📊 Found 1 C++ files
...
✅ Component complete!
🎉 Compilation complete!
```

## Project Structure

Each example follows this structure:

```
example_name/
├── src/              # C++ source files
│   └── *.cpp
├── include/          # C++ header files (optional)
│   └── *.h
├── jmake.toml        # JMake configuration
├── julia/            # Generated output (created by JMake)
│   ├── lib*.so       # Compiled shared library
│   └── *.jl          # Generated Julia bindings
├── build/            # Build artifacts (created by JMake)
└── test/             # Tests (optional)
```

## Creating Your Own Example

1. **Initialize a new project:**
```julia
using JMake
JMake.init("my_example")
```

2. **Add your C++ code to `src/`:**
```cpp
// src/my_functions.cpp
extern "C" {
    int my_function(int x) {
        return x * 2;
    }
}
```

3. **Configure `jmake.toml` (optional):**
```toml
[project]
name = "MyExample"

[compile]
include_dirs = ["include"]
```

4. **Compile:**
```julia
using JMake
JMake.compile()
```

5. **Use from Julia:**
```julia
using Libdl
lib = Libdl.dlopen("./julia/libMyExample.so")
result = ccall(Libdl.dlsym(lib, :my_function), Cint, (Cint,), 5)
println(result)  # 10
```

## Tips

### Minimal Configuration
The default `jmake.toml` works for most projects. You only need to customize:
- `include_dirs` - If you have custom headers
- `opt_level` - Optimization level (O0, O1, O2, O3)
- `cpu` - Target CPU ("generic", "native", etc.)

### Exclude Unwanted Functions
If JMake generates too many bindings (from stdlib, etc.):

```toml
[bindings]
exclude_patterns = [
    "^std::",        # Standard library
    "^operator",     # C++ operators
    "^_.*",          # Private symbols
    ".*_impl$"       # Implementation details
]
```

### Debug Mode
For debugging compilation issues:

```toml
[target]
debug = true
opt_level = "O0"
```

### Type Mappings
Customize C++ to Julia type conversions:

```toml
[bindings.type_mappings]
"std::string" = "String"
"std::vector<double>" = "Vector{Float64}"
"MyCustomType*" = "Ptr{MyCustomType}"
```

### 2. CMake Import (`cmake_import/`)

Demonstrates importing existing CMake projects without running CMake.

**Status**: ✅ Implemented

**What it does:**
- Parses CMakeLists.txt directly (no CMake execution)
- Extracts sources, includes, flags, and dependencies
- Generates jmake.toml configuration
- Shows how to import specific targets

**Try it:**
```bash
cd examples/cmake_import

# Import CMake project
julia --project=../.. -e 'using JMake; JMake.import_cmake("CMakeLists.txt")'

# Generates jmake.toml ready for JMake.compile()
```

## Coming Soon

- **Advanced Example** - Templates, classes, namespaces
- **OpenCV Wrapper** - Real-world library example
- **Binary Wrapping** - Wrapping existing `.so` files
- **Cross-Compilation** - Targeting different architectures

## Need Help?

- Check the main [README.md](../README.md)
- Read the [API Reference](../README.md#api-reference)
- Open an issue on GitHub

---

**Happy compiling!** 🚀
