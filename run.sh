#!/bin/bash

# Navigate to your project directory
cd "$(dirname "$0")"

# Function to gracefully stop the Python server when you exit this script
cleanup() {
    echo -e "\nStopping Python backend and Flutter server..."
    if [ -n "$PYTHON_PID" ]; then
        kill $PYTHON_PID 2>/dev/null
    fi
    exit
}

# Trap Ctrl+C to run the cleanup function
trap cleanup SIGINT EXIT

echo "====================================="
echo "   Starting Neural Note Gen          "
echo "====================================="

# 1. Start the Python Backend in the background
echo "-> Starting Python Backend on port 8000..."
source .venv/bin/activate
python server.py > backend.log 2>&1 &
PYTHON_PID=$!

# Wait briefly to ensure backend is up
sleep 2

# 2. Open the browser (macOS command)
echo "-> Opening browser to http://localhost:8082..."
open "http://localhost:8082"

# 3. Start the Flutter Web Server in the foreground
echo "-> Starting Flutter Web Server on port 8082..."
cd flutter_frontend
flutter run -d web-server --web-port=8082
