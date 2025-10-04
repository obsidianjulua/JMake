# JMake System Architecture

## Overview

JMake is a metamorphic Julia build system that compiles C++ source code to Julia bindings using an isolated LLVM 20.1.2 toolchain. It features adaptive error learning, daemon-based parallel processing, and a configuration-driven 8-stage pipeline.

## Core Philosophy

**Metamorphic Design**: The `ConfigurationManager` serves as the single source of truth. All modules read from and write to the TOML configuration, allowing the system to evolve its understanding of the project through multiple compilation passes.

**Isolation**: In-tree LLVM 20.1.2 ensures consistent compilation across systems without dependency on system compilers.

**Learning**: SQLite-backed error pattern matching improves build success rates over time.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         JMake.jl (Main Entry)                   │
│                    Version 0.1.0 - Orchestrator                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
│ Configuration    │ │ LLVM         │ │ Discovery        │
│ Manager          │ │ Environment  │ │ Pipeline         │
│                  │ │              │ │                  │
│ Single source    │ │ Isolated     │ │ File scanning    │
│ of truth         │ │ LLVM 20.1.2  │ │ Binary detection │
│ 8-stage pipeline │ │ toolchain    │ │ AST walking      │
└────────┬─────────┘ └──────┬───────┘ └────────┬─────────┘
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
│ LLVMake          │ │ BuildBridge  │ │ ASTWalker        │
│ C++ Compiler     │ │ Execution +  │ │ Dependency       │
│                  │ │ Error Learn  │ │ Analysis         │
│ IR generation    │ │              │ │                  │
│ Optimization     │ │ Tool disco   │ │ Include graphs   │
│ Binding gen      │ │ Learning DB  │ │ Topo sort        │
└────────┬─────────┘ └──────┬───────┘ └──────────────────┘
         │                  │
         └──────────────────┼──────────────────┐
                            │                  │
         ┌──────────────────┼──────────────────┘
         │                  │
         ▼                  ▼
┌──────────────────┐ ┌──────────────────────┐
│ JuliaWrapItUp    │ │ ClangJLBridge        │
│ Binary Wrapper   │ │ Clang.jl Integration │
│                  │ │                      │
│ Symbol extract   │ │ Type-aware bindings  │
│ Type inference   │ │ Advanced wrappers    │
│ Advanced wrap    │ │                      │
└──────────────────┘ └──────────────────────┘
         │                  │
         └──────────────────┼──────────────────┐
                            │                  │
                            ▼                  ▼
                   ┌──────────────────┐ ┌──────────────────┐
                   │ ErrorLearning    │ │ DaemonManager    │
                   │ SQLite DB        │ │ 4 Daemons        │
                   │                  │ │                  │
                   │ Pattern match    │ │ Discovery        │
                   │ Fix suggestions  │ │ Setup            │
                   │ Confidence       │ │ Compilation      │
                   └──────────────────┘ │ Orchestrator     │
                                        └──────────────────┘
