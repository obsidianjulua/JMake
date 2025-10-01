# JMake ErrorLearning Database Strategy

## Database Files

### Primary Database: `jmake_errors.db`

**Location**: Project root (gitignored)
**Purpose**: Stores learned error patterns and fixes
**Lifecycle**: Created on first use, persists across sessions

This is the main knowledge base that improves over time as you build projects.

### Database Options

You can configure the database location in `jmake.toml`:

```toml
[learning]
error_db = "jmake_errors.db"  # Default: project-local
# OR
error_db = "~/.jmake/global_errors.db"  # Global: shared across all projects
```

## Database Strategies

### 1. **Project-Local** (Default)

```toml
[learning]
error_db = "jmake_errors.db"
```

**Pros:**
- Project-specific error patterns
- Isolated learning per project
- Easy to delete/reset
- No cross-project pollution

**Cons:**
- Doesn't share knowledge across projects
- Each project starts fresh

**Best for:** Individual projects with unique build configurations

---

### 2. **Global Database**

```toml
[learning]
error_db = "~/.jmake/global_errors.db"
```

**Pros:**
- Shared knowledge across all projects
- Faster learning (benefits from all builds)
- Collaborative patterns
- One database to maintain

**Cons:**
- Potential for irrelevant patterns
- Larger database size
- Requires manual management

**Best for:** Users working on many similar C++ projects

---

### 3. **Hybrid Approach**

```toml
[learning]
error_db = "jmake_errors.db"
share_knowledge = true
```

With `share_knowledge = true`:
- Maintains local database
- Periodically syncs with global database
- Can import/export patterns

---

## Database Management

### Bootstrap Common Patterns

```bash
julia scripts/bootstrap_error_db.jl
```

Loads ~50 common C++/LLVM error patterns to jumpstart learning.

### Export Knowledge

```julia
using JMake.BuildBridge

db = get_error_db()
export_knowledge(db, "my_error_patterns.json")
```

Share learned patterns with team or community.

### Import Knowledge

```julia
# Future feature - import patterns from JSON
import_knowledge(db, "community_patterns.json")
```

### Reset Database

```bash
rm jmake_errors.db
julia scripts/bootstrap_error_db.jl
```

Starts fresh with only common patterns.

### Database Statistics

```bash
sqlite3 jmake_errors.db "SELECT error_category, COUNT(*) FROM error_patterns GROUP BY error_category"
```

See what types of errors you've encountered.

---

## Database Schema

### Tables

1. **error_patterns** - Unique error signatures
   - `id`, `error_text`, `error_type`, `error_category`
   - `embedding` (BLOB), `occurrence_count`
   - `created_at`, `last_seen`

2. **error_fixes** - Solutions for errors
   - `id`, `error_id`, `fix_type`, `fix_action`
   - `success_count`, `failure_count`, `confidence`

3. **fix_history** - Audit trail
   - `id`, `error_id`, `fix_id`, `applied_at`
   - `success`, `project_path`, `error_context`

### Indices

- `idx_error_category` - Fast category lookup
- `idx_error_type` - Fast type filtering

---

## Best Practices

### For Individual Developers

✅ Use **project-local** databases
✅ Bootstrap on first use
✅ Let the system learn naturally
❌ Don't manually edit database

### For Teams

✅ Use **global database** on CI/CD servers
✅ Export patterns weekly
✅ Share `error_patterns.json` in team repo
✅ Import team patterns on dev machines

### For Library Maintainers

✅ Export well-tested patterns
✅ Publish as package artifacts
✅ Version control pattern exports
✅ Document fix strategies

---

## Database Size

| Patterns | Size | Performance |
|----------|------|-------------|
| 10 (bootstrap) | 32 KB | Instant |
| 100 (typical project) | ~100 KB | <1ms search |
| 1,000 (large project) | ~1 MB | <5ms search |
| 10,000 (enterprise) | ~10 MB | <50ms search |

Even with 10,000 patterns, search remains fast due to:
- SQLite indices
- Category filtering
- Similarity threshold pruning

---

## Cleanup

### Automatic (Test Databases)

Test databases use temp directories and auto-cleanup:

```julia
const TEST_DB = joinpath(tempdir(), "jmake_test_$(timestamp).db")
```

### Manual (Old Databases)

```bash
# Find old test databases
find . -name "test_error_learning_*.db" -mtime +7 -delete

# Clean exports
rm -f test_export_*.json
```

### .gitignore

All database files are gitignored by default:

```gitignore
*.db
test_error_learning_*.db
jmake_errors.db
```

**Exception**: You may want to commit a bootstrapped database for CI/CD:

```bash
# Create and commit a starter database
julia scripts/bootstrap_error_db.jl
git add -f jmake_errors_bootstrap.db
git commit -m "Add bootstrapped error patterns"
```

---

## Troubleshooting

### Database Locked

**Error**: `SQLite: database is locked`

**Solutions:**
1. Wait for other JMake processes to finish
2. Use per-project databases instead of global
3. Close database connections properly

### Database Corrupted

**Error**: `SQLite: malformed database`

**Solutions:**
```bash
# Backup corrupted DB
mv jmake_errors.db jmake_errors.db.bad

# Start fresh
julia scripts/bootstrap_error_db.jl

# Try to recover data (advanced)
sqlite3 jmake_errors.db.bad ".recover" | sqlite3 jmake_errors_recovered.db
```

### Too Many Patterns

If database becomes unwieldy (>10,000 patterns):

```sql
-- Delete old, rarely-used patterns
DELETE FROM error_patterns
WHERE occurrence_count < 2
  AND created_at < date('now', '-30 days');

-- Vacuum to reclaim space
VACUUM;
```

---

## Future Enhancements

- [ ] Automatic database merging
- [ ] Pattern confidence decay over time
- [ ] Export to package artifacts
- [ ] Import from community repositories
- [ ] Database compaction/cleanup tools
- [ ] Web UI for pattern browsing

---

**Recommendation**: Start with project-local databases, export successful patterns, and share with team as JSON files.
