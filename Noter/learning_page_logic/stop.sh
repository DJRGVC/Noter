#!/bin/bash

# Stop Voice-Enabled Study Assistant Servers

echo "🛑 Stopping Voice-Enabled Study Assistant"
echo "========================================"

# Read PIDs from files if they exist
if [ -f logs/backend.pid ]; then
    BACKEND_PID=$(cat logs/backend.pid)
    echo "Stopping backend (PID: $BACKEND_PID)..."
    kill $BACKEND_PID 2>/dev/null
    rm -f logs/backend.pid
fi

if [ -f logs/frontend.pid ]; then
    FRONTEND_PID=$(cat logs/frontend.pid)
    echo "Stopping frontend (PID: $FRONTEND_PID)..."
    kill $FRONTEND_PID 2>/dev/null
    rm -f logs/frontend.pid
fi

# Also kill any processes on the ports
echo "Cleaning up ports 5001 and 8000..."
lsof -ti:5001 | xargs kill -9 2>/dev/null
lsof -ti:5000 | xargs kill -9 2>/dev/null
lsof -ti:8000 | xargs kill -9 2>/dev/null

echo "✅ Servers stopped"
echo ""
