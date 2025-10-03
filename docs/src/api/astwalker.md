# ASTWalker

C++ AST traversal and dependency analysis.

## Overview

ASTWalker provides tools for analyzing C++ Abstract Syntax Trees (AST) to:

- Identify dependencies between files
- Extract function signatures
- Analyze class hierarchies
- Detect include relationships

## Key Concepts

The AST (Abstract Syntax Tree) is a tree representation of source code structure. ASTWalker traverses this tree to understand code relationships without full compilation.

## Functions

```@docs
JMake.ASTWalker.analyze_file
JMake.ASTWalker.extract_dependencies
JMake.ASTWalker.find_definitions
JMake.ASTWalker.get_includes
```

## Usage Examples

### Analyze Single File

```julia
using JMake.ASTWalker

# Analyze C++ file
result = analyze_file("src/myclass.cpp",
    include_dirs=["include"]
)

# View dependencies
println("Dependencies: $(result.dependencies)")
println("Includes: $(result.includes)")
```

### Extract Function Signatures

```julia
# Find all function definitions
functions = find_definitions("src/api.cpp",
    type=:function
)

for func in functions
    println("Function: $(func.name)")
    println("  Return type: $(func.return_type)")
    println("  Parameters: $(func.parameters)")
end
```

### Dependency Graph

```julia
# Build dependency graph for project
files = ["src/a.cpp", "src/b.cpp", "src/c.cpp"]

graph = Dict()
for file in files
    deps = extract_dependencies(file)
    graph[file] = deps
end

# Topological sort for build order
build_order = topological_sort(graph)
```

## Analysis Results

### FileAnalysis

```julia
struct FileAnalysis
    file::String
    includes::Vector{String}
    dependencies::Vector{String}
    definitions::Vector{Definition}
    declarations::Vector{Declaration}
end
```

### Definition

```julia
struct Definition
    name::String
    type::Symbol  # :function, :class, :struct, :enum
    location::Location
    signature::String
end
```

## Advanced Features

### Template Analysis

```julia
# Analyze template definitions
templates = find_definitions("src/container.hpp",
    type=:template
)

for tmpl in templates
    println("Template: $(tmpl.name)")
    println("  Parameters: $(tmpl.template_params)")
end
```

### Class Hierarchy

```julia
# Extract class inheritance
classes = analyze_class_hierarchy("src/classes.cpp")

for cls in classes
    println("Class: $(cls.name)")
    if !isempty(cls.bases)
        println("  Inherits from: $(join(cls.bases, ", "))")
    end
end
```

## Performance Considerations

ASTWalker caches parsed ASTs to improve performance:

```julia
# Enable caching (default)
config = ASTWalkerConfig(
    cache_enabled = true,
    cache_dir = ".ast_cache"
)

# Analyze with caching
analyze_file("large_file.cpp", config)
```

## Integration with Discovery

ASTWalker is used by the Discovery module:

```julia
using JMake

# Discovery uses ASTWalker internally
result = JMake.scan(".")

# Access AST analysis results
println("Dependency relationships discovered via AST analysis")
```

## Best Practices

1. **Provide include paths**: Always specify include directories for accurate analysis
2. **Cache AST results**: Enable caching for large projects
3. **Incremental analysis**: Re-analyze only changed files
4. **Handle templates**: Be aware templates may have complex dependencies
5. **Cross-reference**: Combine AST analysis with file system scanning
