#!/usr/bin/env julia
# ConfigurationManager.jl - Unified TOML configuration management for JMake
# Single source of truth for all build stages and component data flow
# All modules read/write through this manager to ensure consistency

module ConfigurationManager

using TOML
using Dates

"""
Build stage definitions
Each stage has its own section in the TOML for isolated data
"""
const BUILD_STAGES = [
    :discovery,      # File scanning, dependency walking, AST parsing
    :reorganize,     # File sorting and directory structure creation
    :compile,        # C++ to LLVM IR compilation
    :link,           # IR linking and optimization
    :binary,         # Shared library creation
    :symbols,        # Symbol extraction and analysis
    :wrap,           # Julia wrapper generation
    :test,           # Testing and verification
]

"""
Configuration structure with stage-specific data
"""
mutable struct JMakeConfig
    # Metadata
    config_file::String
    last_modified::DateTime
    version::String

    # Project information
    project_name::String
    project_root::String

    # Stage: Discovery
    discovery::Dict{String,Any}

    # Stage: Reorganize
    reorganize::Dict{String,Any}

    # Stage: Compile
    compile::Dict{String,Any}

    # Stage: Link
    link::Dict{String,Any}

    # Stage: Binary
    binary::Dict{String,Any}

    # Stage: Symbols
    symbols::Dict{String,Any}

    # Stage: Wrap
    wrap::Dict{String,Any}

    # Stage: Test
    test::Dict{String,Any}

    # LLVM toolchain settings
    llvm::Dict{String,Any}

    # Target configuration
    target::Dict{String,Any}

    # Workflow settings
    workflow::Dict{String,Any}

    # Cache settings
    cache::Dict{String,Any}

    # Raw TOML data (for custom sections)
    raw_data::Dict{String,Any}
end

"""
    load_config(config_file::String="jmake.toml") -> JMakeConfig

Load JMake configuration from TOML file.
Creates default if not exists.
"""
function load_config(config_file::String="jmake.toml")
    if !isfile(config_file)
        println("📝 Creating default configuration: $config_file")
        return create_default_config(config_file)
    end

    data = TOML.parsefile(config_file)

    # Extract sections with defaults
    project = get(data, "project", Dict())
    discovery = get(data, "discovery", Dict())
    reorganize = get(data, "reorganize", Dict())
    compile = get(data, "compile", Dict())
    link = get(data, "link", Dict())
    binary = get(data, "binary", Dict())
    symbols = get(data, "symbols", Dict())
    wrap = get(data, "wrap", Dict())
    test_section = get(data, "test", Dict())
    llvm = get(data, "llvm", Dict())
    target = get(data, "target", Dict())
    workflow = get(data, "workflow", Dict())
    cache = get(data, "cache", Dict())

    config = JMakeConfig(
        config_file,
        now(),
        get(data, "version", "0.1.0"),
        get(project, "name", basename(pwd())),
        get(project, "root", pwd()),
        discovery,
        reorganize,
        compile,
        link,
        binary,
        symbols,
        wrap,
        test_section,
        llvm,
        target,
        workflow,
        cache,
        data
    )

    return config
end

"""
    save_config(config::JMakeConfig)

Save configuration back to TOML file.
All component data flows back through this function.
"""
function save_config(config::JMakeConfig)
    # Build TOML structure
    data = Dict{String,Any}()

    # Metadata
    data["version"] = config.version
    data["last_updated"] = string(now())

    # Project
    data["project"] = Dict(
        "name" => config.project_name,
        "root" => config.project_root
    )

    # Stage-specific sections (only save non-empty)
    if !isempty(config.discovery)
        data["discovery"] = config.discovery
    end
    if !isempty(config.reorganize)
        data["reorganize"] = config.reorganize
    end
    if !isempty(config.compile)
        data["compile"] = config.compile
    end
    if !isempty(config.link)
        data["link"] = config.link
    end
    if !isempty(config.binary)
        data["binary"] = config.binary
    end
    if !isempty(config.symbols)
        data["symbols"] = config.symbols
    end
    if !isempty(config.wrap)
        data["wrap"] = config.wrap
    end
    if !isempty(config.test)
        data["test"] = config.test
    end

    # System sections
    if !isempty(config.llvm)
        data["llvm"] = config.llvm
    end
    if !isempty(config.target)
        data["target"] = config.target
    end
    if !isempty(config.workflow)
        data["workflow"] = config.workflow
    end
    if !isempty(config.cache)
        data["cache"] = config.cache
    end

    # Write to file
    open(config.config_file, "w") do io
        TOML.print(io, data)
    end

    config.last_modified = now()
end

