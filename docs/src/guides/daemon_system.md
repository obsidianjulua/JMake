# Daemon System

High-performance background build system with job queue architecture.

## Overview

JMake's daemon system provides:

- **Background compilation**: Non-blocking builds
- **Job queue**: Manage multiple build tasks
- **File watching**: Automatic recompilation on changes
- **Error handling**: Persistent error tracking and recovery

## Architecture

The daemon system consists of:

- **Orchestrator Daemon**: Coordinates all other daemons
- **Discovery Daemon**: Monitors project structure changes
- **Compilation Daemon**: Handles compilation tasks
- **Build Daemon**: Manages build artifacts
- **Error Handler Daemon**: Processes compilation errors
- **Watcher Daemon**: Monitors file system changes

## Starting the Daemon System

```bash
cd daemons
./start_all.sh
```

Or programmatically:

```julia
using JMake

# Start daemon system
include("daemons/servers/orchestrator_daemon.jl")
```

## Job Queue

### Submitting Jobs

Jobs are defined in TOML format:

```toml
[[jobs]]
id = "compile_project"
type = "compilation"
priority = 1
config_file = "jmake.toml"

[[jobs]]
id = "wrap_binary"
type = "wrapping"
priority = 2
binary_path = "/usr/lib/libssl.so"
```

### Job Types

- `compilation`: Compile C++ source to Julia
- `wrapping`: Generate binary wrappers
- `discovery`: Scan project structure
- `error_analysis`: Analyze compilation errors

### Job Priorities

- Priority 0: Highest priority
- Priority 1-5: Normal tasks
- Priority 6+: Low priority background tasks

## Reactive Build System

### File Watching

The watcher daemon monitors changes:

```julia
# Files are watched automatically
# Edit any source file...
# Daemon automatically recompiles
```

### Configuration

Edit `daemons/job_queue_design.toml`:

```toml
[queue]
max_concurrent_jobs = 4
job_timeout_seconds = 300

[watcher]
watch_patterns = ["**/*.cpp", "**/*.h", "**/*.toml"]
ignore_patterns = ["build/**", "julia/**"]
debounce_ms = 500

[error_handling]
max_retries = 3
retry_delay_seconds = 5
```

## Daemon Management

### Status Check

```bash
./status.sh
```

Output:
```
Orchestrator Daemon: Running (PID 12345)
Discovery Daemon: Running (PID 12346)
Compilation Daemon: Running (PID 12347)
Build Daemon: Running (PID 12348)
Error Handler Daemon: Running (PID 12349)
Watcher Daemon: Running (PID 12350)
```

### Stop All Daemons

```bash
./stop_all.sh
```

### Individual Daemon Control

```julia
# Start specific daemon
include("daemons/servers/compilation_daemon.jl")

# Check daemon status
# Daemon logs to daemon_<type>.log
```

## Job Queue API

### Client Usage

```julia
using JMake

# Submit compilation job
job_id = submit_job(
    type="compilation",
    config_file="jmake.toml",
    priority=1
)

# Check job status
status = get_job_status(job_id)

# Wait for completion
wait_for_job(job_id)

# Get results
results = get_job_results(job_id)
```

### Job Status

Jobs can be in these states:

- `pending`: Waiting in queue
- `running`: Currently executing
- `completed`: Successfully finished
- `failed`: Encountered an error
- `cancelled`: Manually cancelled

## Advanced Features

### Auto-complete Support

The daemon system provides shell auto-completion:

```julia
include("daemons/jmake_auto_complete.jl")

# Generates completions for:
# - Available commands
# - File paths
# - Configuration options
```

### Error Learning Integration

Daemons automatically learn from errors:

```julia
# View accumulated error patterns
include("daemons/servers/error_handler_daemon.jl")

# Export learned errors
export_daemon_errors("daemon_errors.md")
```

### Test Project Integration

Test the daemon system:

```bash
cd daemons/test_project
julia test_daemons.jl
```

## Configuration Files

### Orchestrator Config

```toml
[orchestrator]
max_daemons = 6
health_check_interval = 30
restart_failed_daemons = true

[logging]
log_level = "info"
log_file = "orchestrator.log"
```

### Compilation Daemon Config

```toml
[compilation]
max_parallel_builds = 4
build_timeout = 600
cache_enabled = true
cache_dir = ".bridge_cache"

[llvm]
use_bundled = false
toolchain_path = "/usr/lib/llvm-17"
```

## Monitoring and Debugging

### Log Files

Each daemon writes to its own log:

- `orchestrator.log`: Main coordination log
- `compilation.log`: Compilation events
- `discovery.log`: Project scanning events
- `error_handler.log`: Error processing log
- `watcher.log`: File system events

### Debug Mode

Enable verbose logging:

```bash
DEBUG=1 ./start_all.sh
```

## Performance Tuning

### Concurrent Jobs

Adjust based on CPU cores:

```toml
[queue]
max_concurrent_jobs = 8  # Match CPU core count
```

### Build Caching

Enable aggressive caching:

```toml
[compilation]
cache_enabled = true
cache_size_mb = 1024
incremental_builds = true
```

## Best Practices

1. **Resource limits**: Set `max_concurrent_jobs` to avoid overloading
2. **Monitor logs**: Regular check logs for issues
3. **Graceful shutdown**: Use `./stop_all.sh` instead of killing processes
4. **Test daemon health**: Run `./status.sh` regularly
5. **Clean old jobs**: Periodically clear completed jobs from queue
