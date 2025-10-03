@testset "LLVMEnvironment" begin
    @testset "Toolchain Detection" begin
        # Test that we can get toolchain info
        @test_nowarn JMake.LLVMEnvironment.get_toolchain()
    end
end
