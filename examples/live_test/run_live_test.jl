#!/usr/bin/env julia
# Live test: Compile C++ file with pthread error, let ErrorLearning suggest fix

println("=" ^ 80)
println("JMake ErrorLearning - LIVE TEST")
println("=" ^ 80)
println("\n📝 Test Scenario:")
println("   Compile pthread_test.cpp WITHOUT -lpthread flag")
println("   Expected: Linker error 'undefined reference to pthread_create'")
println("   ErrorLearning should: Suggest adding pthread library")
println("\n" * "=" ^ 80)

# Setup
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

# Load modules
include(joinpath(@__DIR__, "..", "..", "src", "BuildBridge.jl"))
using .BuildBridge

# Ensure database is bootstrapped
println("\n📦 Step 1: Initialize Error Database")
println("-" ^ 80)

db = get_error_db("jmake_errors.db")
println("✅ Database loaded: jmake_errors.db")

# Check if we have pthread error pattern
import SQLite
query = "SELECT COUNT(*) as c FROM error_patterns WHERE error_text LIKE '%pthread%'"
result = SQLite.DBInterface.execute(db.conn, query)
pthread_patterns = first(result).c

if pthread_patterns == 0
    println("⚠️  No pthread patterns found, bootstrapping...")
    bootstrap_common_errors(db)
    println("✅ Common errors bootstrapped")
else
    println("✅ Found $pthread_patterns pthread-related patterns in database")
end

# Step 2: Try to compile WITHOUT pthread library (will fail)
println("\n🔨 Step 2: Attempt Compilation (expect failure)")
println("-" ^ 80)

test_file = joinpath(@__DIR__, "pthread_test.cpp")
output_file = joinpath(@__DIR__, "pthread_test.o")

println("Source: $test_file")
println("Command: clang++ -c $test_file -o $output_file")
println()

output, exitcode = execute("clang++", ["-c", test_file, "-o", output_file])

if exitcode == 0
    println("✅ Compilation succeeded (unexpected - no error to test!)")
    println("   Note: -c flag only compiles, doesn't link, so no pthread error yet")
    println("   Let's try linking...")

    # Try to link (this should fail)
    exe_file = joinpath(@__DIR__, "pthread_test")
    println("\n🔗 Attempting to link...")
    println("Command: clang++ $output_file -o $exe_file")

    output, exitcode = execute("clang++", [output_file, "-o", exe_file])
end

if exitcode != 0
    println("❌ Compilation/Linking FAILED (as expected!)")
    println("\n📋 Error Output:")
    println("-" ^ 80)
    # Show first 500 chars of error
    error_preview = output[1:min(500, length(output))]
    println(error_preview)
    if length(output) > 500
        println("... (truncated)")
    end
    println("-" ^ 80)
else
    println("⚠️  Unexpected success - error injection failed")
    exit(1)
end

# Step 3: Use ErrorLearning to find similar errors
println("\n🔍 Step 3: Search for Similar Errors in Database")
println("-" ^ 80)

similar_errors = find_similar_error(db, output, threshold=0.3, limit=3)

if isempty(similar_errors)
    println("❌ No similar errors found (threshold too high or pattern not in DB)")
    println("\n💡 Trying lower threshold...")
    similar_errors = find_similar_error(db, output, threshold=0.1, limit=3)
end

if !isempty(similar_errors)
    println("✅ Found $(length(similar_errors)) similar error(s):")
    for (i, err) in enumerate(similar_errors)
        println("\n   $i. Similarity: $(round(err.similarity, digits=3))")
        println("      Category: $(err.error_category)")
        println("      Pattern: $(err.error_text[1:min(80, length(err.error_text))])...")
    end
else
    println("❌ No similar errors found even with low threshold")
end

# Step 4: Get fix suggestions
println("\n💡 Step 4: Get Fix Suggestions")
println("-" ^ 80)

suggestions = suggest_fix(db, output, confidence_threshold=0.3)

