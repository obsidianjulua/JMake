# Wrapper Generation Example

Generate Julia wrappers for existing binary libraries.

## Example: Wrapping SQLite

We'll wrap the SQLite C library as a practical example.

### Step 1: Initialize Wrapper Project

```julia
using JMake

JMake.init("SQLiteWrapper", type=:binary)
cd("SQLiteWrapper")
```

### Step 2: Locate SQLite Library

```bash
# Find SQLite library on your system
ls /usr/lib/x86_64-linux-gnu/libsqlite3.so*
```

### Step 3: Configure Wrapper

Edit `wrapper_config.toml`:

```toml
[wrapper]
name = "SQLiteWrapper"
library_path = "/usr/lib/x86_64-linux-gnu/libsqlite3.so.0"
output_dir = "julia_wrappers"

[scanning]
# Include only main API functions
include_symbols = [
    "sqlite3_open",
    "sqlite3_close",
    "sqlite3_exec",
    "sqlite3_prepare_v2",
    "sqlite3_step",
    "sqlite3_finalize",
    "sqlite3_column_*",
    "sqlite3_bind_*",
    "sqlite3_errmsg"
]

# Exclude internal functions
exclude_symbols = ["*internal*", "_*"]

[generation]
module_name = "SQLiteWrapper"
create_tests = true
add_docstrings = true
```

### Step 4: Generate Wrappers

```julia
JMake.wrap()
```

Output:
```
🚀 JMake - Generating binary wrappers
📖 Reading binary: /usr/lib/x86_64-linux-gnu/libsqlite3.so.0
🔍 Scanning symbols...
   Found 156 symbols
   Filtered to 12 symbols
📝 Generating wrappers...
✅ Generated: julia_wrappers/SQLiteWrapper.jl
🎉 Wrapper generation complete!
```

### Step 5: Use the Wrapper

Create `test_sqlite.jl`:

```julia
include("julia_wrappers/SQLiteWrapper.jl")
using .SQLiteWrapper

# Open database
db_ptr = Ref{Ptr{Cvoid}}()
result = sqlite3_open(":memory:", db_ptr)

if result != 0
    error("Failed to open database")
end

db = db_ptr[]
println("✓ Database opened")

# Create table
sql = """
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    age INTEGER
);
"""

result = sqlite3_exec(db, sql, C_NULL, C_NULL, C_NULL)
@assert result == 0
println("✓ Table created")

# Insert data
sql = "INSERT INTO users (name, age) VALUES ('Alice', 30)"
result = sqlite3_exec(db, sql, C_NULL, C_NULL, C_NULL)
@assert result == 0
println("✓ Data inserted")

# Query data
sql = "SELECT * FROM users"
stmt_ptr = Ref{Ptr{Cvoid}}()
result = sqlite3_prepare_v2(db, sql, -1, stmt_ptr, C_NULL)
@assert result == 0

stmt = stmt_ptr[]
println("\nUsers:")
while sqlite3_step(stmt) == 100  # SQLITE_ROW
    id = sqlite3_column_int(stmt, 0)
    name = unsafe_string(sqlite3_column_text(stmt, 1))
    age = sqlite3_column_int(stmt, 2)
    println("  ID: $id, Name: $name, Age: $age")
end

# Cleanup
sqlite3_finalize(stmt)
sqlite3_close(db)
println("\n✓ Database closed")
```

## Example: Wrapping Custom Library

### Custom C Library

`mylib.h`:

```c
#ifndef MYLIB_H
#define MYLIB_H

typedef struct {
    double x;
    double y;
} Point;

void point_init(Point* p, double x, double y);
double point_distance(const Point* p1, const Point* p2);
void point_midpoint(const Point* p1, const Point* p2, Point* result);

#endif
```

`mylib.c`:

```c
#include "mylib.h"
#include <math.h>

void point_init(Point* p, double x, double y) {
    p->x = x;
    p->y = y;
}

double point_distance(const Point* p1, const Point* p2) {
    double dx = p2->x - p1->x;
    double dy = p2->y - p1->y;
    return sqrt(dx*dx + dy*dy);
}

void point_midpoint(const Point* p1, const Point* p2, Point* result) {
    result->x = (p1->x + p2->x) / 2.0;
    result->y = (p1->y + p2->y) / 2.0;
}
```

