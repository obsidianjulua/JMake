# LLVMake

C++ source compilation to Julia bindings using LLVM toolchain.

## Overview

LLVMake is the core compilation engine that:

- Compiles C++ source to LLVM IR
- Generates Julia-compatible shared libraries
- Creates Julia binding modules
- Manages incremental compilation

## Functions

```@docs
JMake.LLVMake.compile_project
JMake.LLVMake.load_config
JMake.LLVMake.create_default_config
JMake.LLVMake.compile_to_ir
JMake.LLVMake.optimize_and_link_ir
JMake.LLVMake.compile_ir_to_shared_lib
JMake.LLVMake.generate_julia_bindings
JMake.LLVMake.parse_cpp_ast
JMake.LLVMake.find_cpp_files
```

## Compilation Pipeline

### 1. Source → Object Files

```
.cpp files → LLVM IR (.bc) → Object files (.o)
```

### 2. Object Files → Shared Library

```
.o files → Linked shared library (.so/.dll/.dylib)
```

### 3. Shared Library → Julia Bindings

```
.so + headers → Julia module wrapper (.jl)
```

## Usage Examples

### Basic Compilation

```julia
using JMake.LLVMake

# Load configuration
config = BridgeCompilerConfig("jmake.toml")

# Compile project
compile_project(config)
```

### Compile Source to IR

```julia
using JMake.LLVMake

# Create compiler instance
compiler = LLVMJuliaCompiler("jmake.toml")

# Compile C++ files to LLVM IR
cpp_files = ["src/myfile.cpp", "src/utils.cpp"]
ir_files = compile_to_ir(compiler, cpp_files)

println("Generated IR files: $ir_files")
```

### Custom Compilation

```julia
# Create compiler config
compiler_config = CompilerConfig(
    standard = "c++20",
    optimization = "O3",
    warnings = ["all", "error"],
    extra_flags = ["-march=native", "-ffast-math"]
)

# Compile with custom config
compile_project(compiler_config)
```

## Configuration

### Compiler Settings

```julia
struct CompilerConfig
    standard::String           # C++ standard
    optimization::String       # Optimization level
    warnings::Vector{String}   # Warning flags
    extra_flags::Vector{String}# Additional flags
    pic::Bool                 # Position Independent Code
    lto::Bool                 # Link-Time Optimization
end
```

### Target Settings

```julia
struct TargetConfig
    triple::String            # Target triple (e.g., "x86_64-linux-gnu")
    cpu::String              # CPU type (e.g., "native", "skylake")
    features::Vector{String} # CPU features
end
```

## Optimization Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| O0 | No optimization | Debugging |
| O1 | Basic optimization | Development |
| O2 | Moderate optimization | Default release |
| O3 | Aggressive optimization | Performance-critical |
| Os | Size optimization | Embedded systems |

## Incremental Compilation

LLVMake tracks source file changes:

```julia
# First compilation - builds all sources
compile_project(config)

# Modify one source file
# ...

# Incremental recompilation - only rebuilds changed files
compile_project(config)
```

### Dependency Tracking

LLVMake automatically tracks:

- Source file modifications (via timestamps)
- Header file changes (via AST analysis)
- Configuration changes
- Compiler flag changes

## Advanced Features

### LLVM IR Generation

Generate intermediate representation:

```julia
# Enable IR output in config
config.output.generate_ir = true

# Compile
compile_project(config)

# IR files generated in build/
# - file.ll (human-readable)
# - file.bc (bitcode)
```

### Assembly Output

Generate assembly code:

```julia
config.output.generate_assembly = true
compile_project(config)

# Assembly files in build/
# - file.s
```

### Link-Time Optimization (LTO)

Enable LTO for better optimization:

```julia
compiler_config = CompilerConfig(
    optimization = "O3",
    lto = true
)
```

### Cross-Compilation

Compile for different target:

```julia
target_config = TargetConfig(
    triple = "aarch64-linux-gnu",
    cpu = "cortex-a72",
    features = ["neon"]
)

compile_project(config, target=target_config)
```

## Error Handling

LLVMake integrates with ErrorLearning:

```julia
# Compilation errors are automatically logged
try
    compile_project(config)
catch e
    # Error details saved to database
    # View error patterns
    stats = get_error_stats()
    println("Similar errors seen: $(stats.similar_count)")
end
```

## Performance Tuning

### Parallel Compilation

```julia
# Enable parallel builds
config.build.parallel = true
config.build.jobs = 8  # Number of parallel jobs
```

### Compilation Cache

```julia
# Enable caching
config.build.cache_enabled = true
config.build.cache_dir = ".bridge_cache"
```

## Best Practices

1. **Use incremental builds**: Let LLVMake track changes automatically
2. **Enable warnings**: Catch issues early with warning flags
3. **Profile optimization**: Test different optimization levels
4. **Cache IR files**: Keep intermediate files for debugging
5. **Parallel builds**: Use `-j` flag for faster compilation
