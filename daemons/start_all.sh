#!/bin/bash
# start_all.sh - Start all JMake daemon servers

JMAKE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAEMON_DIR="$JMAKE_ROOT/daemons/servers"
LOG_DIR="$JMAKE_ROOT/daemons/logs"

# Create log directory
mkdir -p "$LOG_DIR"

echo "======================================================================="
echo "Starting JMake Daemon System"
echo "======================================================================="
echo "JMake Root: $JMAKE_ROOT"
echo "Daemon Dir: $DAEMON_DIR"
echo "Log Dir:    $LOG_DIR"
echo ""

# Array of daemons with their ports
declare -A DAEMONS
DAEMONS=(
    ["discovery_daemon.jl"]="3001"
    ["setup_daemon.jl"]="3002"
    ["compilation_daemon.jl"]="3003"
    ["orchestrator_daemon.jl"]="3004"
)

# Start each daemon
for daemon in "${!DAEMONS[@]}"; do
    port="${DAEMONS[$daemon]}"
    daemon_path="$DAEMON_DIR/$daemon"
    log_file="$LOG_DIR/${daemon%.jl}.log"
    pid_file="$LOG_DIR/${daemon%.jl}.pid"

    echo "Starting $daemon on port $port..."

    # Start daemon in background
    julia --project="$JMAKE_ROOT" "$daemon_path" > "$log_file" 2>&1 &
    daemon_pid=$!

    # Save PID
    echo $daemon_pid > "$pid_file"

    # Wait a moment and check if still running
    sleep 1
    if kill -0 $daemon_pid 2>/dev/null; then
        echo "  ✓ Started (PID: $daemon_pid)"
    else
        echo "  ✗ Failed to start (check $log_file)"
    fi
done

echo ""
echo "======================================================================="
echo "Daemon System Started"
echo "======================================================================="
echo "Check logs in: $LOG_DIR"
echo "Stop all daemons: ./stop_all.sh"
echo "Check status: ./status.sh"
