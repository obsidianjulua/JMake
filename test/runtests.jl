using Test
using JMake

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
    end

    # Include specialized test files
    include("test_llvm_environment.jl")
    include("test_configuration.jl")
    include("test_astwalker.jl")
    include("test_discovery.jl")
    include("test_cmake_parser.jl")
end
