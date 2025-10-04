# ConfigurationManager - Single Source of Truth

## Overview

`ConfigurationManager` is the central nervous system of JMake. It maintains a unified TOML-based configuration that serves as the single source of truth for all build stages. Every module reads from and writes to this configuration, enabling the system to evolve its understanding of the project across multiple compilation passes.

**Location**: `/home/grim/.julia/julia/JMake/src/ConfigurationManager.jl`

## Key Concepts

### Metamorphic Design

The configuration is not static. It transforms through the build process:

```julia
# Load initial config
config = load_config("jmake.toml")

# Discovery stage populates file lists
update_discovery_data(config, scan_results)

# Compile stage adds IR file paths
update_compile_data(config, ir_results)

# Each stage builds on previous results
save_config(config)  # Persist evolution
```

### 8-Stage Pipeline

```julia
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
```

## Core Types

### `JMakeConfig`

```julia
mutable struct JMakeConfig
    config_file::String
    last_modified::DateTime
    version::String
    project_name::String
    project_root::String
    discovery::Dict{String,Any}
    reorganize::Dict{String,Any}
    compile::Dict{String,Any}
    link::Dict{String,Any}
    binary::Dict{String,Any}
    symbols::Dict{String,Any}
    wrap::Dict{String,Any}
    test::Dict{String,Any}
    llvm::Dict{String,Any}
    target::Dict{String,Any}
    workflow::Dict{String,Any}
    cache::Dict{String,Any}
    raw_data::Dict{String,Any}
end
```

## API Reference

### `load_config(config_file::String="jmake.toml") -> JMakeConfig`

Load configuration from TOML file. Creates default if missing.

### `save_config(config::JMakeConfig)`

Save configuration back to TOML file with updated timestamp.

### `create_default_config(config_file::String) -> JMakeConfig`

Create new default configuration with all stages defined.

### Stage Data Management

- `update_discovery_data(config, results)` - Update discovery stage
- `update_compile_data(config, results)` - Update compile stage
- `update_link_data(config, results)` - Update link stage
- `update_binary_data(config, results)` - Update binary stage
- `update_symbols_data(config, results)` - Update symbols stage
- `update_wrap_data(config, results)` - Update wrap stage

### Stage Introspection

- `get_stage_config(config, stage::Symbol)` - Get stage configuration
- `is_stage_enabled(config, stage::Symbol)` - Check if stage enabled

### Convenience Accessors

- `get_include_dirs(config)` - Get include directories (discovery > compile)
- `set_include_dirs(config, dirs)` - Set include directories
- `get_source_files(config)` - Get categorized source files
- `set_source_files(config, files)` - Set source files
- `get_dependency_graph(config)` - Get AST dependency graph
- `set_dependency_graph(config, graph)` - Set dependency graph

### Utilities

- `print_config_summary(config)` - Print human-readable summary

## Integration Examples

### Discovery Module
```julia
result = Discovery.discover(path)
update_discovery_data(config, result[:scan_results])
save_config(config)
```

### LLVMake Module
```julia
config = load_config("jmake.toml")
flags = config.compile["flags"]
includes = get_include_dirs(config)
```

## Related Documentation

- [Architecture Overview](architecture/overview.md)
- [Discovery](Discovery.md)
- [LLVMake](LLVMake.md)
