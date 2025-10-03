# CMakeParser

CMake project parsing and conversion to JMake configuration.

## Overview

CMakeParser analyzes CMakeLists.txt files without executing CMake, extracting:

- Project information
- Target definitions
- Source files
- Compiler flags
- Dependencies

## Functions

```@docs
JMake.CMakeParser.parse_cmake_file
JMake.CMakeParser.to_jmake_config
JMake.CMakeParser.write_jmake_config
```

## Data Structures

### CMakeProject

```julia
struct CMakeProject
    project_name::String
    version::String
    targets::Dict{String, CMakeTarget}
    variables::Dict{String, String}
end
```

### CMakeTarget

```julia
struct CMakeTarget
    name::String
    type::Symbol  # :executable, :library, :interface
    sources::Vector{String}
    include_dirs::Vector{String}
    compile_definitions::Vector{String}
    link_libraries::Vector{String}
    compile_options::Vector{String}
end
```

## Usage Examples

### Parse CMake Project

```julia
using JMake.CMakeParser

# Parse CMakeLists.txt
cmake_proj = parse_cmake_file("project/CMakeLists.txt")

# Inspect project
println("Project: $(cmake_proj.project_name) v$(cmake_proj.version)")
println("Targets:")
for (name, target) in cmake_proj.targets
    println("  - $name ($(target.type))")
    println("    Sources: $(length(target.sources))")
end
```

### Convert to JMake Config

```julia
# Convert specific target
jmake_config = to_jmake_config(cmake_proj, "my_library")

# Save configuration
write_jmake_config(cmake_proj, "my_library", "jmake.toml")
```

### Extract Target Information

```julia
# Get specific target
target = cmake_proj.targets["my_library"]

println("Include directories:")
for dir in target.include_dirs
    println("  $dir")
end

println("Compile definitions:")
for def in target.compile_definitions
    println("  $def")
end
```

## Parsing Features

### Supported CMake Commands

CMakeParser recognizes:

- `project()`: Project name and version
- `add_executable()`: Executable targets
- `add_library()`: Library targets
- `target_sources()`: Source files
- `target_include_directories()`: Include paths
- `target_compile_definitions()`: Preprocessor definitions
- `target_link_libraries()`: Dependencies
- `target_compile_options()`: Compiler flags
- `set()`: Variable definitions

### Variable Expansion

Simple variable expansion is supported:

```cmake
set(MY_SOURCES file1.cpp file2.cpp)
add_library(mylib ${MY_SOURCES})  # Expanded to file1.cpp file2.cpp
```

### Generator Expressions

Limited generator expression support:

```cmake
target_compile_definitions(mylib PRIVATE
    $<$<CONFIG:Debug>:DEBUG_MODE>  # Parsed but not evaluated
)
```

## Conversion Details

### Mapping CMake to JMake

| CMake | JMake (jmake.toml) |
|-------|-------------------|
| `project(MyProject VERSION 1.0)` | `[project]`<br>`name = "MyProject"`<br>`version = "1.0.0"` |
| `add_library(mylib file.cpp)` | `[sources]`<br>`files = ["file.cpp"]` |
| `target_include_directories()` | `[sources]`<br>`include_dirs = [...]` |
| `target_compile_definitions()` | `[sources]`<br>`defines = [...]` |
| `target_link_libraries()` | `[dependencies]`<br>`system_libs = [...]` |

### Generated Configuration Example

From this CMakeLists.txt:

```cmake
project(MathLib VERSION 2.1.0)

add_library(mathlib SHARED
    src/math.cpp
    src/utils.cpp
)

target_include_directories(mathlib PUBLIC
    include
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/include
)

target_compile_definitions(mathlib PRIVATE
    MATHLIB_EXPORTS
    VERSION="2.1.0"
)

target_link_libraries(mathlib PRIVATE
    pthread
    m
)

set_target_properties(mathlib PROPERTIES
    CXX_STANDARD 17
)
```

Generates this jmake.toml:

```toml
[project]
name = "mathlib"
version = "2.1.0"

[compiler]
standard = "c++17"

[sources]
files = [
    "src/math.cpp",
    "src/utils.cpp"
]
include_dirs = [
    "include",
    "vendor/include"
]
defines = [
    "MATHLIB_EXPORTS",
    "VERSION=\"2.1.0\""
]

[dependencies]
system_libs = ["pthread", "m"]

[output]
julia_module = "MathLib"
library_name = "libmathlib"
```

## Limitations

### Not Supported

- CMake function/macro execution
- Complex conditional logic
- CMake scripting (control flow)
- External CMake modules
- Dynamic variable evaluation

### Workarounds

For complex projects:

1. Parse to get baseline configuration
2. Manually adjust generated jmake.toml
3. Add missing elements
4. Test and iterate

## Best Practices

1. **Start simple**: Parse single-target projects first
2. **Verify output**: Always review generated jmake.toml
3. **Handle externals**: Manually add external dependencies
4. **Test compilation**: Verify conversion worked correctly
5. **Document changes**: Note manual adjustments in config comments
