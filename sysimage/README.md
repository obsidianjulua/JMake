# JMake Build Directory

This directory contains the JMake sysimage and build tools.

## Contents

- **`JMakeSysimage.so`** (362 MB) - Precompiled sysimage with all JMake modules
- **`build_sysimage.jl`** - Script to rebuild the sysimage
- **`precompile_jmake.jl`** - Precompilation workload for sysimage creation

## Performance Comparison

### Without Sysimage
```bash
$ time julia --project=/home/grim/.julia/julia/JMake -e 'using JMake; JMake.info()'
real    0m5.284s    # ~5.3 seconds
```

### With Sysimage
```bash
$ time julia -J /home/grim/.julia/julia/JMake/build/JMakeSysimage.so -e 'using JMake; JMake.info()'
real    0m0.303s    # ~0.3 seconds
```

**Result: ~17x faster startup!** (5.3s → 0.3s)

## Usage

### Quick Start
```bash
# Use the sysimage
julia -J /home/grim/.julia/julia/JMake/build/JMakeSysimage.so

# Then in Julia
using JMake
JMake.help()
```

### Create Alias (Recommended)
Add to `~/.bashrc` or `~/.zshrc`:
```bash
alias jmake='julia -J /home/grim/.julia/julia/JMake/build/JMakeSysimage.so'
```

Then simply:
```bash
jmake -e 'using JMake; JMake.compile()'
```

### One-liner Commands
```bash
# Show info
julia -J build/JMakeSysimage.so -e 'using JMake; JMake.info()'

# Initialize project
julia -J build/JMakeSysimage.so -e 'using JMake; JMake.init("myproject")'

# Compile project
julia -J build/JMakeSysimage.so -e 'using JMake; JMake.compile()'
```

## Rebuilding the Sysimage

When to rebuild:
- After updating JMake source code
- After Julia version updates
- When adding new precompilation targets

```bash
cd /home/grim/.julia/julia/JMake/build
julia --project=.. build_sysimage.jl
```

Build time: ~5-10 minutes on first build

## What's Included

The sysimage includes fully precompiled versions of:

### Modules
- `JMake` - Main module
- `JuliaWrapItUp` - Binary wrapper generator (1500+ lines)
- `LLVMake` - C++ to Julia compiler
- `Bridge_LLVM` - Integration orchestrator
- `ClangJLBridge` - Clang.jl integration
- `BuildBridge` - Command execution with error learning
- `CMakeParser` - CMake file parser
- `Templates` - Project templates
- `ErrorLearning` - Error database

### Dependencies
- `TOML` - Configuration parsing
- `JSON` - Metadata handling
- `Dates` - Timestamps
- `Libdl` - Dynamic library loading

### Optimized Functions
- Identifier sanitization (`make_julia_identifier`)
- Module name generation (`generate_module_name`)
- Binary type detection (`identify_binary_type`)
- Type inference (`infer_julia_type`)
- C++ symbol parsing (`parse_symbol_signature`)
- Parameter parsing (`parse_parameter_list`)
- Configuration management

## Disk Space

- Sysimage: 362 MB
- Regular Julia sysimage: ~200 MB
- Overhead: ~162 MB

The 17x speedup is well worth the disk space for frequent JMake usage.

## Documentation

See `/home/grim/.julia/julia/JMake/docs/SYSIMAGE.md` for complete documentation.
