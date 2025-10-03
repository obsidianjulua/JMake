#!/usr/bin/env julia
"""
Test Discovery Daemon functionality
"""

# Test the discovery daemon by writing a test script and running it via daemon
test_code = """
push!(LOAD_PATH, "/home/grim/.julia/julia/JMake/src")
using JMake.Discovery

# Test scan
result = Discovery.scan_all_files("/home/grim/.julia/julia/JMake/daemons/test_project")
println("Scanned files:")
println("  C++ sources: \$(length(result.cpp_sources))")
println("  Total: \$(result.total_files)")

# Return result
result
"""

# Write test file
open("_test_discovery_temp.jl", "w") do f
    write(f, test_code)
end

println("Testing Discovery Daemon via runfile...")
println("="^50)

using DaemonMode
try
    runfile("_test_discovery_temp.jl", port=3001)
    println("\n✅ Discovery test executed")
catch e
    println("❌ Error: $e")
end

# Cleanup
rm("_test_discovery_temp.jl", force=true)
