# CMake Project Import

Import existing CMake projects into JMake without running CMake.

## Overview

JMake can parse `CMakeLists.txt` files and convert them to `jmake.toml` configuration, allowing you to work with CMake projects without needing CMake installed.

## Basic Import

```julia
using JMake

# Import CMake project
cmake_project = JMake.import_cmake("path/to/CMakeLists.txt")

# Compile the imported project
JMake.compile()
```

## Import Specific Target

```julia
# Import specific target from CMake project
JMake.import_cmake(
    "opencv/CMakeLists.txt",
    target="opencv_core",
    output="opencv_core.toml"
)
```

## What Gets Imported

JMake extracts from CMakeLists.txt:

- Project name and version
- Source files
- Include directories
- Compiler flags and definitions
- Target dependencies
- Library links

## Example: OpenCV Import

```julia
# Import OpenCV core module
cmake_proj = JMake.import_cmake(
    "/path/to/opencv/CMakeLists.txt",
    target="opencv_core"
)

# Review generated configuration
println("Project: $(cmake_proj.project_name)")
println("Targets: $(keys(cmake_proj.targets))")

# Compile to Julia bindings
JMake.compile()
```

## Generated Configuration

After import, `jmake.toml` contains:

```toml
[project]
name = "opencv_core"
version = "4.8.0"

[compiler]
standard = "c++17"
optimization = "O3"

[sources]
files = [
    "modules/core/src/array.cpp",
    "modules/core/src/matrix.cpp",
    # ... more files
]
include_dirs = [
    "modules/core/include",
    "build/include"
]
defines = [
    "CV_CPU_OPTIMIZATION_DECLARATIONS_ONLY",
    "HAVE_OPENCV_CORE"
]

[dependencies]
system_libs = ["pthread", "dl", "m"]
```

## Customizing After Import

Edit the generated `jmake.toml` to customize:

```toml
# Add additional source files
[sources]
files = [
    # CMake-discovered files...
    "custom/extra.cpp"  # Your additions
]

# Override compiler settings
[compiler]
optimization = "O2"  # Changed from O3
extra_flags = ["-march=native"]
```

## Advanced Features

### Multiple Targets

Import and build multiple CMake targets:

```julia
targets = ["opencv_core", "opencv_imgproc", "opencv_highgui"]

for target in targets
    JMake.import_cmake(
        "opencv/CMakeLists.txt",
        target=target,
        output="$(target).toml"
    )
    JMake.compile("$(target).toml")
end
```

### Dependency Resolution

CMake dependencies are preserved:

```toml
[dependencies]
# System libraries from CMake
system_libs = ["pthread", "z", "dl"]

# CMake target dependencies
# (if the dependency is also a JMake project)
jmake_deps = ["../opencv_core"]
```

## Limitations

JMake's CMake parser handles common patterns but has limitations:

- **No CMake execution**: Variables and functions aren't evaluated
- **Static parsing**: Conditional logic is not executed
- **Manual review needed**: Complex projects may need config adjustments

## Troubleshooting

### Missing Sources

If sources are missing, add them manually:

```toml
[sources]
files = [
    # Add missing files
    "additional/*.cpp"
]
```

### Incorrect Paths

Fix relative paths in generated config:

```toml
[sources]
# Update paths if they're wrong
include_dirs = [
    "/absolute/path/to/includes"
]
```

### Complex CMake Logic

For projects with complex CMake:

1. Import to get a starting point
2. Manually adjust the configuration
3. Add missing pieces

```julia
# Import as baseline
JMake.import_cmake("complex/CMakeLists.txt")

# Edit jmake.toml manually
# ...

# Compile with adjusted config
JMake.compile()
```

## Best Practices

1. **Review generated config**: Always check `jmake.toml` after import
2. **Start with simple targets**: Import leaf targets first
3. **Test incrementally**: Build and test each target separately
4. **Document changes**: Note manual adjustments in comments
5. **Keep CMake reference**: Maintain original CMakeLists.txt for reference
