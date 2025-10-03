# Testing and Validation Guide

Complete guide to testing JMake functionality and validating your builds.

## Running JMake Tests

### Complete Test Suite

```julia
# Run all tests
using Pkg
Pkg.test("JMake")
```

### Individual Test Files

```bash
# End-to-end daemon workflow test
julia --project=. test/test_e2e_daemon_workflow.jl

# Simple math example test
julia --project=. test/test_simple_math_example.jl

# Manual library loading test
julia test/test_manual_load.jl

# Integration tests
julia --project=. test/test_integration.jl
```

## Test Coverage

### Phase 1: Daemon System (if DaemonMode available)
- ✅ Daemon lifecycle management
- ✅ Status checking
- ✅ Multi-daemon coordination

### Phase 2: Automated Build Pipeline
- ✅ File discovery (C++, headers)
- ✅ LLVM toolchain detection (52+ tools)
- ✅ AST dependency graph (100+ files)
- ✅ Configuration auto-generation
- ✅ C++ → LLVM IR compilation
- ✅ IR linking and optimization
- ✅ Shared library creation
- ✅ Symbol extraction

### Phase 3: Functional Testing
- ✅ All exported functions callable
- ✅ Correct return values
- ✅ Type safety (Int32, Float64)
- ✅ Standard library functions (sqrt, sin, pow)

### Phase 4: Performance Testing
- ✅ First build benchmarks
- ✅ Incremental rebuild speed (16-200x faster)
- ✅ Cache effectiveness
- ✅ Parallel compilation

### Phase 5: Configuration Validation
- ✅ Complete jmake.toml generation
- ✅ All required sections present
- ✅ LLVM tools discovered
- ✅ Source files tracked

## Validating Your Build

### 1. Check Generated Files

```bash
# After running JMake.compile()
ls -lah build/    # Should contain .ll files (LLVM IR)
ls -lah julia/    # Should contain .so library
```

Expected output:
```
build/
├── myproject.cpp.ll         # LLVM IR for source
├── myproject.linked.ll      # Linked IR
└── myproject.opt.ll         # Optimized IR

julia/
└── libmyproject.so          # Shared library
```

### 2. Verify Symbols

```bash
# Check exported symbols
nm -D julia/libmyproject.so | grep " T "

# Should show your functions:
# 0000000000001130 T add
# 0000000000001140 T multiply
# 0000000000001150 T fast_sqrt
```

### 3. Test Functions

```julia
# Test each function
const LIB = "julia/libmyproject.so"

# Integer functions
@test ccall((:add, LIB), Int32, (Int32, Int32), 5, 3) == 8
@test ccall((:multiply, LIB), Int32, (Int32, Int32), 4, 7) == 28

# Float functions
@test abs(ccall((:fast_sqrt, LIB), Float64, (Float64,), 16.0) - 4.0) < 1e-10
```

### 4. Validate Configuration

```julia
using TOML

config = TOML.parsefile("jmake.toml")

# Check required sections
@assert haskey(config, "project")
@assert haskey(config, "discovery")
@assert haskey(config, "compile")
@assert haskey(config, "link")
@assert haskey(config, "binary")
@assert haskey(config, "wrap")

# Check LLVM tools
@assert haskey(config, "llvm")
@assert haskey(config["llvm"], "tools")
println("✅ Configuration valid")
```

## Performance Benchmarks

### Measuring Build Times

```julia
using JMake

# First build (full discovery + compilation)
@time JMake.compile("path/to/project")
# Expected: 5-10 seconds for small projects

# Incremental build (touch a file)
touch("src/main.cpp")
@time JMake.compile("path/to/project")
# Expected: 0.3-2 seconds (16-50x faster)
```

### Expected Performance

| Project Size | First Build | Incremental | Speedup |
|--------------|-------------|-------------|---------|
| 1-5 files    | 5-8s       | 0.3-0.5s   | 16x     |
| 10-25 files  | 15-30s     | 1-2s       | 20x     |
| 50-100 files | 60-120s    | 2-5s       | 30x     |
| 100+ files   | 180-300s   | 5-10s      | 50x     |

## Common Issues and Solutions

### Issue: No symbols exported

**Symptoms:**
```
⚠️  No symbols to wrap
🔧 Symbols: 0
```

**Solution:**
```cpp
// Make sure functions use extern "C"
extern "C" {
    int my_function(int x) {
        return x * 2;
    }
}
```

Verify with:
```bash
nm -D julia/libmyproject.so | grep " T "
```

### Issue: LLVM tools not found

**Symptoms:**
```
ERROR: LLVM toolchain not found
```

**Solution:**
```julia
# Check LLVM environment
using JMake
toolchain = JMake.LLVMEnvironment.get_toolchain()

# Should show:
# Root: /path/to/LLVM
# Tools: 52 discovered
```

If not found, JMake uses embedded LLVM at `JMake/LLVM/`.

### Issue: Compilation errors

**Symptoms:**
```
ERROR: Compilation failed for src/main.cpp
```

**Debug steps:**
1. Check C++ syntax
2. Verify include paths in jmake.toml
3. Review error log
4. Use error learning system:

```julia
# Export errors for analysis
JMake.export_errors("errors.md")
```

### Issue: Slow incremental builds

**Expected:** 0.3-2s
**If slower:** Cache may not be working

**Solution:**
```bash
# Clean and rebuild
rm -rf build/ julia/ .jmake_cache/
julia -e 'using JMake; JMake.compile()'

# Check cache settings in jmake.toml
[cache]
enabled = true
directory = ".jmake_cache"
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test JMake Build

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Setup Julia
        uses: julia-actions/setup-julia@v1
        with:
          version: '1.9'

      - name: Install JMake
        run: |
          julia --project -e 'using Pkg; Pkg.add(url="https://github.com/yourusername/JMake.jl")'

      - name: Build C++ Project
        run: |
          julia --project -e 'using JMake; JMake.compile(".")'

      - name: Test Library
        run: |
          julia test/test_library.jl
```

## Regression Testing

### Create a Test Suite

```julia
# test/test_myproject.jl
using Test

const LIB = "../julia/libmyproject.so"

@testset "MyProject Library Tests" begin
    @testset "Basic Operations" begin
        @test ccall((:add, LIB), Int32, (Int32, Int32), 2, 3) == 5
        @test ccall((:multiply, LIB), Int32, (Int32, Int32), 4, 5) == 20
    end

    @testset "Math Functions" begin
        @test abs(ccall((:sqrt, LIB), Float64, (Float64,), 9.0) - 3.0) < 1e-10
    end

    @testset "Edge Cases" begin
        @test ccall((:add, LIB), Int32, (Int32, Int32), 0, 0) == 0
        @test ccall((:multiply, LIB), Int32, (Int32, Int32), -1, 5) == -5
    end
end
```

### Run Before Each Commit

```bash
# Rebuild and test
julia -e 'using JMake; JMake.compile(".")'
julia test/test_myproject.jl
```

## Documentation

After validation, document your build:

```julia
# Generate build report
using JMake

println("Build Summary")
println("="^70)
println("Project: ", config["project"]["name"])
println("Sources: ", length(config["discovery"]["files"]["cpp_sources"]))
println("Library: ", "julia/lib$(config["project"]["name"]).so")
println("Symbols: ", length(readlines(`nm -D julia/libmyproject.so`)))
```

## Next Steps

Once validated:
- ✅ Library works correctly
- ✅ All symbols exported
- ✅ Tests pass
- ✅ Performance is good

You're ready to:
1. Integrate with your Julia project
2. Set up CI/CD
3. Create Julia wrappers (optional)
4. Deploy to users
