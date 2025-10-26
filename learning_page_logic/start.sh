#!/bin/bash

# Start the StudyHub backend server

echo "🚀 Starting StudyHub Backend Server..."
echo ""
echo "📦 Checking Python dependencies..."

# Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

# Install requirements if needed
if [ -f "requirements.txt" ]; then
    echo "Installing/updating Python packages..."
    python3 -m pip install -r requirements.txt --quiet
fi

echo ""
echo "✅ Dependencies ready!"
echo ""
echo "🌐 Starting server on http://localhost:5001"
echo "📝 Press Ctrl+C to stop the server"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Start the backend server
python3 backend_server.py
