# CMake Project Example

Example of importing and building a CMake-based project with JMake.

## Project: Vector Math Library

We'll import a CMake project that implements vector operations.

### Existing CMake Project

Suppose you have this project structure:

```
VectorMath/
├── CMakeLists.txt
├── include/
│   └── vector3d.h
└── src/
    └── vector3d.cpp
```

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.10)
project(VectorMath VERSION 1.0)

set(CMAKE_CXX_STANDARD 17)

add_library(vectormath SHARED
    src/vector3d.cpp
)

target_include_directories(vectormath PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_options(vectormath PRIVATE
    -Wall -Wextra -O3
)
```

`include/vector3d.h`:

```cpp
#ifndef VECTOR3D_H
#define VECTOR3D_H

extern "C" {

struct Vector3D {
    double x, y, z;
};

Vector3D vector_add(Vector3D a, Vector3D b);
Vector3D vector_subtract(Vector3D a, Vector3D b);
Vector3D vector_scale(Vector3D v, double scalar);
double vector_dot(Vector3D a, Vector3D b);
Vector3D vector_cross(Vector3D a, Vector3D b);
double vector_magnitude(Vector3D v);
Vector3D vector_normalize(Vector3D v);

}

#endif
```

`src/vector3d.cpp`:

```cpp
#include "vector3d.h"
#include <cmath>

extern "C" {

Vector3D vector_add(Vector3D a, Vector3D b) {
    return {a.x + b.x, a.y + b.y, a.z + b.z};
}

Vector3D vector_subtract(Vector3D a, Vector3D b) {
    return {a.x - b.x, a.y - b.y, a.z - b.z};
}

Vector3D vector_scale(Vector3D v, double scalar) {
    return {v.x * scalar, v.y * scalar, v.z * scalar};
}

double vector_dot(Vector3D a, Vector3D b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

Vector3D vector_cross(Vector3D a, Vector3D b) {
    return {
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    };
}

double vector_magnitude(Vector3D v) {
    return std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

Vector3D vector_normalize(Vector3D v) {
    double mag = vector_magnitude(v);
    if (mag == 0.0) return {0, 0, 0};
    return vector_scale(v, 1.0 / mag);
}

}
```

### Import with JMake

```julia
using JMake

# Import the CMake project
cmake_proj = JMake.import_cmake("VectorMath/CMakeLists.txt")
```

Output:
```
📦 Importing CMake project: VectorMath/CMakeLists.txt
✅ Found CMake project: VectorMath
   Targets: vectormath
   Using target: vectormath
🎉 CMake import complete!
   Generated: jmake.toml
   Run: JMake.compile("jmake.toml")
```

### Generated jmake.toml

```toml
[project]
name = "vectormath"
version = "1.0"

[compiler]
standard = "c++17"
optimization = "O3"
warnings = ["all", "extra"]

[sources]
files = ["src/vector3d.cpp"]
include_dirs = ["include"]

[output]
julia_module = "VectorMath"
library_name = "libvectormath"

[dependencies]
system_libs = ["m"]
```

### Compile

```julia
JMake.compile()
```

### Use in Julia

Create `test_vectors.jl`:

```julia
include("julia/VectorMath.jl")
using .VectorMath

# Define vectors
v1 = Vector3D(1.0, 2.0, 3.0)
v2 = Vector3D(4.0, 5.0, 6.0)

# Vector addition
v3 = vector_add(v1, v2)
println("v1 + v2 = ($(v3.x), $(v3.y), $(v3.z))")  # (5.0, 7.0, 9.0)

# Dot product
dot = vector_dot(v1, v2)
println("v1 · v2 = $dot")  # 32.0

# Cross product
cross = vector_cross(v1, v2)
println("v1 × v2 = ($(cross.x), $(cross.y), $(cross.z))")  # (-3.0, 6.0, -3.0)

# Magnitude
mag = vector_magnitude(v1)
println("|v1| = $mag")  # 3.7416573867739413

# Normalize
v_norm = vector_normalize(v1)
println("normalize(v1) = ($(v_norm.x), $(v_norm.y), $(v_norm.z))")

# Verify normalized magnitude
@assert abs(vector_magnitude(v_norm) - 1.0) < 1e-10
println("✓ Normalized vector has magnitude 1")
```

### Advanced Usage

Integrate with Julia's LinearAlgebra:

```julia
using LinearAlgebra
using VectorMath

# Convert between Julia arrays and Vector3D
function vec3d_to_array(v::Vector3D)
    return [v.x, v.y, v.z]
end

function array_to_vec3d(arr::Vector{Float64})
    return Vector3D(arr[1], arr[2], arr[3])
end

# Compare implementations
v1_jl = [1.0, 2.0, 3.0]
v2_jl = [4.0, 5.0, 6.0]

# Using Julia's dot product
dot_jl = dot(v1_jl, v2_jl)

# Using our C++ implementation
v1_c = array_to_vec3d(v1_jl)
v2_c = array_to_vec3d(v2_jl)
dot_c = vector_dot(v1_c, v2_c)

@assert dot_jl == dot_c
println("✓ C++ and Julia implementations match")

# Benchmark
using BenchmarkTools

println("\nBenchmarking dot product:")
println("Julia implementation:")
@btime dot($v1_jl, $v2_jl)

println("C++ implementation:")
@btime vector_dot($v1_c, $v2_c)
```

## Modifying Imported Project

If you need to customize the configuration:

```julia
# Import generates baseline jmake.toml
JMake.import_cmake("VectorMath/CMakeLists.txt")

# Edit jmake.toml to add features
# For example, add debug symbols:
```

Edit `jmake.toml`:

```toml
[compiler]
standard = "c++17"
optimization = "O3"
warnings = ["all", "extra"]
extra_flags = ["-g"]  # Add debug symbols

[output]
julia_module = "VectorMath"
generate_ir = true  # Also generate LLVM IR
```

Recompile:

```julia
JMake.compile()
```

## Benefits Over CMake

1. **No CMake required**: Don't need CMake installed
2. **Simpler syntax**: TOML is easier than CMake
3. **Julia-native**: Configuration in Julia-friendly format
4. **Incremental builds**: Automatic dependency tracking
5. **Error learning**: Better error messages over time

## Next Steps

- See [Wrapper Generation Example](wrapper_generation.md) for wrapping pre-built libraries
- See [Error Learning Example](error_learning.md) for handling compilation errors
