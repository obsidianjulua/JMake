# JuliaWrapItUp

Binary wrapper generation for existing shared libraries.

## Overview

JuliaWrapItUp generates Julia bindings from compiled binaries without requiring source code. It:

- Scans binary symbols
- Generates Julia wrappers
- Handles C/C++ ABI
- Creates type-safe interfaces

## Functions

```@docs
JMake.JuliaWrapItUp.generate_wrappers
JMake.JuliaWrapItUp.scan_binaries
JMake.JuliaWrapItUp.create_default_wrapper_config
JMake.JuliaWrapItUp.save_wrapper_config
```

## Data Structures

### BinaryWrapper

```julia
struct BinaryWrapper
    config::WrapperConfig
    binary_path::String
    symbols::Vector{Symbol}
end
```

### WrapperConfig

```julia
struct WrapperConfig
    name::String
    library_path::String
    output_dir::String
    include_symbols::Vector{String}
    exclude_symbols::Vector{String}
    module_name::String
end
```

## Usage Examples

### Wrap Single Binary

```julia
using JMake.JuliaWrapItUp

# Create wrapper
wrapper = BinaryWrapper("wrapper_config.toml")

# Generate wrappers
generate_wrappers(wrapper)
```

### Scan and Wrap

```julia
# Scan directory for binaries
binaries = scan_binaries("/usr/lib")

# Filter for specific library
target_lib = filter(b -> contains(b, "libcrypto"), binaries)[1]

# Create and generate wrapper
wrapper = BinaryWrapper(target_lib)
generate_wrappers(wrapper)
```

### Custom Configuration

```julia
# Create config
config = WrapperConfig(
    name = "OpenSSL",
    library_path = "/usr/lib/libssl.so",
    output_dir = "wrappers",
    include_symbols = ["SSL_*", "TLS_*"],
    exclude_symbols = ["*_internal"],
    module_name = "OpenSSL"
)

# Save config
save_wrapper_config(config, "ssl_wrapper.toml")

# Generate
wrapper = BinaryWrapper("ssl_wrapper.toml")
generate_wrappers(wrapper)
```

## Symbol Scanning

### Available Symbols

JuliaWrapItUp scans for:

- **Exported functions**: C functions with external linkage
- **Global variables**: Exported data symbols
- **C++ mangled names**: Demangled when possible

### Symbol Filtering

Use patterns to control wrapping:

```julia
config = WrapperConfig(
    # Include only math functions
    include_symbols = ["sin", "cos", "tan", "exp", "log", "sqrt"],
    # Exclude underscore-prefixed
    exclude_symbols = ["_*"]
)
```

## Generated Wrappers

### Module Structure

Generated Julia module:

```julia
module LibraryWrapper

# Load library
const lib = "/path/to/library.so"

# Wrapped functions
function wrapped_function(arg1::Type1, arg2::Type2)
    ccall((:original_function, lib), ReturnType, (Type1, Type2), arg1, arg2)
end

# Export public API
export wrapped_function

end
```

### Type Mapping

Automatic C → Julia type mapping:

| C Type | Julia Type |
|--------|-----------|
| `int` | `Cint` |
| `double` | `Cdouble` |
| `char*` | `Cstring` |
| `void*` | `Ptr{Cvoid}` |
| `size_t` | `Csize_t` |

## Advanced Features

### C++ Name Demangling

```julia
# C++ mangled: _Z3addii
# Demangled: add(int, int)

# Automatically generates:
function add(a::Cint, b::Cint)
    ccall((:_Z3addii, lib), Cint, (Cint, Cint), a, b)
end
```

### Struct Wrapping

For libraries with exported structs:

```julia
# Detected C struct
struct CStruct
    field1::Cint
    field2::Cdouble
end

# Generated Julia equivalent
struct WrappedStruct
    field1::Int32
    field2::Float64
end
```

### Callback Support

Wrap function pointers:

```julia
# C callback type: void (*callback)(int)
const CallbackType = Ptr{Cvoid}

# Wrapper function accepting Julia functions
function set_callback(f::Function)
    c_func = @cfunction($f, Cvoid, (Cint,))
    ccall((:set_callback_native, lib), Cvoid, (CallbackType,), c_func)
end
```

## Binary Analysis

### Metadata Extraction

```julia
# Get binary information
info = BinaryInfo("/usr/lib/libssl.so")

println("Format: $(info.format)")        # ELF, Mach-O, PE
println("Architecture: $(info.arch)")    # x86_64, aarch64, etc.
println("Symbols: $(length(info.symbols))")
```

### Dependency Analysis

```julia
# Find library dependencies
deps = get_binary_dependencies("/usr/lib/libssl.so")

for dep in deps
    println("Depends on: $dep")
end
```

## Configuration File Format

### Complete Example

```toml
[wrapper]
name = "MyLibWrapper"
library_path = "/usr/lib/libmylib.so"
output_dir = "julia_wrappers"
header_hints = ["/usr/include/mylib.h"]

[scanning]
include_symbols = [
    "mylib_*",      # All functions starting with mylib_
    "MyClass*"      # All C++ class methods
]
exclude_symbols = [
    "_*",           # Underscore-prefixed (internal)
    "*_internal",   # Explicitly internal functions
    "*_test*"       # Test functions
]
scan_dependencies = true
dependency_dirs = ["/usr/lib", "/usr/local/lib"]

[generation]
module_name = "MyLib"
create_tests = true
add_docstrings = true
safe_mode = true  # Add bounds checking

[type_mapping]
"mylib_size_t" = "UInt64"
"mylib_handle_t" = "Ptr{Cvoid}"

[options]
verbose = true
force_regenerate = false
backup_existing = true
```

## Best Practices

1. **Start with specific symbols**: Don't wrap entire library at once
2. **Test incrementally**: Verify each wrapped function works
3. **Handle memory carefully**: Be explicit about ownership
4. **Document assumptions**: Note ABI assumptions in wrapper
5. **Version tracking**: Track library version in wrapper config
