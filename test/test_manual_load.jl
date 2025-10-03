#!/usr/bin/env julia
"""
Manual test of the compiled simple_math library using ccall
"""

# Path to the compiled library
const LIB_PATH = "/home/grim/.julia/julia/JMake/examples/simple_math/julia/libsimple_math.so"

println("="^70)
println("Manual Library Test")
println("="^70)
println("Library: $LIB_PATH")
println()

# Check if library exists
if !isfile(LIB_PATH)
    println("❌ Library not found!")
    exit(1)
end

println("✅ Library found")
println()

# Test the functions using ccall
println("Testing functions:")
println()

# Test add
result_add = ccall((:add, LIB_PATH), Int32, (Int32, Int32), 5, 3)
println("add(5, 3) = $result_add")
@assert result_add == 8 "add failed!"
println("✅ add works correctly")

# Test multiply
result_multiply = ccall((:multiply, LIB_PATH), Int32, (Int32, Int32), 4, 7)
println("multiply(4, 7) = $result_multiply")
@assert result_multiply == 28 "multiply failed!"
println("✅ multiply works correctly")

# Test fast_sqrt
result_sqrt = ccall((:fast_sqrt, LIB_PATH), Float64, (Float64,), 16.0)
println("fast_sqrt(16.0) = $result_sqrt")
@assert abs(result_sqrt - 4.0) < 1e-10 "fast_sqrt failed!"
println("✅ fast_sqrt works correctly")

# Test fast_sin
result_sin = ccall((:fast_sin, LIB_PATH), Float64, (Float64,), 0.0)
println("fast_sin(0.0) = $result_sin")
@assert abs(result_sin) < 1e-10 "fast_sin failed!"
println("✅ fast_sin works correctly")

# Test fast_pow
result_pow = ccall((:fast_pow, LIB_PATH), Float64, (Float64, Float64), 2.0, 3.0)
println("fast_pow(2.0, 3.0) = $result_pow")
@assert abs(result_pow - 8.0) < 1e-10 "fast_pow failed!"
println("✅ fast_pow works correctly")

println()
println("="^70)
println("✅ All function tests passed!")
println("="^70)
println()
println("The library was successfully compiled and all functions work correctly.")
println("However, automatic Julia wrapper generation needs to be fixed.")
