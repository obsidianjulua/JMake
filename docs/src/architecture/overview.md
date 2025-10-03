# Architecture Overview

Understanding JMake's internal architecture and design.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                        │
│          (JMake.jl - High-level API functions)          │
└────────────────────┬────────────────────────────────────┘
                     │
      ┌──────────────┼──────────────┐
      │              │              │
┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐
│ Discovery │ │ LLVMake   │ │ JuliaWrap │
│ Pipeline  │ │ Compiler  │ │ Generator │
└─────┬─────┘ └─────┬─────┘ └─────┬─────┘
      │              │              │
      └──────────────┼──────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼──────┐        ┌────────▼────────┐
│  BuildBridge │        │ LLVMEnvironment │
│ ErrorLearning│        │   Toolchain     │
└──────────────┘        └─────────────────┘
```

## Core Components

### 1. User Interface Layer

**JMake.jl**: Main module providing high-level functions

- `init()`: Project initialization
- `compile()`: Compilation orchestration
- `wrap()`: Wrapper generation
- `import_cmake()`: CMake project import

### 2. Discovery Layer

**Discovery**: Automatic project analysis
- File scanning
- Structure analysis
- Configuration generation

**ASTWalker**: C++ AST analysis
- Dependency extraction
- Symbol discovery
- Template analysis

**CMakeParser**: CMake project parsing
- CMakeLists.txt parsing
- Target extraction
- Configuration conversion

### 3. Compilation Layer

**LLVMake**: C++ → Julia compiler
- Source compilation
- LLVM IR generation
- Library linking
- Incremental builds

**JuliaWrapItUp**: Binary → Julia wrapper
- Symbol scanning
- Wrapper generation
- Type mapping
- ABI handling

### 4. Support Layer

**BuildBridge**: Command execution
- Process management
- Output capture
- Error handling

**ErrorLearning**: Error intelligence
- Pattern recognition
- Solution suggestion
- Knowledge base

**LLVMEnvironment**: Toolchain management
- LLVM tool discovery
- Environment isolation
- Version management

**ConfigurationManager**: Configuration handling
- TOML parsing
- Validation
- Merging

## Data Flow

### C++ Compilation Flow

```
Source Files (.cpp)
       ↓
  [Discovery] → Analyze structure
       ↓
  [ASTWalker] → Extract dependencies
       ↓
  [LLVMake] → Compile to LLVM IR
       ↓
  [LLVMake] → Link to shared library
       ↓
  [ClangJLBridge] → Generate Julia bindings
       ↓
  Julia Module (.jl + .so)
```

### Binary Wrapping Flow

```
Binary Library (.so)
       ↓
  [JuliaWrapItUp] → Scan symbols
       ↓
  [JuliaWrapItUp] → Analyze types
       ↓
  [JuliaWrapItUp] → Generate wrappers
       ↓
  Julia Module (.jl)
```

### CMake Import Flow

```
CMakeLists.txt
       ↓
  [CMakeParser] → Parse project
       ↓
  [CMakeParser] → Extract targets
       ↓
  [CMakeParser] → Convert to TOML
       ↓
  jmake.toml
       ↓
  [LLVMake] → Compile
```

## Module Dependencies

```
JMake
├── LLVMEnvironment (standalone)
├── ConfigurationManager
│   └── TOML (stdlib)
├── Discovery
│   ├── ASTWalker
│   └── Clang.jl
├── Templates
├── BuildBridge
│   ├── ErrorLearning
│   │   └── SQLite.jl
│   └── LLVMEnvironment
├── CMakeParser
│   └── ConfigurationManager
├── LLVMake
│   ├── ConfigurationManager
│   ├── BuildBridge
│   └── LLVMEnvironment
├── JuliaWrapItUp
│   ├── ConfigurationManager
│   └── BuildBridge
└── ClangJLBridge
    ├── Clang.jl
    └── CxxWrap.jl
```

## Design Principles

### 1. Modularity

Each component is self-contained and can be used independently:

```julia
# Use LLVMEnvironment standalone
using JMake.LLVMEnvironment
toolchain = get_toolchain()

