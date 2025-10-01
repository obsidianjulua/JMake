# JMake Error Learning System

## Overview

JMake includes an **intelligent error correction system** that learns from compilation errors and automatically suggests or applies fixes. This system uses BERT embeddings (via EngineT.jl) for semantic error matching, allowing it to recognize similar errors even when the exact text differs.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  JMake Build Process                                     │
├─────────────────────────────────────────────────────────┤
│  1. Compile C++ → LLVM IR                               │
│  2. Error detected ❌                                   │
│  3. ErrorLearning.jl analyzes error                     │
│  4. Semantic search for similar errors (BERT)           │
│  5. Suggest/apply fix based on confidence               │
│  6. Retry compilation ✅                                │
│  7. Record outcome for future learning                   │
└─────────────────────────────────────────────────────────┘
```

### Components

1. **ErrorLearning.jl** - Core learning module
   - SQLite database for error patterns
   - BERT embeddings for semantic similarity
   - Confidence-based fix ranking

2. **BuildBridge.jl** - Integration layer
   - `compile_with_learning()` - Smart compilation with auto-retry
   - `record_compilation_fix()` - Learn from manual fixes

3. **EngineT.jl** - Optional semantic engine
   - BERT tokenizer and embeddings
   - Pure Julia implementation (no Python!)
   - Falls back to string matching if unavailable

## Configuration

Edit `jmake.toml`:

```toml
[learning]
enabled = true                   # Enable error learning
auto_fix = true                  # Auto-apply high-confidence fixes
max_retries = 3                  # Max retry attempts
confidence_threshold = 0.75      # Min confidence for auto-fix (0-1)
error_db = "jmake_errors.db"     # Database location
use_embeddings = true            # Use BERT (requires EngineT)
bootstrap_on_init = true         # Load common patterns
```

## Usage

### Automatic Error Correction

```julia
using JMake
using JMake.BuildBridge

# Compile with learning enabled
output, exitcode, attempts, suggestions = compile_with_learning(
    "clang++",
    ["myfile.cpp", "-o", "myfile.o"],
    max_retries = 3,
    confidence_threshold = 0.75,
    config_modifier = fix -> begin
        # Apply fix to jmake.toml
        # Return true if successful
        return apply_fix_to_config(fix)
    end
)

if exitcode == 0
    println("✅ Compilation succeeded after $attempts attempt(s)")
else
    println("❌ Compilation failed. Suggestions:")
    for suggestion in suggestions
        println("  • $suggestion")
    end
end
```

### Manual Learning

When you manually fix an error, teach the system:

```julia
using JMake.BuildBridge

# Record a successful fix
record_compilation_fix(
    "undefined reference to `pthread_create'",  # Error text
    "libraries += [\"pthread\"]",               # Fix action
    true,                                       # Success
    fix_type = "add_library",
    fix_description = "Link pthread library",
    project_path = pwd()
)
```

### Bootstrap Common Errors

```bash
cd /home/grim/.julia/julia/JMake
julia scripts/bootstrap_error_db.jl
```

This loads ~50 common C++/LLVM error patterns.

## Error Categories

The system tracks these error types:

| Category | Examples |
|----------|----------|
| `compiler_error` | Missing headers, syntax errors |
| `linker_error` | Undefined references, missing libraries |
| `llvm_error` | Invalid IR, optimization failures |
| `missing_header` | `fatal error: iostream: No such file` |
| `undefined_symbol` | `undefined reference to vtable` |
| `missing_pic` | `recompile with -fPIC` |
| `optimization_failure` | `Instruction does not dominate all uses` |

## How It Works

### 1. Error Detection

When compilation fails, ErrorLearning extracts:
- Error text
- Error type (linker, compiler, LLVM)
- Error category (missing_header, undefined_symbol, etc.)
- Context (file, line, symbol names)

### 2. Semantic Search

If EngineT is available:
- Error text → BERT embedding (768-dimensional vector)
- Compare with stored error embeddings (cosine similarity)
- Match threshold: 0.75 for auto-fix, 0.60 for suggestion

Without EngineT:
- Falls back to Jaccard string similarity
- Less accurate but still functional

### 3. Fix Ranking

Fixes are ranked by:
- **Similarity** - How close is this error to known patterns?
- **Success rate** - How often has this fix worked?
- **Confidence** - `success_count / (success_count + failure_count)`

### 4. Auto-Fix Application

If confidence ≥ threshold:
1. Apply fix (via `config_modifier` callback)
2. Retry compilation
3. Record outcome (success/failure)
4. Update confidence scores

If confidence < threshold:
- Suggest fixes to user
- Wait for manual application
- Learn from user's choice

## Database Schema

### `error_patterns`
```sql
id, error_text, error_type, error_category,
embedding (BLOB), created_at, last_seen, occurrence_count
```

### `error_fixes`
```sql
id, error_id, fix_type, fix_description, fix_action,
success_count, failure_count, confidence, created_at
```

### `fix_history`
```sql
id, error_id, fix_id, applied_at, success (0/1),
project_path, error_context
```

## Common Error Patterns

### Missing -fPIC
```
Error: relocation R_X86_64_32 can not be used when making a shared object
Fix:   flags += ["-fPIC"]
```

### Undefined pthread
```
Error: undefined reference to `pthread_create'
Fix:   libraries += ["pthread"]
```

