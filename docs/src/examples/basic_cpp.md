# Basic C++ Example

Complete walkthrough of compiling a simple C++ project to Julia bindings.

## Project: Simple Math Library

We'll create a basic math library with common operations.

### Step 1: Initialize Project

```julia
using JMake

# Create project
JMake.init("SimpleMath")
cd("SimpleMath")
```

This creates:
```
SimpleMath/
├── jmake.toml
├── src/
├── include/
├── julia/
├── build/
└── test/
```

### Step 2: Create C++ Code

Create `include/math_ops.h`:

```cpp
#ifndef MATH_OPS_H
#define MATH_OPS_H

#ifdef __cplusplus
extern "C" {
#endif

// Basic arithmetic
double add(double a, double b);
double subtract(double a, double b);
double multiply(double a, double b);
double divide(double a, double b);

// Advanced operations
double power(double base, double exponent);
double square_root(double x);

#ifdef __cplusplus
}
#endif

#endif // MATH_OPS_H
```

Create `src/math_ops.cpp`:

```cpp
#include "math_ops.h"
#include <cmath>

extern "C" {

double add(double a, double b) {
    return a + b;
}

double subtract(double a, double b) {
    return a - b;
}

double multiply(double a, double b) {
    return a * b;
}

double divide(double a, double b) {
    if (b == 0.0) {
        return NAN;  // Return NaN for division by zero
    }
    return a / b;
}

double power(double base, double exponent) {
    return std::pow(base, exponent);
}

double square_root(double x) {
    if (x < 0.0) {
        return NAN;
    }
    return std::sqrt(x);
}

} // extern "C"
```

### Step 3: Configure Project

Edit `jmake.toml`:

```toml
[project]
name = "SimpleMath"
version = "1.0.0"
authors = ["Your Name"]

[compiler]
standard = "c++17"
optimization = "O2"
warnings = ["all", "error"]

[sources]
files = ["src/math_ops.cpp"]
include_dirs = ["include"]

[output]
julia_module = "SimpleMath"
output_dir = "julia"
library_name = "libsimplemath"

[dependencies]
system_libs = ["m"]  # Link with math library
```

### Step 4: Compile

```julia
JMake.compile()
```

Output:
```
🚀 JMake - Compiling project
📁 Scanning sources...
   Found 1 source file
🔨 Compiling src/math_ops.cpp...
✅ Generated: build/math_ops.o
🔗 Linking library...
✅ Generated: julia/libsimplemath.so
📝 Generating Julia bindings...
✅ Generated: julia/SimpleMath.jl
🎉 Compilation complete!
```

### Step 5: Use the Bindings

Create `test/test_math.jl`:

```julia
include("../julia/SimpleMath.jl")
using .SimpleMath

# Test basic operations
println("Testing SimpleMath library...")

# Addition
result = add(5.0, 3.0)
@assert result == 8.0
println("✓ add(5.0, 3.0) = $result")

# Subtraction
result = subtract(10.0, 4.0)
@assert result == 6.0
println("✓ subtract(10.0, 4.0) = $result")

# Multiplication
result = multiply(3.0, 4.0)
@assert result == 12.0
println("✓ multiply(3.0, 4.0) = $result")

# Division
result = divide(15.0, 3.0)
@assert result == 5.0
println("✓ divide(15.0, 3.0) = $result")

# Division by zero
result = divide(10.0, 0.0)
@assert isnan(result)
println("✓ divide(10.0, 0.0) = NaN")

# Power
result = power(2.0, 3.0)
@assert result == 8.0
println("✓ power(2.0, 3.0) = $result")

# Square root
result = square_root(16.0)
@assert result == 4.0
println("✓ square_root(16.0) = $result")

# Negative square root
result = square_root(-1.0)
@assert isnan(result)
println("✓ square_root(-1.0) = NaN")

println("\n✅ All tests passed!")
```

Run tests:

```bash
julia test/test_math.jl
```

Output:
```
Testing SimpleMath library...
✓ add(5.0, 3.0) = 8.0
✓ subtract(10.0, 4.0) = 6.0
✓ multiply(3.0, 4.0) = 12.0
✓ divide(15.0, 3.0) = 5.0
✓ divide(10.0, 0.0) = NaN
✓ power(2.0, 3.0) = 8.0
✓ square_root(16.0) = 4.0
✓ square_root(-1.0) = NaN

✅ All tests passed!
```

### Step 6: Use in Real Code

```julia
using Pkg
Pkg.develop(path="path/to/SimpleMath")

using SimpleMath

# Calculate compound expression
x = add(multiply(3.0, 4.0), power(2.0, 3.0))
# (3 * 4) + (2^3) = 12 + 8 = 20
println("Result: $x")

# Use in algorithms
function quadratic_formula(a, b, c)
    discriminant = subtract(power(b, 2.0), multiply(4.0, multiply(a, c)))
    sqrt_disc = square_root(discriminant)

    x1 = divide(add(-b, sqrt_disc), multiply(2.0, a))
    x2 = divide(subtract(-b, sqrt_disc), multiply(2.0, a))

    return (x1, x2)
end

roots = quadratic_formula(1.0, -5.0, 6.0)
println("Roots: $roots")  # (3.0, 2.0)
```

## Incremental Development

### Adding New Functions

Add to `include/math_ops.h`:

```cpp
double factorial(int n);
```

Add to `src/math_ops.cpp`:

```cpp
double factorial(int n) {
    if (n <= 0) return 1.0;
    double result = 1.0;
    for (int i = 2; i <= n; i++) {
        result *= i;
    }
    return result;
}
```

Recompile:

```julia
JMake.compile()  # Only recompiles changed files
```

Use new function:

```julia
using SimpleMath
println("5! = $(factorial(5))")  # 120.0
```

## Best Practices Demonstrated

1. **extern "C"**: Ensures C linkage for Julia compatibility
2. **Header guards**: Prevents multiple inclusion
3. **Error handling**: Returns NaN for invalid inputs
4. **Include paths**: Separate headers in include/ directory
5. **Testing**: Comprehensive test coverage
6. **Documentation**: Clear function naming and behavior

## Next Steps

- Add more complex data structures (see [CMake Project Example](cmake_project.md))
- Implement callback functions
- Handle array parameters
- Create templates with JMake
