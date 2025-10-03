#!/usr/bin/env julia
# test_vectors.jl - Test the vector math library
# Shows you how to pass arrays to C++

println("🧪 Testing vector math library")

lib_path = joinpath(@__DIR__, "julia", "lib.so")

if !isfile(lib_path)
    error("Library not found! Build it first.")
end

lib = Libc.Libdl.dlopen(lib_path)

# Get function pointers
vector_add = Libc.Libdl.dlsym(lib, :vector_add)
vector_dot = Libc.Libdl.dlsym(lib, :vector_dot)
vector_magnitude = Libc.Libdl.dlsym(lib, :vector_magnitude)

# Test data
a = [1.0, 2.0, 3.0]
b = [4.0, 5.0, 6.0]
result = zeros(Float64, 3)

# Test vector_add
println("➕ Testing vector addition...")
ccall(vector_add, Nothing, (Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Int32),
      a, b, result, length(a))
expected = [5.0, 7.0, 9.0]
@assert result ≈ expected "vector_add failed: expected $expected, got $result"
println("✓ [1,2,3] + [4,5,6] = $result")

# Test dot product
println("⊙ Testing dot product...")
dot = ccall(vector_dot, Float64, (Ptr{Float64}, Ptr{Float64}, Int32),
            a, b, length(a))
expected_dot = 32.0  # 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
@assert dot ≈ expected_dot "vector_dot failed: expected $expected_dot, got $dot"
println("✓ [1,2,3] · [4,5,6] = $dot")

# Test magnitude
println("📏 Testing vector magnitude...")
mag = ccall(vector_magnitude, Float64, (Ptr{Float64}, Int32), a, length(a))
expected_mag = sqrt(1.0 + 4.0 + 9.0)  # sqrt(14) ≈ 3.742
@assert abs(mag - expected_mag) < 1e-10 "vector_magnitude failed: expected $expected_mag, got $mag"
println("✓ ||[1,2,3]|| = $mag")

Libc.Libdl.dlclose(lib)

println("\n🎉 All vector math tests passed!")
println("💡 This example shows multi-file projects with headers")
println("📚 Check out include/ and src/ to see the structure")