```

## Module Relationships

### Core Layer (Foundation)

**ConfigurationManager**: Central nervous system. All state flows through this module.
- 8-stage pipeline: discovery → reorganize → compile → link → binary → symbols → wrap → test
- TOML-based persistence
- Stage-specific data isolation

**LLVMEnvironment**: Toolchain isolation layer.
- Dual-source support: in-tree LLVM or LLVM_full_assert_jll
- Environment variable isolation
- Tool discovery and validation

### Analysis Layer

**Discovery**: Project introspection pipeline.
- File type classification
- Binary detection (ELF magic, executable bits)
- Include directory construction
- Integrates ASTWalker for dependency analysis

**ASTWalker**: C/C++ dependency analysis.
- Clang-based include resolution
- Regex fallback parsing
- Topological sorting for compilation order
- Symbol extraction (functions, classes, namespaces)

**CMakeParser**: Pure Julia CMake parsing.
- No CMake execution required
- Multi-line command handling
- Variable substitution
- Direct conversion to jmake.toml

### Compilation Layer

**LLVMake**: C++ to Julia compiler.
- Clang++ → LLVM IR → shared library pipeline
- AST-based function extraction
- Target configuration (triple, CPU, optimization)
- Component-based compilation (grouping by directory)

**BuildBridge**: Command execution with learning.
- Simplified `execute()` and `capture()` API
- Automatic LLVM environment activation
- Error pattern detection
- Integration with ErrorLearning for fix suggestions

### Wrapper Generation Layer

**JuliaWrapItUp**: Universal binary wrapper.
- Symbol extraction via `nm`/`objdump`
- C++ demangling
- Type inference from headers
- Safety checks and load validation

**ClangJLBridge**: Type-aware wrapper generation.
- Uses Clang.jl's Generators
- Produces idiomatic Julia bindings
- Full type information preservation
- Automatic documentation generation

### Infrastructure Layer

**ErrorLearning**: Adaptive error correction.
- SQLite database (jmake_errors.db)
- Pattern matching (10 common patterns)
- Confidence-based fix ranking
- Obsidian-friendly markdown export

**DaemonManager**: Process lifecycle management.
- 4 daemon types: discovery (3001), setup (3002), compilation (3003), orchestrator (3004)
- Health monitoring and auto-restart
- PID tracking and cleanup
- Optional DaemonMode.jl integration

## Data Flow

### Typical Compilation Flow

1. **User invokes**: `JMake.compile("jmake.toml")`

2. **Configuration Load**: ConfigurationManager reads TOML
   - Loads all 8 stage configurations
   - Reads LLVM toolchain settings
   - Extracts target and workflow settings

3. **LLVM Initialization**: LLVMEnvironment activates
   - Discovers tools in `/home/grim/.julia/julia/JMake/LLVM/tools/`
   - Sets up isolated environment variables
   - Validates toolchain

4. **Discovery** (if enabled):
   - Discovery.discover() scans project
   - ASTWalker builds dependency graph
   - Updates ConfigurationManager with results

5. **Compilation Pipeline**:
   ```
   C++ Sources
       │
       ├─> LLVMake.compile_to_ir()
       │   (via BuildBridge.execute with error learning)
       │
       ├─> LLVMake.optimize_and_link_ir()
       │   (llvm-link + opt)
       │
       ├─> LLVMake.compile_ir_to_shared_lib()
       │   (clang++ -shared)
       │
       ├─> JuliaWrapItUp.generate_wrappers()
       │   OR ClangJLBridge.generate_bindings_clangjl()
       │
       └─> Julia Module (.jl file)
   ```

6. **Error Handling**:
   - BuildBridge captures errors
   - ErrorLearning records pattern
   - Suggests fixes based on history
   - Updates success metrics

7. **Configuration Update**:
   - Each stage writes results back to ConfigurationManager
   - ConfigurationManager.save_config() persists to TOML
   - System evolves for next build

## Key Design Patterns

### 1. Metamorphic Configuration

The TOML configuration file is not static. It evolves:

```julia
# Initial state
config = ConfigurationManager.load_config("jmake.toml")

# Discovery updates it
Discovery.discover(path)
# Now config.discovery["files"] contains all source files

# Compilation updates it
LLVMake.compile_project(config)
# Now config.compile["ir_files"] contains generated IR

# Each stage builds on previous results
```

### 2. Isolated Execution

All LLVM tools run in isolated environment:

```julia
LLVMEnvironment.with_llvm_env() do
    # This clang++ is the JMake in-tree version
    run(`clang++ --version`)
end
```

### 3. Adaptive Learning

Errors become training data:

```julia
# Record error
(id, pattern, desc) = ErrorLearning.record_error(db, cmd, output)

# Get suggestions from past successes
fixes = ErrorLearning.suggest_fixes(db, output)

# Apply fix
success = apply_fix(fixes[1])

