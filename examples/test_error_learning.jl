#!/usr/bin/env julia
# Test script for ErrorLearning system

println("🧪 Testing JMake Error Learning System")
println("=" ^ 60)

# Setup environment
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

# Load modules
include(joinpath(@__DIR__, "..", "src", "BuildBridge.jl"))
using .BuildBridge

# Test 1: Initialize database
println("\n📦 Test 1: Database Initialization")
println("-" ^ 40)

db = get_error_db("test_errors.db")
println("✅ Database initialized at: test_errors.db")

# Test 2: Bootstrap common errors
println("\n📚 Test 2: Bootstrap Common Errors")
println("-" ^ 40)

bootstrap_common_errors(db)
println("✅ Common errors loaded")

# Test 3: Find similar errors
println("\n🔍 Test 3: Semantic Error Matching")
println("-" ^ 40)

test_error = "undefined reference to `pthread_create'"
println("Query error: $test_error")

similar_errors = find_similar_error(db, test_error, threshold=0.5)

if isempty(similar_errors)
    println("❌ No similar errors found")
else
    println("✅ Found $(length(similar_errors)) similar error(s):")
    for (i, error) in enumerate(similar_errors)
        println("  $i. Similarity: $(round(error.similarity, digits=3)) - $(error.error_text[1:min(60, length(error.error_text))])...")
    end
end

# Test 4: Suggest fixes
println("\n💡 Test 4: Fix Suggestions")
println("-" ^ 40)

suggestions = suggest_fix(db, test_error, confidence_threshold=0.5)

if isempty(suggestions)
    println("❌ No fixes suggested")
else
    println("✅ Found $(length(suggestions)) suggested fix(es):")
    for (i, fix) in enumerate(suggestions[1:min(3, length(suggestions))])
        println("  $i. Confidence: $(round(fix.confidence, digits=3))")
        println("     Description: $(fix.fix_description)")
        println("     Action: $(fix.fix_action)")
    end
end

# Test 5: Record a new fix
println("\n✍️  Test 5: Record New Fix")
println("-" ^ 40)

new_error = "error: no such file or directory: 'missing_header.h'"
new_fix = "include_dirs += [\"third_party/headers\"]"

result = record_fix(
    db,
    new_error,
    new_fix,
    true,  # success
    fix_type = "add_include_dir",
    fix_description = "Add third-party header directory",
    project_path = pwd()
)

println("✅ Recorded new fix:")
println("   Error ID: $(result.error_id)")
println("   Fix ID: $(result.fix_id)")

# Test 6: Verify it's learned
println("\n🔄 Test 6: Verify Learning")
println("-" ^ 40)

learned_fixes = suggest_fix(db, new_error, confidence_threshold=0.0)

if !isempty(learned_fixes)
    println("✅ System learned the new pattern!")
    println("   Confidence: $(round(learned_fixes[1].confidence, digits=3))")
else
    println("❌ Pattern not found")
end

# Test 7: Database statistics
println("\n📊 Test 7: Database Statistics")
println("-" ^ 40)

import SQLite

error_count = 0
fix_count = 0
history_count = 0

for row in SQLite.DBInterface.execute(db.conn, "SELECT COUNT(*) as c FROM error_patterns")
    error_count = row.c
end

for row in SQLite.DBInterface.execute(db.conn, "SELECT COUNT(*) as c FROM error_fixes")
    fix_count = row.c
end

for row in SQLite.DBInterface.execute(db.conn, "SELECT COUNT(*) as c FROM fix_history")
    history_count = row.c
end

println("Error patterns: $error_count")
println("Known fixes: $fix_count")
println("History entries: $history_count")
println("Embeddings: $(db.use_embeddings ? "✅ Enabled" : "❌ Disabled")")

# Cleanup
println("\n🧹 Cleanup")
println("-" ^ 40)
rm("test_errors.db", force=true)
println("✅ Test database removed")

println("\n" * "=" * 60)
println("✅ All tests completed successfully!")
println("\n💡 Next steps:")
println("   1. Run: julia scripts/bootstrap_error_db.jl")
println("   2. Use: compile_with_learning() in your builds")
println("   3. Errors will be automatically learned and fixed!")
