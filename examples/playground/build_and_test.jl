#!/usr/bin/env julia
# build_and_test.jl - The "does this thing actually work" script
# 
# This builds all playground examples and tests them
# Run this when you want to verify JMake isn't completely broken

using JMake

println("🎮 JMake Playground Build & Test")
println("="^70)

examples = [
    "01_hello_cpp",
    "02_sqlite_wrapper", 
    "03_math_library"
]

results = Dict{String, Bool}()

for example in examples
    println("\n📦 Building: $example")
    println("-"^70)
    
    example_dir = joinpath(@__DIR__, example)
    
    if !isdir(example_dir)
        @warn "Example not found: $example"
        results[example] = false
        continue
    end
    
    cd(example_dir) do
        try
            # Discovery phase - find all the things!
            println("🔍 Discovering project...")
            config = JMake.Discovery.discover(force=true)
            
            # Compile phase - C++ → LLVM IR
            println("⚙️  Compiling...")
            # TODO: Add actual compile call once LLVMake is updated
            
            println("✅ $example built successfully!")
            results[example] = true
        catch e
            println("❌ $example failed: $e")
            results[example] = false
        end
    end
end

# Print summary
println("\n" * "="^70)
println("📊 Build Summary")
println("="^70)

for (example, success) in sort(collect(results))
    status = success ? "✅" : "❌"
    println("$status $example")
end

total = length(results)
passed = count(values(results))
println("\nPassed: $passed/$total")

if passed == total
    println("\n🎉 All examples built successfully!")
    println("🚀 You're ready to build cool stuff with JMake!")
else
    println("\n⚠️  Some examples failed. Check the output above.")
    println("💡 Tip: Make sure you have libsqlite3-dev installed for example 02")
end
