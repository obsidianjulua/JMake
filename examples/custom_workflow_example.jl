#!/usr/bin/env julia
# custom_workflow_example.jl - Demonstrates custom JMake workflows

using Pkg
Pkg.activate(dirname(@__DIR__))

using JMake
using JMake.ConfigurationManager
using JMake.Discovery
using JMake.LLVMake

println("="^70)
println("JMake Custom Workflow Examples")
println("="^70)

# =============================================================================
# Example 1: Custom Discovery with Filters
# =============================================================================
println("\n📦 Example 1: Filtered Discovery")
println("-"^70)

function discover_with_filters(project_dir; exclude_tests=true, c_only=false)
    println("Running custom discovery on: $project_dir")

    # Run standard discovery
    config = Discovery.discover(project_dir, force=true)

    # Get discovered files
    files = ConfigurationManager.get_source_files(config)

    # Apply custom filters
    if exclude_tests
        println("  Filtering out test files...")
        for (file_type, file_list) in files
            filtered = filter(f -> !contains(f, "test"), file_list)
            files[file_type] = filtered
        end
        ConfigurationManager.set_source_files(config, files)
    end

    if c_only
        println("  Keeping only C sources...")
        files["cpp_sources"] = String[]
        files["cpp_headers"] = String[]
        ConfigurationManager.set_source_files(config, files)
    end

    # Save modified config
    ConfigurationManager.save_config(config)

    println("  ✓ Custom discovery complete")
    return config
end

# =============================================================================
# Example 2: Stage-by-Stage Compilation
# =============================================================================
println("\n🔨 Example 2: Manual Stage Control")
println("-"^70)

function manual_compilation_pipeline(project_dir)
    println("Running manual compilation pipeline...")

    config_path = joinpath(project_dir, "jmake.toml")

    if !isfile(config_path)
        println("  ⚠️  No config found, run discovery first")
        return
    end

    compiler = LLVMJuliaCompiler(config_path)

    # Stage 1: List all C++ files
    cpp_files = LLVMake.find_cpp_files(compiler.config.source_dir)
    println("  Stage 1: Found $(length(cpp_files)) source files")

    # Stage 2: Compile to IR
    println("  Stage 2: Compiling to IR...")
    ir_files = LLVMake.compile_to_ir(compiler, cpp_files)
    println("  Generated $(length(ir_files)) IR files")

    # Stage 3: Link IR
    if !isempty(ir_files)
        println("  Stage 3: Linking IR...")
        linked_ir = LLVMake.optimize_and_link_ir(compiler, ir_files, "manual_build")

        # Stage 4: Create library
        if !isnothing(linked_ir)
            println("  Stage 4: Creating shared library...")
            lib_path = LLVMake.compile_ir_to_shared_lib(compiler, linked_ir, "manual_build")

            if !isnothing(lib_path)
                println("  ✓ Library created: $lib_path")
                return lib_path
            end
        end
    end

    println("  ⚠️  Pipeline incomplete")
    return nothing
end

# =============================================================================
# Example 3: Configuration Manipulation
# =============================================================================
println("\n⚙️  Example 3: Dynamic Configuration")
println("-"^70)

function configure_for_debug(config_path)
    println("Configuring for debug build...")

    config = ConfigurationManager.load_config(config_path)

    # Modify compile stage
    config.compile["flags"] = vcat(
        config.compile["flags"],
        ["-g", "-O0", "-fno-omit-frame-pointer"]
    )

    # Enable symbols
    config.symbols["enabled"] = true
    config.symbols["demangle"] = true

    # Disable optimization
    config.link["optimize"] = false
    config.link["opt_level"] = "O0"

    ConfigurationManager.save_config(config)

    println("  ✓ Configured for debugging")
end

function configure_for_release(config_path)
    println("Configuring for release build...")

    config = ConfigurationManager.load_config(config_path)

    # Modify compile stage
    config.compile["flags"] = vcat(
        filter(f -> f != "-g", config.compile["flags"]),
        ["-O3", "-DNDEBUG"]
    )

    # Enable LTO
    config.link["optimize"] = true
    config.link["opt_level"] = "O3"
    config.link["lto"] = true

    ConfigurationManager.save_config(config)

    println("  ✓ Configured for release")
end

# =============================================================================
# Example 4: Conditional Compilation
# =============================================================================
println("\n🔀 Example 4: Platform-Specific Builds")
println("-"^70)

function configure_for_platform(config_path, platform::Symbol)
    println("Configuring for platform: $platform")

    config = ConfigurationManager.load_config(config_path)

    if platform == :linux
        config.compile["flags"] = vcat(
            config.compile["flags"],
            ["-DPLATFORM_LINUX", "-pthread"]
        )
        config.binary["link_libraries"] = vcat(
            get(config.binary, "link_libraries", String[]),
            ["pthread", "dl"]
        )

    elseif platform == :macos
        config.compile["flags"] = vcat(
            config.compile["flags"],
            ["-DPLATFORM_MACOS"]
        )
        config.binary["link_libraries"] = vcat(
            get(config.binary, "link_libraries", String[]),
            ["System"]
        )

    elseif platform == :windows
        config.compile["flags"] = vcat(
            config.compile["flags"],
            ["-DPLATFORM_WINDOWS"]
        )
    end

    ConfigurationManager.save_config(config)

    println("  ✓ Configured for $platform")
end

# =============================================================================
# Example 5: Incremental Build Check
# =============================================================================
println("\n⚡ Example 5: Incremental Build Detection")
println("-"^70)

function check_needs_rebuild(compiler::LLVMJuliaCompiler, cpp_file::String, ir_file::String)
    if !isfile(ir_file)
        return true, "IR file doesn't exist"
    end

    if !isfile(cpp_file)
        return false, "Source file missing"
    end

    cpp_mtime = mtime(cpp_file)
    ir_mtime = mtime(ir_file)

    if cpp_mtime > ir_mtime
        return true, "Source newer than IR"
    end

    return false, "Up to date"
end

# =============================================================================
# Usage Examples
# =============================================================================
println("\n" * "="^70)
println("Workflow Functions Available:")
println("="^70)
println("""
  1. discover_with_filters(dir; exclude_tests=true, c_only=false)
  2. manual_compilation_pipeline(dir)
  3. configure_for_debug(config_path)
  4. configure_for_release(config_path)
  5. configure_for_platform(config_path, :linux|:macos|:windows)
  6. check_needs_rebuild(compiler, cpp_file, ir_file)

Example Usage:

  # Filtered discovery
  config = discover_with_filters("/path/to/project", exclude_tests=true)

  # Debug build
  configure_for_debug("jmake.toml")
  JMake.compile()

  # Platform-specific
  configure_for_platform("jmake.toml", :linux)

  # Manual pipeline
  lib = manual_compilation_pipeline("/path/to/project")
""")
