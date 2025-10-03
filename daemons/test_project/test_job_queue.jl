#!/usr/bin/env julia
"""
Test JobQueue.jl - Complete integration test

Tests:
1. Load job queue from TOML
2. Execute jobs in dependency order
3. Verify results written to ConfigurationManager
4. Check TOML persistence
"""

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using TOML

# Load JobQueue which includes ConfigurationManager
include("../src/JobQueue.jl")
using .JobQueue

println("="^70)
println("JobQueue Integration Test")
println("="^70)

# Test 1: Load incomplete TOML config
println("\n[TEST 1] Loading incomplete TOML config...")
config_path = joinpath(@__DIR__, "test_project", "jmake_incomplete.toml")

if !isfile(config_path)
    println("❌ Config file not found: $config_path")
    exit(1)
end

config = JobQueue.ConfigurationManager.load_config(config_path)
println("✅ Loaded config: $(config.project_name)")
println("   Project root: $(config.project_root)")

# Test 2: Create simplified job queue for testing
println("\n[TEST 2] Creating test job queue...")

# Create a test job queue TOML with only the most basic jobs
test_jobs_toml = joinpath(@__DIR__, "test_jobs.toml")

test_jobs = """
[job_queue]
enabled = true
auto_execute = true
persistence = true

# Job 1: Discover LLVM tools (no dependencies)
[[jobs]]
id = "discover_llvm"
type = "toolchain"
daemon = "discovery"
port = 3001
priority = 10
status = "pending"
depends_on = []
target_section = "llvm.tools"
callback = "get_all_tools"
args = {}

# Job 2: Discover project files (no dependencies)
[[jobs]]
id = "discover_files"
type = "discovery"
daemon = "discovery"
port = 3001
priority = 9
status = "pending"
depends_on = []
target_section = "discovery.files"
callback = "scan_files"

[jobs.args]
path = "$(config.project_root)"

# Job 3: Setup build directory (no dependencies)
[[jobs]]
id = "setup_build"
type = "setup"
daemon = "setup"
port = 3002
priority = 8
status = "pending"
depends_on = []
target_section = "compile.output_dir"
callback = "create_structure"

[jobs.args]
path = "$(config.project_root)"
type = "cpp_project"
"""

open(test_jobs_toml, "w") do io
    write(io, test_jobs)
end

println("✅ Created test job queue: $test_jobs_toml")

# Test 3: Load job queue
println("\n[TEST 3] Loading job queue...")

try
    manager = JobQueue.load_jobs(test_jobs_toml, config)
    println("✅ Loaded $(length(manager.jobs)) jobs")

    for (id, job) in manager.jobs
        println("   • $id: $(job.type) -> $(job.target_section)")
    end

    # Test 4: Execute job queue
    println("\n[TEST 4] Executing job queue...")
    println("   (This will call daemons on ports 3001-3002)")

    JobQueue.execute_job_queue(manager)

    # Test 5: Verify results in ConfigurationManager
    println("\n[TEST 5] Verifying results...")

    # Reload config to see updates
    updated_config = JobQueue.ConfigurationManager.load_config(config_path)

    checks = [
        ("LLVM tools", haskey(updated_config.llvm, "tools") && !isempty(get(updated_config.llvm, "tools", Dict()))),
        ("Discovery files", haskey(updated_config.discovery, "files") && !isempty(get(updated_config.discovery, "files", Dict()))),
        ("Output directory", haskey(updated_config.compile, "output_dir") && !isempty(get(updated_config.compile, "output_dir", "")))
    ]

    all_passed = true
    for (name, result) in checks
        status = result ? "✅" : "❌"
        println("   $status $name")
        all_passed = all_passed && result
    end

    # Test 6: Check job state file
    println("\n[TEST 6] Checking job state persistence...")
    state_file = manager.state_file

    if isfile(state_file)
        println("✅ State file exists: $state_file")
        state = TOML.parsefile(state_file)

        if haskey(state, "jobs")
            completed = count(j -> get(j, "status", "") == "completed", state["jobs"])
            failed = count(j -> get(j, "status", "") == "failed", state["jobs"])

            println("   Jobs completed: $completed")
            println("   Jobs failed: $failed")
        end
    else
        println("❌ State file not found")
        all_passed = false
    end

    # Final summary
    println("\n" * "="^70)
    if all_passed
        println("✅ ALL TESTS PASSED - JobQueue integration working!")
    else
        println("⚠️  SOME TESTS FAILED - Check output above")
    end
    println("="^70)

catch e
    println("❌ Error during test: $e")
    println("\nStacktrace:")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
    exit(1)
end
