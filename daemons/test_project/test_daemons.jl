#!/usr/bin/env julia
"""
Simple modular daemon tests
"""

using DaemonMode

println("Testing JMake Daemons")
println("="^70)

# Test 1: Discovery Daemon (port 3001)
println("\n[TEST 1] Discovery Daemon (port 3001)")
try
    result = runexpr("1 + 1", port=3001)
    println("  ✓ Discovery daemon responding: $result")
catch e
    println("  ✗ Discovery daemon not responding: $e")
end

# Test 2: Setup Daemon (port 3002)
println("\n[TEST 2] Setup Daemon (port 3002)")
try
    result = runexpr("2 + 2", port=3002)
    println("  ✓ Setup daemon responding: $result")
catch e
    println("  ✗ Setup daemon not responding: $e")
end

# Test 3: Compilation Daemon (port 3003)
println("\n[TEST 3] Compilation Daemon (port 3003)")
try
    result = runexpr("3 + 3", port=3003)
    println("  ✓ Compilation daemon responding: $result")
catch e
    println("  ✗ Compilation daemon not responding: $e")
end

# Test 4: Orchestrator Daemon (port 3004)
println("\n[TEST 4] Orchestrator Daemon (port 3004)")
try
    result = runexpr("4 + 4", port=3004)
    println("  ✓ Orchestrator daemon responding: $result")
catch e
    println("  ✗ Orchestrator daemon not responding: $e")
end

# Test 5: Discovery - Get tool
println("\n[TEST 5] Discovery - Get cached LLVM tool")
try
    result = runexpr("get_tool(Dict(\"tool\" => \"clang++\"))", port=3001)
    if result isa Dict && haskey(result, :success) && result[:success]
        println("  ✓ Tool found: $(result[:path])")
    else
        println("  ⚠️  Tool not found")
    end
catch e
    println("  ✗ Error: $e")
end

# Test 6: Discovery - Cache stats
println("\n[TEST 6] Discovery - Cache statistics")
try
    result = runexpr("cache_stats(Dict())", port=3001)
    if result isa Dict && haskey(result, :success) && result[:success]
        println("  ✓ Cache stats: $(result[:stats])")
    else
        println("  ⚠️  Failed to get stats")
    end
catch e
    println("  ✗ Error: $e")
end

# Test 7: Setup - Cache stats
println("\n[TEST 7] Setup - Cache statistics")
try
    result = runexpr("cache_stats(Dict())", port=3002)
    if result isa Dict && haskey(result, :success) && result[:success]
        println("  ✓ Cache stats: $(result[:stats])")
    else
        println("  ⚠️  Failed to get stats")
    end
catch e
    println("  ✗ Error: $e")
end

# Test 8: Compilation - Cache stats
println("\n[TEST 8] Compilation - Cache statistics")
try
    result = runexpr("cache_stats(Dict())", port=3003)
    if result isa Dict && haskey(result, :success) && result[:success]
        println("  ✓ Cache stats: $(result[:stats])")
    else
        println("  ⚠️  Failed to get stats")
    end
catch e
    println("  ✗ Error: $e")
end

println("\n" * "="^70)
println("Daemon tests complete!")