"""
    create_default_config(config_file::String) -> JMakeConfig

Create default JMake configuration with all stages defined.
"""
function create_default_config(config_file::String)
    project_name = basename(dirname(abspath(config_file)))
    project_root = pwd()

    config = JMakeConfig(
        config_file,
        now(),
        "0.1.0",
        project_name,
        project_root,
        # Discovery stage
        Dict{String,Any}(
            "enabled" => true,
            "scan_recursive" => true,
            "max_depth" => 10,
            "exclude_dirs" => ["build", ".git", ".cache", "node_modules"],
            "follow_symlinks" => false,
            "parse_ast" => true,
            "walk_dependencies" => true,
            "log_all_files" => true
        ),
        # Reorganize stage
        Dict{String,Any}(
            "enabled" => false,  # Optional stage
            "create_structure" => true,
            "sort_by_type" => true,
            "preserve_hierarchy" => false,
            "target_structure" => Dict(
                "cpp_sources" => "src",
                "cpp_headers" => "include",
                "c_sources" => "src",
                "c_headers" => "include",
                "julia_files" => "julia",
                "config_files" => "config",
                "docs" => "docs"
            )
        ),
        # Compile stage
        Dict{String,Any}(
            "enabled" => true,
            "output_dir" => "build/ir",
            "flags" => ["-std=c++17", "-fPIC"],
            "include_dirs" => String[],  # Populated by discovery
            "defines" => Dict{String,String}(),
            "emit_ir" => true,
            "emit_bc" => false,
            "parallel" => true
        ),
        # Link stage
        Dict{String,Any}(
            "enabled" => true,
            "output_dir" => "build/linked",
            "optimize" => true,
            "opt_level" => "O2",
            "opt_passes" => String[],  # Custom optimization passes
            "lto" => false
        ),
        # Binary stage
        Dict{String,Any}(
            "enabled" => true,
            "output_dir" => "julia",
            "library_name" => "",  # Auto-generated from project name
            "library_type" => "shared",  # shared, static
            "link_libraries" => String[],
            "rpath" => true
        ),
        # Symbols stage
        Dict{String,Any}(
            "enabled" => true,
            "method" => "nm",  # nm, objdump, llvm-nm
            "demangle" => true,
            "filter_internal" => true,
            "export_list" => true
        ),
        # Wrap stage
        Dict{String,Any}(
            "enabled" => true,
            "output_dir" => "julia",
            "style" => "auto",  # auto, basic, advanced, clangjl
            "module_name" => "",  # Auto-generated
            "add_tests" => true,
            "add_docs" => true,
            "type_mappings" => Dict{String,String}()
        ),
        # Test stage
        Dict{String,Any}(
            "enabled" => false,
            "test_dir" => "test",
            "run_tests" => false
        ),
        # LLVM settings
        Dict{String,Any}(
            "use_jmake_llvm" => true,
            "isolated" => true
        ),
        # Target settings
        Dict{String,Any}(
            "triple" => "",
            "cpu" => "generic",
            "features" => String[]
        ),
        # Workflow
        Dict{String,Any}(
            "stages" => ["discovery", "compile", "link", "binary", "symbols", "wrap"],
            "stop_on_error" => true,
            "parallel_stages" => ["compile"]
        ),
        # Cache
        Dict{String,Any}(
            "enabled" => true,
            "directory" => ".jmake_cache",
            "invalidate_on_change" => true
        ),
        # Raw data
        Dict{String,Any}()
    )

    save_config(config)
    println("✅ Created default configuration: $config_file")

    return config
end

"""
    update_discovery_data(config::JMakeConfig, discovery_results::Dict)

Update discovery stage with scan results.
All discovered files, dependencies, and AST data flow here.
"""
function update_discovery_data(config::JMakeConfig, discovery_results::Dict)
    merge!(config.discovery, discovery_results)
    config.last_modified = now()
end

"""
    update_compile_data(config::JMakeConfig, compile_results::Dict)

Update compile stage with IR generation results.
"""
function update_compile_data(config::JMakeConfig, compile_results::Dict)
    merge!(config.compile, compile_results)
    config.last_modified = now()
end

"""
    update_link_data(config::JMakeConfig, link_results::Dict)

Update link stage with optimization and linking results.
"""
function update_link_data(config::JMakeConfig, link_results::Dict)
    merge!(config.link, link_results)
    config.last_modified = now()
end

"""
    update_binary_data(config::JMakeConfig, binary_results::Dict)

Update binary stage with shared library creation results.
"""
function update_binary_data(config::JMakeConfig, binary_results::Dict)
    merge!(config.binary, binary_results)
    config.last_modified = now()
end

"""
    update_symbols_data(config::JMakeConfig, symbol_results::Dict)

Update symbols stage with extracted symbols and metadata.
"""
function update_symbols_data(config::JMakeConfig, symbol_results::Dict)
    merge!(config.symbols, symbol_results)
    config.last_modified = now()
