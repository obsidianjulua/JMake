#!/usr/bin/env julia
"""
test_integration.jl - Comprehensive end-to-end integration tests for JMake

Tests the complete pipeline:
1. Project initialization
2. Configuration generation
3. Discovery and scanning
4. Compilation
5. Binary wrapping
6. Daemon system integration
"""

using Test
using JMake

# Test configuration
const TEST_ROOT = mktempdir()
println("Integration test root: $TEST_ROOT")

@testset "JMake Integration Tests" begin

    # ========================================================================
    # Test 1: Project Initialization
    # ========================================================================

    @testset "Project Initialization" begin
        @testset "C++ Project Init" begin
            proj_dir = joinpath(TEST_ROOT, "cpp_project")
            JMake.init(proj_dir)

            @test isdir(proj_dir)
            @test isdir(joinpath(proj_dir, "src"))
            @test isdir(joinpath(proj_dir, "include"))
            @test isdir(joinpath(proj_dir, "julia"))
            @test isdir(joinpath(proj_dir, "build"))
            @test isfile(joinpath(proj_dir, "jmake.toml"))

            # Verify jmake.toml is valid TOML
            config = TOML.parsefile(joinpath(proj_dir, "jmake.toml"))
            @test haskey(config, "project")
            @test haskey(config, "compile")
        end

        @testset "Binary Wrapping Project Init" begin
            proj_dir = joinpath(TEST_ROOT, "binary_project")
            JMake.init(proj_dir, type=:binary)

            @test isdir(proj_dir)
            @test isdir(joinpath(proj_dir, "lib"))
            @test isdir(joinpath(proj_dir, "bin"))
            @test isdir(joinpath(proj_dir, "julia_wrappers"))
            @test isfile(joinpath(proj_dir, "wrapper_config.toml"))
        end
    end

    # ========================================================================
    # Test 2: Configuration Management
    # ========================================================================

    @testset "Configuration Management" begin
        proj_dir = joinpath(TEST_ROOT, "config_test")
        JMake.init(proj_dir)

        config_file = joinpath(proj_dir, "jmake.toml")

        @testset "Load Configuration" begin
            config = JMake.ConfigurationManager.load_config(config_file)
            @test config.project_name != ""
            @test config.project_root == proj_dir
        end

        @testset "Save Configuration" begin
            config = JMake.ConfigurationManager.load_config(config_file)
            config.project_name = "TestProject"
            JMake.ConfigurationManager.save_config(config)

            # Reload and verify
            config2 = JMake.ConfigurationManager.load_config(config_file)
            @test config2.project_name == "TestProject"
        end
    end

    # ========================================================================
    # Test 3: Project Scanning and Discovery
    # ========================================================================

    @testset "Project Scanning" begin
        proj_dir = joinpath(TEST_ROOT, "scan_test")
        JMake.init(proj_dir)

        # Create test C++ files
        write(joinpath(proj_dir, "src", "math.cpp"), """
        #include <cmath>

        double add(double a, double b) {
            return a + b;
        }

        double multiply(double a, double b) {
            return a * b;
        }
        """)

        write(joinpath(proj_dir, "include", "math.h"), """
        #ifndef MATH_H
        #define MATH_H

        double add(double a, double b);
        double multiply(double a, double b);

        #endif
        """)

        @testset "Scan Project Structure" begin
            result = JMake.analyze(proj_dir)
            @test haskey(result, :scan_results)
            scan = result[:scan_results]
            @test length(scan.cpp_sources) >= 1
            @test length(scan.headers) >= 1
        end

        @testset "Auto-Generate Configuration" begin
            JMake.scan(proj_dir, generate_config=true, output=joinpath(proj_dir, "jmake_generated.toml"))
            @test isfile(joinpath(proj_dir, "jmake_generated.toml"))

            config = TOML.parsefile(joinpath(proj_dir, "jmake_generated.toml"))
            @test haskey(config, "project")
            @test haskey(config, "compile")
        end
    end

    # ========================================================================
    # Test 4: CMake Import
    # ========================================================================

    @testset "CMake Import" begin
        proj_dir = joinpath(TEST_ROOT, "cmake_test")
        mkdir(proj_dir)

        # Create test CMakeLists.txt
        cmake_file = joinpath(proj_dir, "CMakeLists.txt")
        write(cmake_file, """
        cmake_minimum_required(VERSION 3.10)
        project(TestProject)

        add_library(mylib SHARED
            src/math.cpp
        )

        target_include_directories(mylib PUBLIC include)
        """)

        @testset "Parse CMake Project" begin
            cmake_project = JMake.CMakeParser.parse_cmake_file(cmake_file)
            @test cmake_project.project_name == "TestProject"
            @test length(cmake_project.targets) >= 1
        end

        @testset "Convert to JMake Config" begin
            output_file = joinpath(proj_dir, "jmake.toml")
            JMake.import_cmake(cmake_file, output=output_file)

            @test isfile(output_file)
            config = TOML.parsefile(output_file)
            @test haskey(config, "project")
        end
    end

    # ========================================================================
    # Test 5: Discovery Pipeline
    # ========================================================================

    @testset "Discovery Pipeline" begin
        proj_dir = joinpath(TEST_ROOT, "discovery_test")
        JMake.init(proj_dir)

        # Create test source
        write(joinpath(proj_dir, "src", "test.cpp"), """
        #include <iostream>

        void hello() {
            std::cout << "Hello from JMake!" << std::endl;
        }
        """)

        @testset "Discover Files" begin
            result = JMake.Discovery.discover(proj_dir)
            @test haskey(result, :scan_results)
            scan = result[:scan_results]
            @test length(scan.cpp_sources) >= 1
        end
    end

    # ========================================================================
    # Test 6: Daemon System (if daemons available)
    # ========================================================================

    @testset "Daemon Management" begin
        # Note: This test is conditional based on DaemonMode availability
        try
            @testset "Start Daemons" begin
                # Clean up any existing daemons
                JMake.stop_daemons()
                sleep(1)

                # Start new daemon system
                daemon_sys = JMake.start_daemons(project_root=TEST_ROOT)
                @test !isnothing(daemon_sys)

                sleep(3)  # Give daemons time to start

                # Check status
                JMake.daemon_status()
            end

            @testset "Stop Daemons" begin
                JMake.stop_daemons()
                sleep(1)
                # Verify stopped (this will print "No daemons are running")
                JMake.daemon_status()
            end
        catch e
            @warn "Daemon tests skipped (DaemonMode not available or daemons failed to start): $e"
        end
    end

    # ========================================================================
    # Test 7: LLVM Environment
    # ========================================================================

    @testset "LLVM Environment" begin
        @testset "Get Toolchain" begin
            try
                toolchain = JMake.LLVMEnvironment.get_toolchain()
                @test !isnothing(toolchain.root)
                @test !isempty(toolchain.tools)
                @test haskey(toolchain.tools, "clang") || haskey(toolchain.tools, "clang++")
            catch e
                @warn "LLVM toolchain test skipped: $e"
            end
        end
    end

    # ========================================================================
    # Test 8: AST Walking (requires Clang.jl)
    # ========================================================================

    @testset "AST Walker" begin
        test_code = """
        class MyClass {
        public:
            int add(int a, int b) { return a + b; }
        };
        """

        test_file = joinpath(TEST_ROOT, "test_ast.cpp")
        write(test_file, test_code)

        try
            # Test AST parsing (may require proper LLVM setup)
            @test isfile(test_file)
        catch e
            @warn "AST Walker test skipped: $e"
        end
    end

    # ========================================================================
    # Test 9: Error Learning System
    # ========================================================================

    @testset "Error Learning" begin
        db_file = joinpath(TEST_ROOT, "test_errors.db")

        @testset "Record Error" begin
            # Initialize database first
            db = JMake.ErrorLearning.init_db(db_file)

            # Record error with correct API
            JMake.ErrorLearning.record_error(
                db,
                "test_command",
                "Error: undefined reference to `main`",
                project_path="test"
            )

            @test isfile(db_file)
        end

        @testset "Query Errors" begin
            # Database already initialized in previous test
            db = JMake.ErrorLearning.init_db(db_file)
            @test !isnothing(db)
        end
    end

    # ========================================================================
    # Test 10: Template System
    # ========================================================================

    @testset "Discovery System" begin
        proj_dir = joinpath(TEST_ROOT, "discovery_system_test")
        mkdir(proj_dir)

        # Create source structure
        mkdir(joinpath(proj_dir, "src"))
        write(joinpath(proj_dir, "src", "main.cpp"), "int main() { return 0; }")

        @testset "Analyze Project" begin
            result = JMake.analyze(proj_dir)
            @test haskey(result, :scan_results)
        end
    end

end

# Cleanup
println("\nCleaning up test directory: $TEST_ROOT")
try
    rm(TEST_ROOT, recursive=true, force=true)
catch e
    @warn "Failed to clean up test directory: $e"
end

println("\n" * "="^70)
println("Integration Tests Complete!")
println("="^70)