### Missing Standard Library
```
Error: fatal error: iostream: No such file or directory
Fix:   flags += ["-I/usr/include/c++/11"]
```

### LLVM Optimization Failure
```
Error: Instruction does not dominate all uses!
Fix:   opt_level = "O1"  # Lower optimization
```

### C++ ABI Mismatch
```
Error: undefined symbol: _ZNSt...
Fix:   flags += ["-D_GLIBCXX_USE_CXX11_ABI=1"]
```

## Benefits

### 1. **Zero External Dependencies**
- Pure Julia (no Python/Ollama required)
- Works offline
- Runs in milliseconds

### 2. **Learning Across Projects**
- Share knowledge database
- Export/import learned patterns
- Community error databases possible

### 3. **Aligned with JMake Philosophy**
> "Backend logic makes AI stronger" - The more the system knows, the less the AI has to figure out.

### 4. **Self-Improving**
- Confidence scores improve with usage
- Failed fixes are recorded and avoided
- New patterns learned automatically

## Comparison with Paladin AI

| Aspect | ErrorLearning (JMake) | Paladin AI |
|--------|---------------------|------------|
| **Speed** | Milliseconds | Seconds (LLM inference) |
| **Scope** | Build errors only | General purpose |
| **Learning** | Automatic, local | Manual tool creation |
| **Dependencies** | Julia only | Python, Ollama, network |
| **Integration** | Native to JMake | External agent |
| **Best for** | Compilation feedback loop | High-level project tasks |

## Future Enhancements

1. **Export/Import Knowledge**
   ```julia
   # Export learned patterns
   export_knowledge(db, "jmake_patterns.json")

   # Import community patterns
   import_knowledge(db, "community_patterns.json")
   ```

2. **Project-Specific Learning**
   - Per-project error databases
   - Share patterns across team

3. **Multi-Language Support**
   - Rust, Go, C, Fortran error patterns
   - Language-specific fix strategies

4. **Visual Dashboard**
   - Web UI to browse error patterns
   - Confidence score visualization
   - Success rate analytics

## Troubleshooting

### EngineT Not Loading

```
⚠️  ErrorLearning: EngineT not available - falling back to exact string matching
```

**Solution:**
```bash
cd /home/grim/.julia/julia/EngineT
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Database Lock Errors

```
Error: database is locked
```

**Solution:**
- Use per-project databases: `error_db = ".jmake_errors.db"`
- Or wait for other JMake processes to complete

### Low Confidence Scores

If fixes aren't being auto-applied:
1. Lower `confidence_threshold` in jmake.toml (try 0.6)
2. Bootstrap with `julia scripts/bootstrap_error_db.jl`
3. Manually record successful fixes to build confidence

## Contributing

### Add Your Error Patterns

```julia
using JMake.BuildBridge

db = get_error_db()

# Add your learned patterns
record_fix(
    db,
    "your error message",
    "your fix action",
    true,  # success
    fix_type = "your_category",
    fix_description = "Human-readable description"
)
```

### Share Knowledge

Export and contribute:
```bash
julia -e 'using JMake.BuildBridge; export_knowledge(get_error_db(), "my_patterns.json")'
```

---

**Built with ❤️ by the JMake team**