# Record result
ErrorLearning.record_fix(db, id, description, action, type, success)
```

### 4. Pipeline as Configuration

Build stages are data, not code:

```toml
[workflow]
stages = ["discovery", "compile", "link", "binary", "symbols", "wrap"]
stop_on_error = true
parallel_stages = ["compile"]
```

## Innovation Points

### 1. Temporal Reasoning via ConfigurationManager

The system maintains history across builds. Each stage's results persist, enabling:
- Incremental rebuilds
- Dependency caching
- Build artifact tracking

### 2. Dual-Source Toolchain

Automatically chooses between:
- In-tree LLVM: `/home/grim/.julia/julia/JMake/LLVM/` (guaranteed version)
- LLVM_full_assert_jll: If available and preferred

### 3. Pure Julia CMake Parser

No CMake execution required. Parses `CMakeLists.txt` directly:
- Multi-line command support
- Comment handling
- Variable expansion
- Outputs native jmake.toml

### 4. Error Learning Database

SQLite schema:
```sql
compilation_errors (id, timestamp, command, error_output, error_pattern, ...)
error_fixes (error_id, fix_description, fix_action, success)
```

Enables:
- Pattern matching across projects
- Confidence scoring (success_count / usage_count)
- Temporal improvement (newer fixes preferred)

### 5. Daemon Architecture

4 cooperating processes:
- **Discovery Daemon** (3001): File scanning, binary detection
- **Setup Daemon** (3002): Toolchain configuration
- **Compilation Daemon** (3003): Parallel C++ compilation (4 workers)
- **Orchestrator Daemon** (3004): Coordinates other daemons

Benefits:
- Parallel processing
- Persistent toolchain state
- RPC-based communication (DaemonMode.jl)

## Limitations and Trade-offs

1. **LLVM Version Lock**: Fixed at 20.1.2 for consistency
2. **Linux-First**: ELF binary detection, Unix tool assumptions
3. **C++17 Default**: Modern C++ assumed, older standards require config
4. **Memory Usage**: Daemon system + SQLite + LLVM tools = ~500MB baseline
5. **Type Inference**: Best-effort for C++, perfect for headers with Clang.jl

## Extension Points

### Custom Build Stages

Add to `ConfigurationManager.BUILD_STAGES`:

```julia
const BUILD_STAGES = [
    :discovery, :reorganize, :compile, :link, :binary,
    :symbols, :wrap, :test,
    :my_custom_stage  # Add here
]
```

### Custom Error Patterns

Extend `ErrorLearning.ERROR_PATTERNS`:

```julia
push!(ERROR_PATTERNS, (
    r"my_error_regex",
    "pattern_name",
    "Description with $1 capture"
))
```

### Custom Wrapper Styles

Implement in `JuliaWrapItUp`:

```julia
elseif wrapper.config.wrapper_style == :my_style
    return my_custom_wrapper_generator(wrapper, binary)
```

## Performance Characteristics

| Operation | Time | Memory | Disk I/O |
|-----------|------|--------|----------|
| Discovery (1000 files) | 2-5s | 100MB | Medium |
| AST Walk (100 files) | 5-10s | 200MB | Low |
| Compile to IR (10 files) | 10-30s | 500MB | High |
| Link + Optimize | 2-5s | 300MB | Medium |
| Symbol Extract | <1s | 50MB | Low |
| Wrapper Gen (Clang.jl) | 5-15s | 400MB | Medium |
| Wrapper Gen (Basic) | <1s | 50MB | Low |

## Security Considerations

1. **LLVM Isolation**: In-tree toolchain prevents injection via system PATH
2. **TOML Validation**: Configuration parsing uses Julia's TOML library (safe)
3. **SQLite Injection**: ErrorLearning uses parameterized queries
4. **File Permissions**: Daemon PID files created with user permissions only

## Comparison with Traditional Build Systems

| Feature | JMake | CMake | Meson | Bazel |
|---------|-------|-------|-------|-------|
| Language | Julia | CMake | Python | Starlark |
| Toolchain | Bundled LLVM | System | System | Hermetic |
| Learning | Yes (SQLite) | No | No | No |
| Config Format | TOML | CMake | Meson | BUILD |
| Julia Bindings | Native | Manual | Manual | Manual |
| Incremental | Via TOML state | Via timestamps | Via DB | Via cache |
| Parallel | Daemon + workers | Yes | Yes | Yes |

## Next Steps

For detailed module documentation, see:
- [ConfigurationManager](../ConfigurationManager.md) - Single source of truth
- [LLVMEnvironment](../LLVMEnvironment.md) - Toolchain isolation
- [LLVMake](../LLVMake.md) - C++ compilation pipeline
- [Discovery](../Discovery.md) - Project analysis
- [ErrorLearning](../ErrorLearning.md) - Adaptive error correction
