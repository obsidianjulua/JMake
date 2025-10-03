# Daemon Lifecycle & Management

## 🔄 Daemon Lifecycle

### Current Behavior

**Daemons run indefinitely** until explicitly stopped. They do NOT automatically exit.

```
[Start] → [Running] → [Manual Stop] → [Exit]
    ↓         ↑
    └─────────┘ (persistent, serves unlimited requests)
```

### Starting Daemons

```bash
cd daemons
./start_all.sh

# Daemons start in background and stay running
# PIDs saved to .daemon_pids.* files
```

**What Happens**:
1. Each daemon starts as background process (`&`)
2. PID saved to `.daemon_pids.<name>` file
3. Daemon enters `serve(port)` loop - **runs forever**
4. Shell script exits, daemons continue running

### Stopping Daemons

**Manual Stop** (recommended):
```bash
./stop_all.sh

# Gracefully kills each daemon
# Removes PID files
```

**Individual Stop**:
```bash
# Stop specific daemon
kill $(cat .daemon_pids.discovery)
rm .daemon_pids.discovery
```

**Force Kill** (if hung):
```bash
# Kill all Julia processes (nuclear option)
killall julia

# Or by port
lsof -ti:3001 | xargs kill
```

### Status Checking

```bash
./status.sh

# Output:
# ✓ Discovery Daemon   : RUNNING (PID 9053, port 3001)
# ✓ Setup Daemon       : RUNNING (PID 9063, port 3002)
# ✓ Compilation Daemon : RUNNING (PID 9075, port 3003)
# ✓ Orchestrator Daemon: RUNNING (PID 9100, port 3004)
```

---

## 🛡️ Graceful Shutdown (Improved)

### Current Issue

Daemons use `DaemonMode.serve(port)` which runs indefinitely:

```julia
# Current implementation
function main()
    println("Starting daemon...")
    serve(PORT)  # Blocks forever
end
```

**Problem**: No cleanup on exit (caches, temp files, etc.)

### Solution: Add Signal Handling

Update each daemon with graceful shutdown:

```julia
# Improved daemon template
const SHOULD_EXIT = Ref(false)

function main()
    println("Starting daemon on port $PORT")

    # Register cleanup handler
    atexit() do
        println("[SHUTDOWN] Cleaning up...")
        cleanup()
    end

    # Start serving
    println("Ready to accept requests...")
    serve(PORT)

    println("[EXIT] Daemon stopped")
end

function cleanup()
    # Save caches to disk
    save_cache_to_disk()

    # Log statistics
    println("[STATS] Served $(REQUEST_COUNT[]) requests")
    println("[STATS] Cache hits: $(CACHE_HITS[])")

    # Close any open connections
    # (DaemonMode handles this internally)
end
```

### Implementing Graceful Shutdown

**Add to each daemon** (`discovery_daemon.jl`, `setup_daemon.jl`, etc.):

```julia
# At top of file
const REQUEST_COUNT = Ref(0)
const CACHE_HITS = Ref(0)
const CACHE_MISSES = Ref(0)

# Track requests
function handle_request(func, args)
    REQUEST_COUNT[] += 1

    # Call actual function
    result = func(args)

    # Track cache hits
    if haskey(result, :cached) && result[:cached]
        CACHE_HITS[] += 1
    else
        CACHE_MISSES[] += 1
    end

    return result
end

# Cleanup on exit
atexit() do
    println("\n[SHUTDOWN] $(basename(@__FILE__))")
    println("  Requests served: $(REQUEST_COUNT[])")
    println("  Cache hit rate: $(round(100 * CACHE_HITS[] / max(1, REQUEST_COUNT[]), digits=1))%")

    # Optional: persist caches
    if PERSIST_CACHE
        println("  Saving caches to disk...")
        save_caches()
    end

    println("  Goodbye! 👋")
end
```

---

## 💾 Cache Persistence

### Current: In-Memory Only

Caches are **lost on daemon restart**:

```julia
const TOOL_CACHE = Dict{String, String}()  # Lost on exit!
```

