#!/bin/bash
# status.sh - Check status of all JMake daemon servers

JMAKE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$JMAKE_ROOT/daemons/logs"

echo "======================================================================="
echo "JMake Daemon System Status"
echo "======================================================================="

if [ ! -d "$LOG_DIR" ]; then
    echo "No daemon logs directory found. Daemons are not running."
    exit 0
fi

running=0
stopped=0

for pid_file in "$LOG_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        daemon_name=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file")

        if kill -0 $pid 2>/dev/null; then
            echo "✓ $daemon_name (PID: $pid) - RUNNING"
            ((running++))
        else
            echo "✗ $daemon_name - STOPPED (stale PID: $pid)"
            ((stopped++))
            rm "$pid_file"  # Clean up stale PID
        fi
    fi
done

if [ $running -eq 0 ] && [ $stopped -eq 0 ]; then
    echo "No daemons found."
fi

echo ""
echo "Running: $running"
echo "Stopped: $stopped"
echo "======================================================================="
