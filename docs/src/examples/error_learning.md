# Error Learning Example

Demonstration of JMake's error learning and suggestion system.

## Overview

JMake automatically learns from compilation errors and suggests fixes based on historical patterns.

## Example Workflow

### Initial Compilation Error

Create a C++ file with a common error:

`test.cpp`:

```cpp
#include <vector>

int main() {
    vector<int> numbers;  // Missing std:: namespace
    numbers.push_back(42);
    return 0;
}
```

Compile:

```julia
using JMake.LLVMake

try
    compile_source("test.cpp")
catch e
    println("Error: $e")
end
```

Output:

```
test.cpp:4:5: error: use of undeclared identifier 'vector'
    vector<int> numbers;
    ^

Error: Compilation failed
```

JMake automatically:
1. Captures the error
2. Normalizes the pattern
3. Stores in error database

### First Fix

Fix the code:

```cpp
#include <vector>

int main() {
    std::vector<int> numbers;  // Fixed
    numbers.push_back(42);
    return 0;
}
```

Record the solution:

```julia
using JMake.ErrorLearning

learn_error(
    "test.cpp:4:5: error: use of undeclared identifier 'vector'",
    solution = "Add std:: namespace prefix",
    context = "Missing namespace for standard library type"
)
```

### Similar Error Later

New file `test2.cpp`:

```cpp
#include <string>

int main() {
    string name = "Alice";  // Same type of error
    return 0;
}
```

Compile:

```julia
try
    compile_source("test2.cpp")
catch e
    # JMake automatically suggests fix
    println("Error: $e")

    suggestion = suggest_fix(e.message)
    if suggestion !== nothing
        println("\n💡 Suggested fix:")
        println(suggestion.fix)
        println("Confidence: $(suggestion.confidence * 100)%")
        println("Based on $(suggestion.occurrences) similar errors")
    end
end
```

Output:

```
test2.cpp:4:5: error: use of undeclared identifier 'string'

💡 Suggested fix:
Add std:: namespace prefix
Confidence: 95%
Based on 1 similar error
```

## Common Error Patterns

### Missing Headers

Error:

```
error: 'cout' was not declared in this scope
```

JMake learns:

```julia
learn_error(
    "error: 'cout' was not declared in this scope",
    solution = "Add: #include <iostream>\nUse: std::cout",
    category = :compilation
)
```

### Linking Errors

Error:

```
undefined reference to `pthread_create'
```

JMake learns:

```julia
learn_error(
    "undefined reference to `pthread_create'",
    solution = "Add -lpthread to link flags",
    category = :linking
)
```

### Template Errors

Error:

```
error: no matching function for call to 'make_unique<Foo>()'
```

JMake learns:

```julia
learn_error(
    "error: no matching function for call to 'make_unique'",
    solution = "Requires C++14 or later. Set standard = \"c++14\" in jmake.toml",
    category = :compilation
)
```

## Error Statistics

### View Error History

```julia
using JMake.ErrorLearning

# Get statistics
stats = get_error_statistics()

println("Total errors: $(stats.total)")
println("Unique patterns: $(stats.unique_patterns)")
println("Average resolution time: $(stats.avg_resolution_time)")

# Most common errors
println("\nTop 5 errors:")
for (i, (pattern, count)) in enumerate(stats.top_errors[1:5])
    println("$i. [$count occurrences] $pattern")
end
```

Output:

```
Total errors: 127
Unique patterns: 23
Average resolution time: 45 seconds

Top 5 errors:
1. [15 occurrences] undefined reference to pthread_*
2. [12 occurrences] use of undeclared identifier
3. [8 occurrences] no matching function for call
4. [7 occurrences] template argument deduction failed
5. [5 occurrences] incomplete type
```

### Export Error Log

```julia
# Export to Markdown
JMake.export_errors("project_errors.md")
```

Generated `project_errors.md`:

```markdown
# Project Error Log

Generated: 2024-01-20

## Summary

- Total errors: 127
- Unique patterns: 23
- Success rate: 87%

## Top Errors

### 1. Linking Error - pthread (15 occurrences)

**Pattern**: `undefined reference to pthread_*`

**Solution**:
Add `-lpthread` to link flags:

\```toml
[dependencies]
system_libs = ["pthread"]
\```

**First seen**: 2024-01-10
**Last seen**: 2024-01-19
**Success rate**: 100%

---

### 2. Undeclared Identifier (12 occurrences)

**Pattern**: `use of undeclared identifier`

**Common causes**:
- Missing namespace (std::)
- Missing header include
- Typo in variable name

**Solutions**:
1. Add appropriate namespace
2. Include required header
3. Check spelling

**Success rate**: 92%

...
```

## Integration with Daemon System

The daemon system continuously learns from errors:

```julia
# Start daemon with error learning enabled
include("daemons/servers/error_handler_daemon.jl")

# Daemon automatically:
# 1. Monitors compilation errors
# 2. Learns patterns
# 3. Updates database
# 4. Suggests fixes in real-time
```

## Advanced Features

### Custom Error Patterns

Define project-specific patterns:

```julia
# Define custom pattern
custom_pattern = ErrorPattern(
    pattern = r"MyCustomError: .*",
    category = :custom,
    solution = "Check MyCustom configuration",
    confidence = 0.9
)

# Register pattern
register_error_pattern(custom_pattern)
```

### Error Prediction

Predict likely errors before compilation:

```julia
using JMake.ErrorLearning

# Analyze source before compiling
potential_errors = predict_errors("risky_code.cpp")

println("Potential issues:")
for err in potential_errors
    println("  - $(err.description) ($(err.probability * 100)% likely)")
    println("    Fix: $(err.suggested_fix)")
end
```

### Team Knowledge Sharing

Share error database across team:

```julia
# Export knowledge base
export_error_knowledge("team_errors.db")

# Team members import
import_error_knowledge("team_errors.db")

# Merged with local knowledge
# Everyone benefits from collective experience
```

## Best Practices

1. **Record solutions**: Always record what fixed the error
2. **Categorize properly**: Use appropriate error categories
3. **Update success rates**: Mark which solutions worked
4. **Review periodically**: Check error patterns monthly
5. **Share knowledge**: Export and share team knowledge base
6. **Clean obsolete**: Remove outdated error patterns
7. **Add context**: Include file/configuration context with errors

## Benefits

- **Faster debugging**: Immediate suggestions for known errors
- **Learning curve**: New team members benefit from past experience
- **Pattern recognition**: Identify recurring issues
- **Documentation**: Auto-generated error reference
- **Continuous improvement**: System gets smarter over time
