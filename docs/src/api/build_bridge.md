# BuildBridge

Command execution framework with error learning and recovery.

## Overview

BuildBridge provides robust command execution with:

- Error capture and analysis
- Pattern learning from failures
- Automatic retry logic
- SQLite-backed error database

## Functions

```@docs
JMake.BuildBridge.execute
JMake.BuildBridge.capture
JMake.BuildBridge.find_executable
JMake.BuildBridge.command_exists
JMake.BuildBridge.discover_llvm_tools
JMake.BuildBridge.compile_with_learning
```

## Command Execution

### Basic Execution

```julia
using JMake.BuildBridge

# Execute command
success = execute(`clang++ -o output input.cpp`)

# Capture output
output, status = capture(`llvm-config --version`)
println("LLVM version: $output")
```

### With Error Handling

```julia
# Execute with automatic error learning
try
    compile_with_learning(`make all`)
catch e
    # Error logged to database
    println("Compilation failed: $e")

    # Check for similar past errors
    similar = find_similar_errors(e)
    if !isempty(similar)
        println("Similar error seen $(similar.count) times")
        println("Suggested fix: $(similar.suggestion)")
    end
end
```

## Error Learning

### Error Database

BuildBridge maintains an SQLite database of errors:

```julia
# Get error database
db = get_error_db()

# Query error statistics
stats = get_error_stats(db)
println("Total errors: $(stats.total)")
println("Unique patterns: $(stats.unique)")
println("Most common: $(stats.most_common)")
```

### Error Patterns

Automatically detects patterns:

- Compilation errors (syntax, type errors)
- Linking errors (undefined symbols, library not found)
- Runtime errors (segfaults, assertions)
- Configuration errors (missing tools, wrong flags)

### Learning Algorithm

1. **Capture**: Record error output
2. **Normalize**: Extract pattern (remove file-specific details)
3. **Store**: Save to database with context
4. **Match**: Compare new errors to known patterns
5. **Suggest**: Provide fix based on past solutions

## Tool Discovery

### Find Executables

```julia
# Find tool in PATH
clang_path = find_executable("clang++")
if clang_path !== nothing
    println("Found: $clang_path")
end

# Check if command exists
if command_exists("llvm-config")
    println("LLVM tools available")
end
```

### LLVM Tools Discovery

```julia
# Discover all LLVM tools
tools = discover_llvm_tools()

println("Found $(length(tools)) LLVM tools:")
for tool in tools
    println("  $(tool.name) - $(tool.path)")
end
```

## Error Export

### Export to Markdown

```julia
# Export errors to Obsidian-friendly markdown
export_error_log("jmake_errors.db", "error_log.md")
```

Generated format:

```markdown
# Error Log

## Compilation Errors

### Error: undefined reference to 'pthread_create'
**Occurrences**: 5
**Pattern**: Linking error - missing pthread library

**Solution**:
Add `-lpthread` to link flags

**Context**:
- Files affected: networking.cpp, threads.cpp
- First seen: 2024-01-15
- Last seen: 2024-01-20

---

### Error: 'vector' file not found
**Occurrences**: 3
**Pattern**: Missing standard library headers

**Solution**:
Install libstdc++-dev or add include path

...
```

## Advanced Features

### Retry Logic

```julia
# Execute with automatic retry on transient failures
result = execute_with_retry(
    `curl https://example.com/file.tar.gz`,
    max_retries = 3,
    retry_delay = 5  # seconds
)
```

### Timeout Handling

```julia
# Execute with timeout
result = execute_with_timeout(
    `long_running_command`,
    timeout = 60  # seconds
)
```

### Environment Management

```julia
# Execute with custom environment
env = Dict("CC" => "clang", "CXX" => "clang++")
execute(`make`, env=env)
```

## Configuration

### ErrorLearning Settings

```julia
struct ErrorLearningConfig
    db_path::String           # Database file path
    min_similarity::Float64   # Minimum similarity for pattern match (0.0-1.0)
    max_suggestions::Int      # Maximum suggestions to return
    auto_apply_fixes::Bool    # Automatically apply known fixes
end
```

## Database Schema

Error database structure:

```sql
CREATE TABLE errors (
    id INTEGER PRIMARY KEY,
    pattern TEXT,           -- Normalized error pattern
    raw_error TEXT,         -- Original error message
    context TEXT,           -- Compilation context (files, flags)
    solution TEXT,          -- Known solution
    occurrence_count INT,   -- Times this pattern occurred
    first_seen DATETIME,
    last_seen DATETIME
);

CREATE TABLE error_fixes (
    id INTEGER PRIMARY KEY,
    error_id INTEGER,
    fix_description TEXT,
    success_rate REAL,      -- 0.0-1.0
    FOREIGN KEY(error_id) REFERENCES errors(id)
);
```

## Integration

BuildBridge integrates with:

- **LLVMake**: Compilation error tracking
- **JuliaWrapItUp**: Symbol scanning errors
- **Daemon System**: Background error processing
- **CMakeParser**: CMake parsing errors

## Best Practices

1. **Enable learning**: Always use `compile_with_learning` for builds
2. **Review patterns**: Periodically check error patterns
3. **Share database**: Team can share learned error database
4. **Export regularly**: Export errors for documentation
5. **Clean old entries**: Prune obsolete error patterns
