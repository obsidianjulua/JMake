#!/bin/bash
# Start all JMake daemon servers

echo "Starting JMake Daemon Servers..."
echo "================================"

# Start discovery daemon
echo "Starting Discovery Daemon (port 3001)..."
julia --project=.. servers/discovery_daemon.jl &
DISCOVERY_PID=$!
echo "  PID: $DISCOVERY_PID"

sleep 2

# Start setup daemon
echo "Starting Setup Daemon (port 3002)..."
julia --project=.. servers/setup_daemon.jl &
SETUP_PID=$!
echo "  PID: $SETUP_PID"

sleep 2

# Start compilation daemon (with 4 workers)
echo "Starting Compilation Daemon (port 3003, 4 workers)..."
julia --project=.. -p 4 servers/compilation_daemon.jl &
COMPILE_PID=$!
echo "  PID: $COMPILE_PID"

sleep 3

# Start orchestrator daemon
echo "Starting Orchestrator Daemon (port 3004)..."
julia --project=.. servers/orchestrator_daemon.jl &
ORCHESTRATOR_PID=$!
echo "  PID: $ORCHESTRATOR_PID"

sleep 2

# Start error handler daemon (old port 3002, now shared with setup)
# echo "Starting Error Handler Daemon..."
# julia --project=.. servers/error_handler_daemon.jl &
# ERROR_PID=$!

# Start watcher daemon (old port 3003, now shared with compilation)
# echo "Starting Watcher Daemon..."
# julia --project=.. servers/watcher_daemon.jl &
# WATCHER_PID=$!

echo ""
echo "All daemons started!"
echo "================================"
echo "Discovery Daemon:     PID $DISCOVERY_PID (port 3001)"
echo "Setup Daemon:         PID $SETUP_PID (port 3002)"
echo "Compilation Daemon:   PID $COMPILE_PID (port 3003, 4 workers)"
echo "Orchestrator Daemon:  PID $ORCHESTRATOR_PID (port 3004)"
echo ""
echo "To stop all daemons, run: ./stop_all.sh"
echo "To check status, run: ./status.sh"

# Save PIDs to file
echo $DISCOVERY_PID > .daemon_pids.discovery
echo $SETUP_PID > .daemon_pids.setup
echo $COMPILE_PID > .daemon_pids.compilation
echo $ORCHESTRATOR_PID > .daemon_pids.orchestrator
