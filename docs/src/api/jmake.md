# JMake API

Main JMake module API reference.

## Module Information

```@docs
JMake
JMake.VERSION
```

## Initialization Functions

```@docs
JMake.init
```

## Compilation Functions

```@docs
JMake.compile
JMake.discover_tools
```

## Wrapping Functions

```@docs
JMake.wrap
JMake.wrap_binary
```

## Import/Export Functions

```@docs
JMake.import_cmake
JMake.export_errors
```

## Analysis Functions

```@docs
JMake.scan
JMake.analyze
```

## Information Functions

```@docs
JMake.info
JMake.help
```

## Usage Examples

### Initialize and Compile

```julia
using JMake

# Initialize C++ project
JMake.init("myproject")

# Add source files to src/
# Edit jmake.toml

# Compile
cd("myproject")
JMake.compile()
```

### Binary Wrapping

```julia
# Initialize wrapper project
JMake.init("wrappers", type=:binary)

# Wrap specific binary
cd("wrappers")
JMake.wrap_binary("/usr/lib/libcrypto.so")
```

### CMake Import

```julia
# Import CMake project
cmake_proj = JMake.import_cmake("third_party/CMakeLists.txt")

# Compile imported project
JMake.compile()
```

### Error Analysis

```julia
# After compilation with errors
stats = JMake.get_error_stats()

# Export error log
JMake.export_errors("build_errors.md")
```
