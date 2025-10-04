#!/usr/bin/env julia
# Test script for LLVM_full_jll toolchain integration

using Pkg
Pkg.activate(".")

using JMake
using JMake.LLVMEnvironment

println("="^70)
println("Testing LLVM Toolchain Source Selection")
println("="^70)
println()

# Check if LLVM_full_assert_jll is available
println("🔍 Checking LLVM_full_assert_jll availability...")
if LLVM_JLL_AVAILABLE[]
    println("✅ LLVM_full_assert_jll is available")

    jll_root = get_jll_llvm_root()
    if jll_root !== nothing
        println("   JLL Root: $jll_root")
    end
else
    println("⚠️  LLVM_full_assert_jll is not available (install with: Pkg.add(\"LLVM_full_assert_jll\"))")
end
println()

# Test 1: Auto-discovery (prefers JLL if available)
println("📋 Test 1: Auto-discovery (prefers JLL)")
try
    toolchain_auto = init_toolchain(source=:auto)
    println("   ✅ Auto toolchain initialized")
    println("   Source: $(toolchain_auto.source)")
    println("   Root: $(toolchain_auto.root)")
    println("   Version: $(toolchain_auto.version)")
catch e
    println("   ❌ Failed: $e")
end
println()

# Test 2: Force in-tree
println("📋 Test 2: Force in-tree LLVM")
try
    toolchain_intree = init_toolchain(source=:intree)
    println("   ✅ In-tree toolchain initialized")
    println("   Source: $(toolchain_intree.source)")
    println("   Root: $(toolchain_intree.root)")
    println("   Version: $(toolchain_intree.version)")
catch e
    println("   ❌ Failed: $e")
end
println()

# Test 3: Force JLL (only if available)
if LLVM_JLL_AVAILABLE[]
    println("📋 Test 3: Force LLVM_full_assert_jll")
    try
        toolchain_jll = init_toolchain(source=:jll)
        println("   ✅ JLL toolchain initialized")
        println("   Source: $(toolchain_jll.source)")
        println("   Root: $(toolchain_jll.root)")
        println("   Version: $(toolchain_jll.version)")
    catch e
        println("   ❌ Failed: $e")
    end
    println()
else
    println("📋 Test 3: Skipped (LLVM_full_assert_jll not available)")
    println()
end

# Test 4: Compare available tools
println("📋 Test 4: Tool availability comparison")
println()

function test_toolchain_tools(source_sym)
    try
        tc = init_toolchain(source=source_sym)
        essential_tools = ["clang++", "llvm-config", "llvm-link", "opt", "llc"]

        println("   $(tc.source) toolchain:")
        for tool in essential_tools
            available = haskey(tc.tools, tool) && (isfile(tc.tools[tool]) || islink(tc.tools[tool]))
            status = available ? "✅" : "❌"
            println("      $status $tool")
        end
        println()
    catch e
        println("   ❌ Failed to initialize $(source_sym): $e")
        println()
    end
end

test_toolchain_tools(:intree)
if LLVM_JLL_AVAILABLE[]
    test_toolchain_tools(:jll)
end

println("="^70)
println("✅ Testing complete!")
println("="^70)
