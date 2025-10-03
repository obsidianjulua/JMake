# Binary Wrapping Guide

Generate Julia wrappers for existing binary libraries.

## Overview

JMake can wrap existing shared libraries (`.so`, `.dll`, `.dylib`) without needing source code.

## Basic Workflow

### 1. Initialize Wrapper Project

```julia
using JMake
JMake.init("mybindings", type=:binary)
cd("mybindings")
```

### 2. Configure Wrapper

Edit `wrapper_config.toml`:

```toml
[wrapper]
name = "MyLibWrapper"
library_path = "/usr/lib/libmylib.so"
output_dir = "julia_wrappers"

[scanning]
include_symbols = ["*"]  # Include all symbols
exclude_symbols = ["_internal_*"]  # Exclude internal symbols

[generation]
module_name = "MyLib"
```

### 3. Generate Wrappers

```julia
# Wrap configured libraries
JMake.wrap()

# Or wrap specific binary
JMake.wrap_binary("/usr/lib/libmylib.so")
```

## Advanced Configuration

### Symbol Filtering

Control which symbols are wrapped:

```toml
[scanning]
# Include only public API
include_symbols = [
    "mylib_*",
    "MyLib*"
]

# Exclude internals
exclude_symbols = [
    "_*",
    "*_internal",
    "*_private"
]
```

### Binary Discovery

Automatically scan directories:

```julia
# Scan for binaries
binaries = JMake.scan_binaries("lib/")

# Generate wrappers for all found binaries
for binary in binaries
    JMake.wrap_binary(binary)
end
```

### Multiple Libraries

Wrap multiple libraries in one project:

```toml
[[libraries]]
name = "Core"
path = "/usr/lib/libcore.so"
module_name = "Core"

[[libraries]]
name = "Utils"
path = "/usr/lib/libutils.so"
module_name = "Utils"
```

## Wrapper Configuration Options

### Full Configuration

```toml
[wrapper]
name = "CompleteWrapper"
library_path = "/path/to/lib.so"
output_dir = "wrappers"
header_hints = ["/path/to/headers"]  # Optional headers for better wrapping

[scanning]
include_symbols = ["*"]
exclude_symbols = []
scan_dependencies = true  # Also wrap dependencies

[generation]
module_name = "MyModule"
create_tests = true
add_docstrings = true

[options]
verbose = true
force_regenerate = false
```

## Using Wrapped Bindings

```julia
# Load generated wrapper
include("julia_wrappers/MyLib.jl")
using .MyLib

# Use wrapped functions
result = MyLib.some_function(arg1, arg2)
```

## Wrapping System Libraries

### Example: Wrapping libm (Math Library)

```julia
JMake.init("libm_wrapper", type=:binary)
cd("libm_wrapper")

# Configure for libm
wrapper_config = """
[wrapper]
name = "LibM"
library_path = "/usr/lib/x86_64-linux-gnu/libm.so"
output_dir = "julia_wrappers"

[scanning]
include_symbols = ["sin", "cos", "tan", "exp", "log"]

[generation]
module_name = "LibM"
"""

write("wrapper_config.toml", wrapper_config)
JMake.wrap()
```

### Example: Wrapping OpenSSL

```julia
JMake.wrap_binary("/usr/lib/libssl.so")
```

## Advanced Features

### Dependency Tracking

Automatically wrap library dependencies:

```toml
[scanning]
scan_dependencies = true
dependency_dirs = ["/usr/lib", "/usr/local/lib"]
```

### Custom Symbol Mapping

Rename symbols in Julia:

```toml
[symbol_mapping]
"_Z3fooii" = "foo"  # Demangle C++ symbols
"old_name" = "new_name"
```

### Header Assistance

Provide headers for better type information:

```toml
[wrapper]
header_hints = [
    "/usr/include/mylib.h",
    "/usr/local/include/mylib"
]
```

## Troubleshooting

### Symbol Not Found

Use `nm` to inspect available symbols:

```bash
nm -D /path/to/library.so | grep symbol_name
```

### ABI Compatibility

Ensure the binary was compiled with a compatible ABI:

```julia
# Check library info
run(`file /path/to/library.so`)
```

### Missing Dependencies

Check library dependencies:

```bash
ldd /path/to/library.so
```

## Best Practices

1. **Start small**: Wrap specific symbols first, expand gradually
2. **Test thoroughly**: Verify wrapped functions work correctly
3. **Document mappings**: Keep track of symbol name mappings
4. **Version control**: Commit wrapper configurations
5. **Handle errors**: Wrapped functions may have different error conventions
