#!/usr/bin/env julia
# Simple test to verify error learning is working

println("=" ^ 70)
println("Testing Error Learning Integration")
println("=" ^ 70)

using Pkg
Pkg.activate(".")

# Load JMake
include("src/JMake.jl")
using .JMake
using .JMake.BuildBridge
using SQLite, DataFrames

# Create a temporary directory with a broken C++ file
test_dir = mktempdir()
println("\n📁 Test directory: $test_dir")

# Write a C++ file with an intentional error (missing semicolon)
broken_cpp = joinpath(test_dir, "broken.cpp")
write(broken_cpp, """
#include <iostream>

extern "C" {
    int test_function() {
        return 42  // Missing semicolon!
    }
}
""")

println("📝 Created broken.cpp with syntax error")

# Try to compile it with BuildBridge
println("\n🔨 Attempting compilation (should fail)...")

db_path = joinpath(test_dir, "test_errors.db")
db = BuildBridge.get_error_db(db_path)

# Execute clang (will fail)
output, exitcode = BuildBridge.execute("clang++", ["-c", broken_cpp, "-o", "/tmp/test.o"])

println("\n📊 Compilation result:")
println("  Exit code: $exitcode")
println("  Expected: non-zero (error)")

if exitcode != 0
    println("  ✅ Compilation failed as expected")
    
    # Record the error manually to test ErrorLearning
    (error_id, pattern_name, description) = BuildBridge.ErrorLearning.record_error(
        db, "clang++ -c $broken_cpp", output,
        project_path=test_dir, file_path=broken_cpp)
    
    println("\n💾 Error recorded:")
    println("  Error ID: $error_id")
    println("  Pattern: $pattern_name")
    println("  Description: $description")
    
    # Check database
    errors = DataFrame(DBInterface.execute(db, "SELECT * FROM compilation_errors"))
    println("\n📋 Database contents:")
    println("  Total errors: $(size(errors, 1))")
    
    if size(errors, 1) > 0
        println("\n✅ ERROR LEARNING IS WORKING!")
        println("\nRecorded error details:")
        println("  Pattern: ", errors.error_pattern[1])
        println("  Timestamp: ", errors.timestamp[1])
        println("  File: ", errors.file_path[1])
        
        # Test suggestions
        suggestions = BuildBridge.ErrorLearning.suggest_fixes(db, output)
        if !isempty(suggestions)
            println("\n💡 Suggested fixes:")
            for (i, sug) in enumerate(suggestions)
                println("  $i. $(sug["description"]) (confidence: $(sug["confidence"]))")
            end
        end
    else
        println("\n❌ ERROR: Nothing was recorded in database!")
    end
else
    println("  ❌ ERROR: Compilation should have failed!")
end

# Cleanup
rm(test_dir, recursive=true, force=true)

println("\n" * repeat("=", 70))
println("Test Complete")
println(repeat("=", 70))