Build the library:

```bash
gcc -shared -fPIC -o libmylib.so mylib.c -lm
```

### Wrap the Library

```julia
using JMake

# Generate wrapper for custom library
JMake.init("MyLibWrapper", type=:binary)
cd("MyLibWrapper")

# Copy library to lib directory
cp("../libmylib.so", "lib/libmylib.so")

# Configure wrapper
config = """
[wrapper]
name = "MyLib"
library_path = "lib/libmylib.so"
output_dir = "julia_wrappers"
header_hints = ["../mylib.h"]

[scanning]
include_symbols = ["point_*"]

[generation]
module_name = "MyLib"
"""

write("wrapper_config.toml", config)

# Generate
JMake.wrap()
```

### Use Custom Wrapper

```julia
include("julia_wrappers/MyLib.jl")
using .MyLib

# Create points
p1 = Point(0.0, 0.0)
p2 = Point(3.0, 4.0)

point_init(Ref(p1), 0.0, 0.0)
point_init(Ref(p2), 3.0, 4.0)

# Calculate distance
dist = point_distance(Ref(p1), Ref(p2))
println("Distance: $dist")  # 5.0

# Find midpoint
mid = Point(0.0, 0.0)
point_midpoint(Ref(p1), Ref(p2), Ref(mid))
println("Midpoint: ($(mid.x), $(mid.y))")  # (1.5, 2.0)
```

## Advanced Wrapper Features

### Type-Safe Wrappers

Improve the generated wrapper with Julia types:

```julia
module MyLibSafe

include("../julia_wrappers/MyLib.jl")
using .MyLib

# Julia-friendly Point type
struct JuliaPoint
    x::Float64
    y::Float64
end

# Convert to C Point
function to_c_point(jp::JuliaPoint)
    p = Point(jp.x, jp.y)
    return p
end

# Convert from C Point
function from_c_point(p::Point)
    return JuliaPoint(p.x, p.y)
end

# Safe wrappers
function distance(p1::JuliaPoint, p2::JuliaPoint)
    c_p1 = to_c_point(p1)
    c_p2 = to_c_point(p2)
    return point_distance(Ref(c_p1), Ref(c_p2))
end

function midpoint(p1::JuliaPoint, p2::JuliaPoint)
    c_p1 = to_c_point(p1)
    c_p2 = to_c_point(p2)
    c_result = Point(0.0, 0.0)
    point_midpoint(Ref(c_p1), Ref(c_p2), Ref(c_result))
    return from_c_point(c_result)
end

export JuliaPoint, distance, midpoint

end
```

Usage:

```julia
using .MyLibSafe

p1 = JuliaPoint(0.0, 0.0)
p2 = JuliaPoint(3.0, 4.0)

# Clean Julia API
dist = distance(p1, p2)
mid = midpoint(p1, p2)

println("Distance: $dist")
println("Midpoint: $(mid.x), $(mid.y)")
```

## Troubleshooting

### Symbol Not Found

If symbols aren't found:

```julia
# Inspect binary
using JMake.JuliaWrapItUp

bininfo = BinaryInfo("lib/libmylib.so")
println("Available symbols:")
for sym in bininfo.symbols
    println("  $sym")
end
```

### ABI Mismatches

For C++ libraries with name mangling:

```toml
[scanning]
# Use exact mangled name
include_symbols = ["_Z10point_initP5Pointdd"]

[symbol_mapping]
# Map to friendly name
"_Z10point_initP5Pointdd" = "point_init"
```

## Best Practices

1. **Start specific**: Wrap only needed functions initially
2. **Test each function**: Verify behavior matches expectations
3. **Create safe wrappers**: Add Julia-friendly layer on top
4. **Handle memory**: Be explicit about ownership and lifetime
5. **Document ABI**: Note calling convention assumptions
6. **Version tracking**: Track library version in wrapper
