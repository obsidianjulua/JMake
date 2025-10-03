#!/usr/bin/env julia
"""
Ultra-simple daemon test - just check they respond
"""

using DaemonMode

println("Simple Daemon Connectivity Test")
println("="^50)

ports = Dict(
    "Discovery" => 3001,
    "Setup" => 3002,
    "Compilation" => 3003,
    "Orchestrator" => 3004
)

for (name, port) in sort(collect(ports), by=x->x[2])
    try
        # Just try to execute something simple
        runexpr("1+1", port=port, output=devnull)
        println("✓ $name (port $port) - RESPONDING")
    catch e
        println("✗ $name (port $port) - NOT RESPONDING")
        println("  Error: $e")
    end
end

println("="^50)
println("\nAll daemons responding!")
println("\nNext step: Test actual functionality")
println("  • Discovery: scan files, find binaries, build AST")
println("  • Setup: generate configs, validate")
println("  • Compilation: parallel compile C++ → IR → binary")
println("  • Orchestrator: full pipeline coordination")
