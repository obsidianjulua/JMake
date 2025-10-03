# JMake Sysimage Build Guide

## Overview

JMake can be compiled into a custom Julia sysimage for dramatically faster startup times and reduced memory footprint. This is especially useful when using JMake as a command-line tool or in automated build systems.

## Benefits

- **Fast startup**: ~50-100x faster load time (seconds → milliseconds)
- **Reduced memory**: All modules pre-compiled and optimized
- **Instant availability**: All JMake functions ready immediately
- **Better performance**: Type-specialized code paths precompiled

## Building the Sysimage

### Prerequisites

```julia
# Install PackageCompiler.jl
using Pkg
Pkg.add("PackageCompiler")
```

### Build Process

1. **Navigate to JMake directory:**
   ```bash
   cd /home/grim/.julia/julia/JMake
   ```

2. **Run the build script:**
   ```bash
   julia build_sysimage.jl
   ```

3. **Wait for compilation** (typically 5-10 minutes on first build)

4. **Sysimage will be created:** `JMakeSysimage.so`

## Using the Sysimage

### Option 1: Direct usage

```bash
julia -J /home/grim/.julia/julia/JMake/JMakeSysimage.so
```

Then in Julia:
```julia
using JMake
JMake.compile()  # Instant load!
```

### Option 2: Create an alias (recommended)

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
alias jmake='julia -J /home/grim/.julia/julia/JMake/JMakeSysimage.so'
```

Then use:
```bash
jmake -e 'using JMake; JMake.compile()'
```

### Option 3: Create a wrapper script

Create `/usr/local/bin/jmake`:

```bash
#!/bin/bash
julia -J /home/grim/.julia/julia/JMake/JMakeSysimage.so "$@"
```

Make it executable:
```bash
chmod +x /usr/local/bin/jmake
```

## What Gets Precompiled

The sysimage includes precompiled versions of:

### Core Modules
- `JMake` - Main orchestrator
- `JuliaWrapItUp` - Binary wrapper generator
- `LLVMake` - C++ to Julia compiler
- `Bridge_LLVM` - Integration layer
- `ClangJLBridge` - Clang.jl integration
- `BuildBridge` - Command execution
- `CMakeParser` - CMake file parser
- `Templates` - Project templates
- `ErrorLearning` - Error database

### Key Functions
- Configuration creation and loading
- Binary analysis and symbol extraction
- Wrapper generation
- Type inference and mapping
- Symbol parsing and demangling
- Module and identifier generation

### Dependencies
- `TOML` - Configuration file parsing
- `JSON` - Metadata handling
- `Dates` - Timestamp generation
- `Libdl` - Dynamic library loading

## Performance Comparison

### Without Sysimage
```bash
$ time julia -e 'using JMake; JMake.info()'
# ~3-5 seconds startup time
```

### With Sysimage
```bash
$ time julia -J JMakeSysimage.so -e 'using JMake; JMake.info()'
# ~0.1-0.3 seconds startup time
```

**~10-50x faster!**

## Rebuilding the Sysimage

Rebuild when:
- You update JMake source code
- You add new functions you want precompiled
- You update Julia version
- Dependencies are updated

```bash
cd /home/grim/.julia/julia/JMake
julia build_sysimage.jl
```

## Customizing Precompilation

Edit `precompile_jmake.jl` to add more function calls you want precompiled:

```julia
# Add your frequently-used function calls
JMake.compile("my_common_config.toml")
JMake.wrap_binary("/common/path/lib.so")
```

Then rebuild:
```bash
julia build_sysimage.jl
```

## Troubleshooting

### "Cannot find sysimage"
Ensure you're using the full absolute path:
```bash
julia -J /home/grim/.julia/julia/JMake/JMakeSysimage.so
```

### "Sysimage is incompatible"
Rebuild the sysimage after Julia version updates:
```bash
rm JMakeSysimage.so
julia build_sysimage.jl
```

### "Out of memory during build"
PackageCompiler needs significant RAM (4-8GB). Close other applications or use:
```bash
julia --threads=1 build_sysimage.jl
```

## Advanced Usage

### Multiple sysimages for different workflows

Create specialized sysimages:

```julia
# Fast wrapper-only sysimage
create_sysimage(
    [:JuliaWrapItUp, :TOML, :JSON],
    sysimage_path="WrapperSysimage.so"
)

# Compiler-only sysimage
create_sysimage(
    [:LLVMake, :ClangJLBridge, :TOML],
    sysimage_path="CompilerSysimage.so"
)
```

### Integrating with build systems

**Makefile:**
```makefile
.PHONY: jmake-compile
jmake-compile:
	julia -J /path/to/JMakeSysimage.so -e 'using JMake; JMake.compile()'
```

**GitHub Actions:**
```yaml
- name: Build with JMake
  run: |
    julia -J JMakeSysimage.so -e 'using JMake; JMake.compile()'
```

## Size Considerations

Typical sysimage sizes:
- Base Julia sysimage: ~200 MB
- JMake full sysimage: ~300-450 MB
- Size increase: ~50-100 MB

The startup time savings usually far outweigh the disk space cost.

## Tips

1. **Keep sysimage updated**: Rebuild monthly or after major changes
2. **Use absolute paths**: Avoid issues with relative paths
3. **Version control**: Add `*.so` to `.gitignore`
4. **CI/CD**: Consider caching built sysimages
5. **Test after rebuilding**: Ensure all functions work correctly

## Next Steps

- See `CONTRIBUTING.md` for development workflow
- See main `README.md` for JMake usage examples
- Check `Project.toml` for version compatibility
