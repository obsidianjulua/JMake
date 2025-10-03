#!/bin/bash
# stop_all.sh - Stop all JMake daemon servers

JMAKE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$JMAKE_ROOT/daemons/logs"

echo "======================================================================="
echo "Stopping JMake Daemon System"
echo "======================================================================="

if [ ! -d "$LOG_DIR" ]; then
    echo "No daemon logs directory found. Daemons may not be running."
    exit 0
fi

# Stop all daemons
for pid_file in "$LOG_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        daemon_name=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file")

        echo "Stopping $daemon_name (PID: $pid)..."

        if kill -0 $pid 2>/dev/null; then
            kill $pid
            sleep 0.5

            # Force kill if still running
            if kill -0 $pid 2>/dev/null; then
                echo "  Force killing..."
                kill -9 $pid
            fi

            echo "  ✓ Stopped"
        else
            echo "  Already stopped"
        fi

        # Remove PID file
        rm "$pid_file"
    fi
done

echo ""
echo "======================================================================="
echo "All Daemons Stopped"
echo "======================================================================="