end

"""
    update_wrap_data(config::JMakeConfig, wrap_results::Dict)

Update wrap stage with Julia binding generation results.
"""
function update_wrap_data(config::JMakeConfig, wrap_results::Dict)
    merge!(config.wrap, wrap_results)
    config.last_modified = now()
end

"""
    get_stage_config(config::JMakeConfig, stage::Symbol) -> Dict

Get configuration for a specific build stage.
"""
function get_stage_config(config::JMakeConfig, stage::Symbol)
    if stage == :discovery
        return config.discovery
    elseif stage == :reorganize
        return config.reorganize
    elseif stage == :compile
        return config.compile
    elseif stage == :link
        return config.link
    elseif stage == :binary
        return config.binary
    elseif stage == :symbols
        return config.symbols
    elseif stage == :wrap
        return config.wrap
    elseif stage == :test
        return config.test
    else
        error("Unknown stage: $stage")
    end
end

"""
    is_stage_enabled(config::JMakeConfig, stage::Symbol) -> Bool

Check if a build stage is enabled.
"""
function is_stage_enabled(config::JMakeConfig, stage::Symbol)
    stage_config = get_stage_config(config, stage)
    return get(stage_config, "enabled", false)
end

"""
    get_include_dirs(config::JMakeConfig) -> Vector{String}

Get include directories from discovery/compile stage.
Centralized accessor to fix the include_dirs confusion.
"""
function get_include_dirs(config::JMakeConfig)
    # Priority: discovery results > compile config
    discovery_includes = get(config.discovery, "include_dirs", String[])
    if !isempty(discovery_includes)
        return discovery_includes
    end

    compile_includes = get(config.compile, "include_dirs", String[])
    return compile_includes
end

"""
    set_include_dirs(config::JMakeConfig, include_dirs::Vector{String})

Set include directories (stored in discovery stage).
"""
function set_include_dirs(config::JMakeConfig, include_dirs::Vector{String})
    config.discovery["include_dirs"] = include_dirs
    config.last_modified = now()
end

"""
    get_source_files(config::JMakeConfig) -> Dict{String,Vector{String}}

Get categorized source files from discovery stage.
"""
function get_source_files(config::JMakeConfig)
    return get(config.discovery, "files", Dict{String,Vector{String}}())
end

"""
    set_source_files(config::JMakeConfig, files::Dict{String,Vector{String}})

Set categorized source files in discovery stage.
"""
function set_source_files(config::JMakeConfig, files::Dict{String,Vector{String}})
    config.discovery["files"] = files
    config.last_modified = now()
end

"""
    get_dependency_graph(config::JMakeConfig) -> Dict

Get dependency graph from discovery stage.
"""
function get_dependency_graph(config::JMakeConfig)
    return get(config.discovery, "dependency_graph", Dict())
end

"""
    set_dependency_graph(config::JMakeConfig, graph::Dict)

Set dependency graph in discovery stage.
"""
function set_dependency_graph(config::JMakeConfig, graph::Dict)
    config.discovery["dependency_graph"] = graph
    config.last_modified = now()
end

"""
    print_config_summary(config::JMakeConfig)

Print summary of configuration.
"""
function print_config_summary(config::JMakeConfig)
    println("="^70)
    println("JMake Configuration Summary")
    println("="^70)
    println()
    println("📦 Project: $(config.project_name)")
    println("📁 Root:    $(config.project_root)")
    println("📄 Config:  $(config.config_file)")
    println("🕐 Updated: $(config.last_modified)")
    println()
    println("🔧 Build Stages:")

    for stage in BUILD_STAGES
        enabled = is_stage_enabled(config, stage)
        status = enabled ? "✅" : "⬜"
        println("   $status $(stage)")
    end

    println()
    println("📊 Discovery Results:")
    files = get_source_files(config)
    if !isempty(files)
        for (file_type, file_list) in files
            println("   $(file_type): $(length(file_list)) files")
        end
    else
        println("   No files discovered yet")
    end

    println()
    println("📂 Include Directories:")
    includes = get_include_dirs(config)
    if !isempty(includes)
        for dir in includes
            println("   • $dir")
        end
    else
        println("   None specified")
    end

    println("="^70)
end

# Exports
export JMakeConfig, BUILD_STAGES,
       load_config, save_config, create_default_config,
       update_discovery_data, update_compile_data, update_link_data,
       update_binary_data, update_symbols_data, update_wrap_data,
       get_stage_config, is_stage_enabled,
       get_include_dirs, set_include_dirs,
       get_source_files, set_source_files,
       get_dependency_graph, set_dependency_graph,
       print_config_summary

end # module ConfigurationManager
