#!/usr/bin/env julia
# runtests.jl - Unit tests for JMake modules
# These are actual tests, not examples. For fun examples, see examples/playground/

using Test
using JMake

println("="^70)
println("JMake Test Suite")
println("="^70)
println()

# Only include actual unit tests, not example/integration tests
test_files = [
    "test_llvm_environment.jl",
    "test_configuration.jl", 
    "test_astwalker.jl",
    "test_discovery.jl",
    "test_cmake_parser.jl",
]

@testset "JMake Unit Tests" begin
    for test_file in test_files
        test_path = joinpath(@__DIR__, test_file)
        if isfile(test_path)
            println("\n▶ Running: $test_file")
            include(test_path)
        else
            @warn "Test file not found: $test_file"
        end
    end
end

println()
println("="^70)
println("Test suite complete!")
println("="^70)
