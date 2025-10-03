#!/usr/bin/env julia
# test_hello.jl - Test the hello example
# Shows you how to actually USE the library you just built

println("🧪 Testing hello library")

# Load the shared library
lib_path = joinpath(@__DIR__, "julia", "lib.so")

if !isfile(lib_path)
    error("Library not found! Did you run the build first?\n" *
          "Run: julia -e 'using JMake; cd(\"$(pwd())\"); JMake.discover(); JMake.compile()'")
end

lib = Libc.Libdl.dlopen(lib_path)

# Get function pointers
add = Libc.Libdl.dlsym(lib, :add)
multiply = Libc.Libdl.dlsym(lib, :multiply)
divide = Libc.Libdl.dlsym(lib, :divide)
fibonacci = Libc.Libdl.dlsym(lib, :fibonacci)

# Test add
result = ccall(add, Int32, (Int32, Int32), 5, 3)
@assert result == 8 "add(5, 3) should be 8, got $result"
println("✓ add(5, 3) = $result")

# Test multiply  
result = ccall(multiply, Int32, (Int32, Int32), 6, 7)
@assert result == 42 "multiply(6, 7) should be 42, got $result"
println("✓ multiply(6, 7) = $result  # The answer to everything!")

# Test divide
result = ccall(divide, Float64, (Float64, Float64), 22.0, 7.0)
println("✓ divide(22, 7) = $result  # Almost π!")

# Test fibonacci (warning: slow for n > 40)
result = ccall(fibonacci, Int32, (Int32,), 10)
@assert result == 55 "fibonacci(10) should be 55, got $result"
println("✓ fibonacci(10) = $result")

Libc.Libdl.dlclose(lib)

println("\n🎉 All tests passed!")
println("💡 Try modifying src/hello.cpp and rebuilding!")
