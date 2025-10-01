# CMake Import Example

This example demonstrates JMake's ability to import existing CMake projects.

## What This Shows

JMake can parse `CMakeLists.txt` and extract:
- Target names and types (library/executable)
- Source files
- Include directories
- Compile flags and options
- Compile definitions
- Link libraries

## Usage

```julia
using JMake

# Import the CMake project
cd("examples/cmake_import")
JMake.import_cmake("CMakeLists.txt", target="mycoollib")

# This generates jmake.toml with all the CMake configuration

# Now compile with JMake (bypassing CMake entirely!)
JMake.compile()
```

## The Magic

**Before**: You'd need to:
1. Run CMake to configure
2. Run Make/Ninja to build
3. Manually write Julia bindings
4. Deal with CMake's complexity

**With JMake**:
1. `JMake.import_cmake()` - Parse CMake config
2. `JMake.compile()` - Build with LLVM
3. Done! Julia bindings ready

**No CMake execution required!**