### Improvement: Optional Disk Persistence

```julia
const CACHE_DIR = ".jmake_daemon_cache"
const CACHE_FILE = joinpath(CACHE_DIR, "discovery_cache.jls")

# Load cache on startup
function init_cache()
    if isfile(CACHE_FILE)
        try
            cache_data = deserialize(CACHE_FILE)
            merge!(TOOL_CACHE, cache_data["tools"])
            merge!(AST_CACHE, cache_data["ast"])
            println("[CACHE] Loaded from disk: $(length(TOOL_CACHE)) tools")
        catch e
            @warn "Failed to load cache: $e"
        end
    end
end

# Save cache on shutdown
function save_caches()
    mkpath(CACHE_DIR)
    cache_data = Dict(
        "tools" => TOOL_CACHE,
        "ast" => AST_CACHE,
        "timestamp" => now()
    )
    serialize(CACHE_FILE, cache_data)
    println("[CACHE] Saved to disk")
end

# In main()
atexit() do
    save_caches()
end
```

---

## 🔧 Daemon Restart Strategies

### 1. Quick Restart (Preserve Caches)

**Use Case**: Daemon crashed, want to resume quickly

```bash
# With cache persistence enabled
./stop_all.sh
./start_all.sh

# Caches loaded from disk
# [CACHE] Loaded from disk: 137 tools
# [CACHE] Loaded from disk: 15 AST graphs
```

### 2. Clean Restart (Clear Caches)

**Use Case**: Debugging, cache corruption, config changes

```bash
# Stop daemons
./stop_all.sh

# Clear cache files
rm -rf .jmake_daemon_cache/

# Restart
./start_all.sh

# Fresh start, rebuild caches
```

### 3. Rolling Restart (Zero Downtime)

**Use Case**: Production updates without stopping builds

```bash
# Start new daemons on different ports
PORT_OFFSET=1000 ./start_all.sh

# New daemons on 4001, 4002, 4003, 4004

# Update client to use new ports
# Stop old daemons
./stop_all.sh

# Move new daemons to standard ports
# (requires port remapping)
```

---

## 🚦 Auto-Restart on Failure

### Systemd Service (Linux)

Create `/etc/systemd/system/jmake-daemons.service`:

```ini
[Unit]
Description=JMake Build Daemons
After=network.target

[Service]
Type=forking
User=grim
WorkingDirectory=/home/grim/.julia/julia/JMake/daemons
ExecStart=/home/grim/.julia/julia/JMake/daemons/start_all.sh
ExecStop=/home/grim/.julia/julia/JMake/daemons/stop_all.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Enable**:
```bash
sudo systemctl enable jmake-daemons
sudo systemctl start jmake-daemons
sudo systemctl status jmake-daemons
```

### Supervisor (Cross-Platform)

Install supervisor: `pip install supervisor`

`/etc/supervisor/conf.d/jmake-daemons.conf`:

```ini
[program:jmake-discovery]
command=julia --project=/home/grim/.julia/julia/JMake /home/grim/.julia/julia/JMake/daemons/servers/discovery_daemon.jl
directory=/home/grim/.julia/julia/JMake/daemons
autostart=true
autorestart=true
user=grim

[program:jmake-setup]
command=julia --project=/home/grim/.julia/julia/JMake /home/grim/.julia/julia/JMake/daemons/servers/setup_daemon.jl
directory=/home/grim/.julia/julia/JMake/daemons
autostart=true
autorestart=true
user=grim

[program:jmake-compilation]
command=julia --project=/home/grim/.julia/julia/JMake -p 4 /home/grim/.julia/julia/JMake/daemons/servers/compilation_daemon.jl
directory=/home/grim/.julia/julia/JMake/daemons
autostart=true
autorestart=true
user=grim

