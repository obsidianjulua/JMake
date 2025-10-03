# ErrorLearning

Intelligent error pattern recognition and solution suggestion system.

## Overview

ErrorLearning is an integrated component of BuildBridge that:

- Learns from compilation errors over time
- Suggests solutions based on historical patterns
- Builds a knowledge base of common issues
- Provides context-aware error resolution

## Core Concepts

### Error Normalization

Errors are normalized to extract patterns:

```julia
# Original error
"/home/user/project/src/file.cpp:42: undefined reference to `pthread_create'"

# Normalized pattern
"*.cpp:*: undefined reference to `pthread_create'"

# This allows matching similar errors across different files/lines
```

### Similarity Matching

Uses Levenshtein distance and pattern matching to find similar errors:

```julia
# New error
"undefined reference to `pthread_join'"

# Matches pattern
"undefined reference to `pthread_*'"

# Returns known solution
"Link with -lpthread"
```

## Functions

```@docs
JMake.ErrorLearning.learn_error
JMake.ErrorLearning.find_similar_errors
JMake.ErrorLearning.suggest_fix
JMake.ErrorLearning.get_error_statistics
```

## Usage Examples

### Record Error

```julia
using JMake.ErrorLearning

# Compilation failed with error
error_msg = """
test.cpp:10:5: error: use of undeclared identifier 'cout'
    cout << "Hello";
    ^
"""

# Learn from this error
learn_error(
    error_msg,
    context = "test.cpp",
    solution = "Add: #include <iostream>\nUse: std::cout"
)
```

### Find Similar Errors

```julia
# New error occurs
new_error = "main.cpp:15:3: error: use of undeclared identifier 'cin'"

# Find similar past errors
similar = find_similar_errors(new_error)

if !isempty(similar)
    println("Found $(length(similar)) similar errors")
    best_match = similar[1]
    println("Similarity: $(best_match.similarity * 100)%")
    println("Suggested fix: $(best_match.solution)")
end
```

### Auto-suggest Fixes

```julia
# During compilation
try
    compile_source("code.cpp")
catch e
    # Automatically suggest fix
    suggestion = suggest_fix(e.message)

    if suggestion !== nothing
        println("Error: $(e.message)")
        println("\nSuggested fix:")
        println(suggestion.fix)
        println("\nConfidence: $(suggestion.confidence * 100)%")
        println("Based on $(suggestion.occurrences) previous occurrences")
    end
end
```

## Error Categories

ErrorLearning categorizes errors:

### Compilation Errors

- Syntax errors
- Type mismatches
- Undeclared identifiers
- Template instantiation failures

### Linking Errors

- Undefined references
- Multiple definitions
- Library not found
- Symbol version conflicts

### Configuration Errors

- Missing tools
- Incorrect flags
- Path issues
- Version mismatches

## Statistics and Analysis

### Error Statistics

```julia
# Get overall statistics
stats = get_error_statistics()

println("Total errors logged: $(stats.total)")
println("Unique patterns: $(stats.unique_patterns)")
println("Success rate of suggested fixes: $(stats.fix_success_rate * 100)%")

# Most common errors
for (pattern, count) in stats.top_errors
    println("$count occurrences: $pattern")
end
```

### Trend Analysis

```julia
# Get error trends
trends = analyze_error_trends(days=30)

println("Errors in last 30 days:")
for day in trends
    println("$(day.date): $(day.count) errors")
end
```

## Database Integration

### Schema

```julia
struct ErrorEntry
    id::Int
    pattern::String
    raw_error::String
    context::String
    solution::String
    occurrence_count::Int
    first_seen::DateTime
    last_seen::DateTime
    category::Symbol
end
```

### Queries

```julia
# Query specific error pattern
errors = query_errors(pattern="undefined reference")

# Query by category
linking_errors = query_errors(category=:linking)

# Query by date range
recent_errors = query_errors(
    after=DateTime(2024, 1, 1),
    before=DateTime(2024, 2, 1)
)
```

## Solution Database

### Recording Solutions

```julia
# Add solution to known error
add_solution(
    error_pattern = "*.cpp:*: undefined reference to `pthread_*'",
    solution = "Add -lpthread to link flags",
    success_rate = 0.95
)
```

### Solution Ranking

Solutions are ranked by:

1. **Success rate**: How often the fix worked
2. **Recency**: Recent solutions ranked higher
3. **Context match**: Better match to current context

## Export and Sharing

### Export Knowledge Base

```julia
# Export entire error database
export_error_knowledge("error_kb.json")

# Share with team
# Others can import:
import_error_knowledge("error_kb.json")
```

### Generate Documentation

```julia
# Generate error reference guide
generate_error_guide(
    output="error_reference.md",
    format=:markdown,
    include_solutions=true,
    include_examples=true
)
```

## Integration Examples

### With LLVMake

```julia
# LLVMake automatically uses ErrorLearning
config = BridgeCompilerConfig("jmake.toml")

try
    compile_project(config)
catch e
    # Error automatically learned
    # Suggestions automatically provided
end
```

### With Daemon System

```julia
# Error handler daemon uses ErrorLearning
# Continuously learns from background builds
# Builds knowledge base over time
```

## Best Practices

1. **Consistent context**: Always provide file/line context when learning
2. **Verify solutions**: Only record solutions that actually worked
3. **Update success rates**: Track which solutions work
4. **Regular cleanup**: Remove obsolete error patterns
5. **Share knowledge**: Export and share error databases across team
6. **Review suggestions**: Don't blindly apply auto-suggestions
7. **Categorize properly**: Correct categorization improves matching
