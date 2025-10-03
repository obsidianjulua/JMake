#!/bin/bash
# Stop all JMake daemon servers

echo "Stopping JMake Daemon Servers..."
echo "================================"

# Read and kill discovery daemon
if [ -f .daemon_pids.discovery ]; then
    DISCOVERY_PID=$(cat .daemon_pids.discovery)
    if ps -p $DISCOVERY_PID > /dev/null 2>&1; then
        echo "Stopping Discovery Daemon (PID $DISCOVERY_PID)..."
        kill $DISCOVERY_PID
    else
        echo "Discovery Daemon not running"
    fi
    rm .daemon_pids.discovery
fi

# Read and kill setup daemon
if [ -f .daemon_pids.setup ]; then
    SETUP_PID=$(cat .daemon_pids.setup)
    if ps -p $SETUP_PID > /dev/null 2>&1; then
        echo "Stopping Setup Daemon (PID $SETUP_PID)..."
        kill $SETUP_PID
    else
        echo "Setup Daemon not running"
    fi
    rm .daemon_pids.setup
fi

# Read and kill compilation daemon
if [ -f .daemon_pids.compilation ]; then
    COMPILE_PID=$(cat .daemon_pids.compilation)
    if ps -p $COMPILE_PID > /dev/null 2>&1; then
        echo "Stopping Compilation Daemon (PID $COMPILE_PID)..."
        kill $COMPILE_PID
    else
        echo "Compilation Daemon not running"
    fi
    rm .daemon_pids.compilation
fi

# Read and kill orchestrator daemon
if [ -f .daemon_pids.orchestrator ]; then
    ORCHESTRATOR_PID=$(cat .daemon_pids.orchestrator)
    if ps -p $ORCHESTRATOR_PID > /dev/null 2>&1; then
        echo "Stopping Orchestrator Daemon (PID $ORCHESTRATOR_PID)..."
        kill $ORCHESTRATOR_PID
    else
        echo "Orchestrator Daemon not running"
    fi
    rm .daemon_pids.orchestrator
fi

echo ""
echo "All daemons stopped!"