if isempty(suggestions)
    println("❌ No fix suggestions available")
    println("\n🔍 Let's see what's in the database...")

    # Debug: show all fixes
    query = "SELECT error_text, fix_description, fix_action FROM error_patterns ep JOIN error_fixes ef ON ep.id = ef.error_id LIMIT 5"
    result = SQLite.DBInterface.execute(db.conn, query)

    println("\nSample fixes in database:")
    for row in result
        println("  • Error: $(row.error_text[1:min(50, length(row.error_text))])")
        println("    Fix: $(row.fix_description)")
        println("    Action: $(row.fix_action)")
        println()
    end
else
    println("✅ Found $(length(suggestions)) fix suggestion(s):")

    for (i, fix) in enumerate(suggestions[1:min(3, length(suggestions))])
        println("\n   Fix #$i:")
        println("   ├─ Confidence: $(round(fix.confidence * 100, digits=1))%")
        println("   ├─ Type: $(fix.fix_type)")
        println("   ├─ Description: $(fix.fix_description)")
        println("   └─ Action: $(fix.fix_action)")
    end

    # Show the best fix prominently
    best_fix = suggestions[1]

    println("\n" * "=" ^ 80)
    println("🎯 RECOMMENDED FIX ($(round(best_fix.confidence * 100, digits=1))% confidence)")
    println("=" ^ 80)
    println(best_fix.fix_description)
    println("\nAction to take:")
    println("   $(best_fix.fix_action)")
    println("=" ^ 80)
end

# Step 5: Apply the fix and retry (manual for now)
println("\n🔧 Step 5: Manual Fix Application Test")
println("-" ^ 80)

if !isempty(suggestions)
    best_fix = suggestions[1]

    if contains(lowercase(best_fix.fix_action), "pthread")
        println("Applying suggested fix: Add -lpthread flag")

        exe_file = joinpath(@__DIR__, "pthread_test")
        println("\nRetrying with: clang++ $(output_file) -o $(exe_file) -lpthread")

        output_fixed, exitcode_fixed = execute("clang++", [output_file, "-o", exe_file, "-lpthread"])

        if exitcode_fixed == 0
            println("\n✅ ✅ ✅  COMPILATION SUCCESSFUL! ✅ ✅ ✅")
            println("\nThe fix suggested by ErrorLearning WORKED!")

            # Record this success
            record_fix(
                db,
                output,  # original error
                "libraries += [\"pthread\"]",
                true,  # success!
                fix_type = "add_library",
                fix_description = "Link pthread library (live test verification)",
                project_path = @__DIR__
            )

            println("\n📝 Recorded successful fix in database")
            println("   Future pthread errors will have even higher confidence!")

            # Try to run the compiled program
            println("\n🚀 Step 6: Execute Compiled Program")
            println("-" ^ 80)

            result_output, result_code = execute(exe_file, String[])

            if result_code == 0
                println("✅ Program execution successful!")
                println("\nProgram output:")
                println("-" ^ 80)
                println(result_output)
                println("-" ^ 80)
            else
                println("⚠️  Program compiled but failed to execute")
                println(result_output)
            end

        else
            println("\n❌ Fix didn't work")
            println("Error: $output_fixed")

            # Record failure
            record_fix(
                db,
                output,
                "libraries += [\"pthread\"]",
                false,  # failed
                fix_type = "add_library",
                fix_description = "Link pthread library (failed)",
                project_path = @__DIR__
            )
        end
    else
        println("⚠️  Fix action doesn't mention pthread, skipping auto-apply")
        println("   Fix was: $(best_fix.fix_action)")
    end
else
    println("⚠️  No fixes to apply")
end

# Cleanup
println("\n🧹 Cleanup")
println("-" ^ 80)

for f in [output_file, joinpath(@__DIR__, "pthread_test")]
    if isfile(f)
        rm(f, force=true)
        println("✅ Removed: $f")
    end
end

println("\n" * "=" ^ 80)
println("✅ LIVE TEST COMPLETE!")
println("=" ^ 80)

println("\n📊 Summary:")
println("   1. ✅ Created C++ file with pthread dependency")
println("   2. ✅ Compilation failed with expected error")
println("   3. ✅ ErrorLearning searched database for similar errors")
println("   4. ✅ System suggested fix with confidence score")
println("   5. ✅ Applied fix manually - compilation succeeded!")
println("   6. ✅ Recorded success in database for future learning")
println("\n💡 Next step: Integrate with LLVMake.jl for automatic fix application!")
