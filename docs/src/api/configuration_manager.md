# ConfigurationManager

TOML-based project configuration management.

## Overview

ConfigurationManager handles loading, validation, and management of JMake project configurations.

## Configuration Types

### CompilerConfig

```julia
struct CompilerConfig
    standard::String           # C++ standard ("c++11", "c++17", "c++20")
    optimization::String       # Optimization level ("O0", "O2", "O3")
    warnings::Vector{String}   # Warning flags
    extra_flags::Vector{String}# Additional compiler flags
end
```

### SourceConfig

```julia
struct SourceConfig
    files::Vector{String}         # Source files/patterns
    include_dirs::Vector{String}  # Include directories
    defines::Vector{String}       # Preprocessor definitions
    exclude::Vector{String}       # Exclusion patterns
end
```

### OutputConfig

```julia
struct OutputConfig
    julia_module::String      # Julia module name
    output_dir::String        # Output directory
    library_name::String      # Shared library name
    generate_ir::Bool         # Generate LLVM IR
    generate_assembly::Bool   # Generate assembly
end
```

## Functions

```@docs
JMake.ConfigurationManager.load_config
JMake.ConfigurationManager.save_config
JMake.ConfigurationManager.create_default_config
JMake.ConfigurationManager.get_stage_config
JMake.ConfigurationManager.is_stage_enabled
JMake.ConfigurationManager.get_include_dirs
JMake.ConfigurationManager.set_include_dirs
JMake.ConfigurationManager.get_source_files
JMake.ConfigurationManager.set_source_files
JMake.ConfigurationManager.print_config_summary
```

## Usage Examples

### Load Configuration

```julia
using JMake.ConfigurationManager

# Load from file
config = load_config("jmake.toml")

# Access settings
println("C++ Standard: $(config.compiler.standard)")
println("Sources: $(config.sources.files)")
```

### Check Stage Status

```julia
# Check if a build stage is enabled
if is_stage_enabled(config, :compile)
    println("Compile stage is enabled")
end

# Get stage-specific configuration
compile_config = get_stage_config(config, :compile)
println("Compile flags: $(get(compile_config, "flags", []))")
```

### Manage Include Directories

```julia
# Get include directories
includes = get_include_dirs(config)
println("Include directories: $includes")

# Set include directories
set_include_dirs(config, ["/usr/include", "./include"])
save_config(config)
```

### Create Default Configuration

```julia
# Create default config
default_config = create_default_config()

# Customize
default_config.compiler.standard = "c++20"
default_config.compiler.optimization = "O3"

# Save
save_config(default_config, "jmake.toml")
```

## Configuration File Format

### Complete Example

```toml
[project]
name = "MyProject"
version = "1.0.0"
authors = ["Your Name <you@example.com>"]
description = "Project description"

[compiler]
standard = "c++17"
optimization = "O2"
warnings = ["all", "error", "pedantic"]
extra_flags = ["-fPIC", "-march=native"]

[sources]
files = [
    "src/**/*.cpp",
    "lib/utils/*.cpp"
]
include_dirs = [
    "include",
    "lib/utils/include",
    "/usr/local/include/mylib"
]
defines = [
    "MY_DEFINE=1",
    "DEBUG",
    "VERSION=\"1.0.0\""
]
exclude = [
    "src/experimental/*",
    "src/deprecated/*"
]

[output]
julia_module = "MyProject"
output_dir = "julia"
library_name = "libmyproject"
generate_ir = false
generate_assembly = false

[dependencies]
system_libs = ["pthread", "m", "dl"]
pkg_config = ["opencv4", "eigen3"]
link_dirs = ["/usr/local/lib"]

[build]
parallel = true
jobs = 4
verbose = false
cache_enabled = true

[llvm]
use_bundled = false
toolchain_path = "/usr/lib/llvm-17"
```

## Environment Variable Expansion

Configurations support environment variable expansion:

```toml
[sources]
include_dirs = [
    "${HOME}/mylib/include",
    "${MYLIB_ROOT}/include"
]
```

## Validation Rules

ConfigurationManager validates:

- Required fields are present
- File paths exist
- C++ standard is valid
- Optimization level is valid
- No conflicting settings

## Best Practices

1. **Version control**: Commit `jmake.toml` to repository
2. **Document custom settings**: Add comments explaining non-obvious config
3. **Use patterns**: Leverage glob patterns for file lists
4. **Separate concerns**: Use multiple configs and merge for complex projects
5. **Validate early**: Run validation before compilation