[program:jmake-orchestrator]
command=julia --project=/home/grim/.julia/julia/JMake /home/grim/.julia/julia/JMake/daemons/servers/orchestrator_daemon.jl
directory=/home/grim/.julia/julia/JMake/daemons
autostart=true
autorestart=true
user=grim
```

**Start**:
```bash
supervisorctl reread
supervisorctl update
supervisorctl status
```

---

## 📊 Monitoring & Health Checks

### Health Check Script

`health_check.sh`:

```bash
#!/bin/bash
# Check daemon health and auto-restart if needed

check_and_restart() {
    daemon=$1
    port=$2
    pid_file=".daemon_pids.$daemon"

    # Check if process exists
    if [ -f $pid_file ]; then
        pid=$(cat $pid_file)
        if ! ps -p $pid > /dev/null 2>&1; then
            echo "⚠️  $daemon daemon (port $port) is down, restarting..."
            # Restart individual daemon
            case $daemon in
                discovery)
                    julia --project=.. servers/discovery_daemon.jl &
                    echo $! > $pid_file
                    ;;
                setup)
                    julia --project=.. servers/setup_daemon.jl &
                    echo $! > $pid_file
                    ;;
                compilation)
                    julia --project=.. -p 4 servers/compilation_daemon.jl &
                    echo $! > $pid_file
                    ;;
                orchestrator)
                    julia --project=.. servers/orchestrator_daemon.jl &
                    echo $! > $pid_file
                    ;;
            esac
            echo "✅ $daemon restarted"
        fi
    else
        echo "❌ $daemon daemon not running (no PID file)"
    fi
}

# Check all daemons
check_and_restart discovery 3001
check_and_restart setup 3002
check_and_restart compilation 3003
check_and_restart orchestrator 3004
```

**Cron Job** (check every 5 minutes):
```bash
*/5 * * * * cd /home/grim/.julia/julia/JMake/daemons && ./health_check.sh
```

### Metrics Collection

Add to each daemon:

```julia
# Metrics
const METRICS = Dict(
    "start_time" => now(),
    "requests" => 0,
    "cache_hits" => 0,
    "cache_misses" => 0,
    "errors" => 0
)

# Expose metrics endpoint
function get_metrics(args::Dict)
    uptime = now() - METRICS["start_time"]

    return Dict(
        :success => true,
        :metrics => merge(METRICS, Dict(
            "uptime_seconds" => uptime.value / 1000,
            "cache_hit_rate" => METRICS["cache_hits"] / max(1, METRICS["requests"]),
            "error_rate" => METRICS["errors"] / max(1, METRICS["requests"])
        ))
    )
end
```

---

## 🔥 Hot Reload (Advanced)

### Reload Without Restart

**Use Case**: Update daemon code without losing cache

```julia
# Add to each daemon
function reload_code(args::Dict)
    println("[RELOAD] Reloading daemon code...")

    try
        # Re-include source files
        include("discovery_daemon.jl")

        println("[RELOAD] ✅ Code reloaded successfully")
        return Dict(:success => true)
    catch e
        println("[RELOAD] ❌ Failed: $e")
        return Dict(:success => false, :error => string(e))
    end
end
```

**Invoke**:
```julia
using DaemonMode
runexpr("reload_code(Dict())", port=3001)
```

---

## 📝 Summary

| Aspect | Current | Recommended |
|--------|---------|-------------|
| **Startup** | Manual (`./start_all.sh`) | Systemd/Supervisor auto-start |
| **Shutdown** | Manual (`./stop_all.sh`) | Graceful with `atexit()` cleanup |
| **Cache** | In-memory (lost on restart) | Persist to disk with serialization |
| **Monitoring** | Manual (`./status.sh`) | Health checks + auto-restart |
| **Restart** | Full stop/start | Rolling restart for zero downtime |
| **Hot Reload** | Not supported | Add `reload_code()` function |

**Best Practice**:
- Use systemd/supervisor for production
- Enable cache persistence for faster restarts
- Add health checks with auto-restart
- Implement graceful shutdown with metrics logging

**Current Answer to Your Question**:
> Daemons currently **run indefinitely** until manually stopped (`./stop_all.sh` or `kill <PID>`). They do NOT exit gracefully on their own. Adding `atexit()` handlers would enable graceful cleanup.
