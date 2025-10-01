# UnifiedLanguageServer.jl Package Structure

## Project.toml
[name]
name = "UnifiedLanguageServer"
uuid = "12345678-1234-1234-1234-123456789abc"
version = "0.1.0"

[deps]
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
TOML = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
Distributed = "8ba89e20-285c-5b6f-9357-94700520ee1b"
Pkg = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[compat]
julia = "1.8"

## src/UnifiedLanguageServer.jl
module UnifiedLanguageServer

include("UnifiedBridge.jl")
include("LSPServer.jl")

using .UnifiedBridge
using .LSPServer

export UnifiedLanguageServer as ULS
export start_server, stop_server

end

## src/UnifiedBridge.jl
# [Your UnifiedBridge module code here]

## src/LSPServer.jl
module LSPServer

using ..UnifiedBridge
using JSON3, TOML

# [Your LSP server code here]

export start_server, stop_server

end

## test/runtests.jl
using Test
using UnifiedLanguageServer

@testset "UnifiedLanguageServer Tests" begin
    @testset "Bridge Functions" begin
        @test UnifiedBridge.command_exists("echo")
        @test !isempty(UnifiedBridge.SYMBOL_TABLE)
    end
    
    @testset "Context Detection" begin
        @test UnifiedBridge.detect_context("ls -la") == :bash
        @test UnifiedBridge.detect_context("using Pkg") == :julia
    end
    
    @testset "Argument Parsing" begin
        args = UnifiedBridge.bash_to_julia_args(["--flag", "value", "pos"])
        @test haskey(args["options"], "flag")
        @test args["positional"][1] == "pos"
    end
end

## debug.jl - Debug script
using Pkg
Pkg.activate(".")

using UnifiedLanguageServer
using UnifiedLanguageServer.UnifiedBridge

# Test symbol table
println("Symbol table size: ", length(SYMBOL_TABLE))

# Test context detection
test_inputs = [
    "ls -la",
    "using Pkg", 
    "grep pattern file",
    "@bashwrap(\"echo test\")"
]

for input in test_inputs
    context = detect_context(input)
    println("'$input' -> $context")
end

# Test execution
result = execute_auto_command("echo", Dict("positional" => ["hello"]))
println("Echo result: $result")

# Test learning
execute_with_learning("test_cmd", ["arg1", "arg2", "arg3"])
predicted = predict_args_count("test_cmd")
println("Predicted args for test_cmd: $predicted")

## Setup commands:
# julia --project=. -e 'using Pkg; Pkg.instantiate()'
# julia --project=. debug.jl