# Use CMakeParser independently
using JMake.CMakeParser
project = parse_cmake_file("CMakeLists.txt")
```

### 2. Composability

Components work together seamlessly:

```julia
# Discovery + LLVMake
result = JMake.scan(".")
JMake.compile()  # Uses discovered configuration

# CMakeParser + LLVMake
JMake.import_cmake("CMakeLists.txt")
JMake.compile()  # Uses converted configuration
```

### 3. Extensibility

Easy to extend with new functionality:

```julia
# Custom compilation pipeline
using JMake.LLVMake
using JMake.BuildBridge

# Add custom optimization step
function compile_with_custom_opts(config)
    # Use LLVMake internals
    ir = compile_to_ir(config)

    # Custom optimization
    optimized_ir = my_optimizer(ir)

    # Continue with standard pipeline
    link_library(optimized_ir, config)
end
```

### 4. Error Resilience

Comprehensive error handling throughout:

```julia
# BuildBridge provides error learning
try
    compile_source(file)
catch e
    # Error automatically logged
    # Similar errors searched
    # Solutions suggested
end
```

## Daemon Architecture

### Background Processing

Separate daemon system for background builds:

```
┌─────────────────────────────────────┐
│      Orchestrator Daemon            │
│   (Coordinates all daemons)         │
└───────┬─────────────────────────────┘
        │
    ┌───┴────┬─────────┬──────────┐
    │        │         │          │
┌───▼──┐ ┌──▼───┐ ┌──▼────┐ ┌───▼────┐
│Disco │ │Comp  │ │Build  │ │ Error  │
│very  │ │iler  │ │Daemon │ │Handler │
└──────┘ └──────┘ └───────┘ └────────┘
```

See [Daemon Architecture](daemon_architecture.md) for details.

## Performance Considerations

### Caching Strategy

- **AST Cache**: Parsed ASTs cached in `.ast_cache/`
- **Build Cache**: Compiled objects in `.bridge_cache/`
- **Symbol Cache**: Scanned binary symbols cached

### Incremental Builds

- Track source file timestamps
- Detect header changes via AST
- Rebuild only affected files

### Parallel Compilation

- Multiple source files compiled in parallel
- Configurable job count (`-j` flag)
- Dependency-aware scheduling

## Configuration System

### Hierarchy

```
Default Config
     ↓
System Config (/etc/jmake/config.toml)
     ↓
User Config (~/.jmake/config.toml)
     ↓
Project Config (./jmake.toml)
     ↓
Command-line Options
```

Each level overrides the previous.

### Validation

Configurations validated at load time:

1. Schema validation
2. Path existence checks
3. Value range validation
4. Dependency verification

## Extension Points

### Custom Backends

Add new compilation backends:

```julia
# Implement backend interface
struct MyBackend <: CompilationBackend
    # ...
end

# Register backend
register_backend(:my_backend, MyBackend)

# Use in configuration
[compiler]
backend = "my_backend"
```

### Custom Wrappers

Extend wrapper generation:

```julia
# Custom wrapper generator
struct MyWrapperGenerator <: WrapperGenerator
    # ...
end

# Use for specific types
register_wrapper_generator(MyType, MyWrapperGenerator)
```

## Testing Architecture

### Unit Tests

Each module has dedicated tests:

- `test/test_llvm_environment.jl`
- `test/test_configuration.jl`
- `test/test_astwalker.jl`
- etc.

### Integration Tests

Test component interactions:

- `test/test_compilation_pipeline.jl`
- `test/test_cmake_workflow.jl`

### Daemon Tests

Test daemon system:

- `daemons/test_project/test_daemons.jl`
- `daemons/test_project/test_job_queue.jl`

## Future Architecture

Planned enhancements:

1. **Plugin System**: Dynamic loading of extensions
2. **Distributed Builds**: Network-based compilation
3. **Cloud Integration**: Remote LLVM toolchain
4. **Language Bridges**: Support for Rust, Go, etc.
