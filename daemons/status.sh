#!/bin/bash
# Check status of JMake daemon servers

echo "JMake Daemon Status"
echo "================================"

check_daemon() {
    name=$1
    pid_file=$2
    port=$3

    if [ -f $pid_file ]; then
        PID=$(cat $pid_file)
        if ps -p $PID > /dev/null 2>&1; then
            echo "✓ $name: RUNNING (PID $PID, port $port)"
            return 0
        else
            echo "✗ $name: STOPPED (stale PID file)"
            return 1
        fi
    else
        echo "✗ $name: STOPPED"
        return 1
    fi
}

# Check each daemon
check_daemon "Discovery Daemon   " ".daemon_pids.discovery" "3001"
check_daemon "Setup Daemon       " ".daemon_pids.setup" "3002"
check_daemon "Compilation Daemon " ".daemon_pids.compilation" "3003"
check_daemon "Orchestrator Daemon" ".daemon_pids.orchestrator" "3004"

echo ""
echo "To start all daemons: ./start_all.sh"
echo "To stop all daemons:  ./stop_all.sh"
