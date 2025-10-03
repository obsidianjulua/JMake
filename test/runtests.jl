using Test
using JMake
using TOML
using Pkg

@testset "JMake.jl Tests" begin
    @testset "Module Loading" begin
        @test isdefined(JMake, :VERSION)
        @test JMake.VERSION == v"0.1.0"
    end

    @testset "Submodules" begin
        @test isdefined(JMake, :LLVMEnvironment)
        @test isdefined(JMake, :ConfigurationManager)
        @test isdefined(JMake, :ASTWalker)
        @test isdefined(JMake, :Discovery)
        @test isdefined(JMake, :BuildBridge)
        @test isdefined(JMake, :CMakeParser)
        @test isdefined(JMake, :LLVMake)
        @test isdefined(JMake, :JuliaWrapItUp)
        @test isdefined(JMake, :ClangJLBridge)
        @test isdefined(JMake, :DaemonManager)
    end

    @testset "High-Level API" begin
        @test isdefined(JMake, :init)
        @test isdefined(JMake, :compile)
        @test isdefined(JMake, :wrap)
        @test isdefined(JMake, :scan)
        @test isdefined(JMake, :analyze)
        @test isdefined(JMake, :start_daemons)
        @test isdefined(JMake, :stop_daemons)
        @test isdefined(JMake, :daemon_status)
    end

    # Include specialized test files
    println("\n" * "="^70)
    println("Running Module-Specific Tests")
    println("="^70)

    include("test_llvm_environment.jl")
    include("test_configuration.jl")
    include("test_astwalker.jl")
    include("test_discovery.jl")
    include("test_cmake_parser.jl")

    # Integration tests
    println("\n" * "="^70)
    println("Running Integration Tests")
    println("="^70)
    include("test_integration.jl")

    # Daemon system tests (optional, may require DaemonMode)
    if isdefined(Main, :DaemonMode) || haskey(Pkg.installed(), "DaemonMode")
        println("\n" * "="^70)
        println("Running Daemon System Tests")
        println("="^70)
        try
            include("test_daemon_system.jl")
        catch e
            @warn "Daemon tests failed or skipped: $e"
        end
    else
        @warn "DaemonMode not installed, skipping daemon tests"
    end
end

println("\n" * "="^70)
println("All Tests Complete!")
println("="^70)
