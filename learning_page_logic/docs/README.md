# 🎓 Voice-Enabled Study Assistant

An AI-powered study companion with realistic text-to-speech, context-aware learning, and emotional voice expression.

## ✨ Features

- **🧠 Context Learning**: AI reads and learns your entire notebook when you open it
- **🎙️ Realistic Voice**: Fish Audio TTS with emotional expression
- **💬 Smart Conversations**: Remembers conversation history
- **📚 Multi-Notebook Support**: Separate assistants for each subject
- **🎭 Emotional Expression**: Uses tags like (calm), (excited), (encouraging) for natural speech
- **🔄 Real-time Streaming**: See text and hear voice simultaneously
- **🔊 Voice Toggle**: Switch between voice and text-only modes

## 🚀 Quick Start

### Fastest Way (One Command)

```bash
cd /Users/haoming/Desktop/calhacks
./start.sh
```

Then open: **http://localhost:8000**

### Manual Start

```bash
# Terminal 1 - Backend
PORT=5001 python3 voice_server.py

# Terminal 2 - Frontend
python3 -m http.server 8000
```

Then open: **http://localhost:8000**

## 📋 Prerequisites

```bash
pip3 install -r requirements.txt
```

Requirements:
- Python 3.8+
- Flask, Flask-CORS
- Anthropic SDK
- Fish Audio SDK

## 🎯 How to Use

### 1. Dashboard
- View all your notebooks
- General study assistant available
- Click any notebook to dive in

### 2. Inside a Notebook
1. Wait for: *"Just a moment, I'm reading through your notes..."*
2. Then: *"Hi! I've learned all about [Topic]..."*
3. Ask questions about the content
4. Hear realistic voice responses
5. Toggle voice with 🔊/🔇 button

### 3. Example Questions

**Ancient Egypt:**
- "What were the main periods?"
- "Tell me about pyramid construction"
- "How did the Nile flood cycle work?"

**Algorithm Asymptotics:**
- "What is Big O notation?"
- "Explain time complexity"
- "Compare O(n) and O(n²)"

## 🎭 Voice Features

### Emotional Tags (Fish API)

The AI uses special tags to make voice sound natural:

**Introductions:**
- `(welcoming)` - Warm greeting
- `(enthusiastic)` - Energetic start
- `(friendly)` - Building rapport

**Explanations:**
- `(calm)` - Clear teaching
- `(patient)` - Complex topics
- `(clear)` - Emphasis on clarity

**Encouragement:**
- `(proud)` - Student progress
- `(delighted)` - Success moments
- `(impressed)` - Good insights

### What You See vs. What Fish Hears

```
AI Generates: "(welcoming) Hi! (enthusiastic) I've learned all about Ancient Egypt!"
Fish Hears:   (welcoming) Hi! (enthusiastic) I've learned all about Ancient Egypt!
You See:      Hi! I've learned all about Ancient Egypt!
```

Tags are stripped from display but sent to Fish API for expressive voice!

## 🏗️ Architecture

```
┌──────────┐
│ Browser  │
│(Frontend)│
└────┬─────┘
     │ HTTP POST /api/ask
     ▼
┌─────────────┐
│Voice Server │
│  (Flask)    │
└─┬─────────┬─┘
  │         │
  ▼         ▼
┌────────┐ ┌──────┐
│Claude  │ │Fish  │
│  API   │ │ TTS  │
└────────┘ └──────┘
```

## 📁 Project Structure

```
calhacks/
├── voice_server.py         # Backend with Fish TTS integration
├── start.sh                # Startup script
├── stop.sh                 # Shutdown script
├── requirements.txt        # Python dependencies
├── config.json            # API keys
├── js/
│   ├── voice-service.js   # Audio streaming & playback
│   ├── note-assistant-voice.js  # Voice-enabled assistant
│   ├── dashboard.js       # Dashboard assistant
│   └── claude-service.js  # Fallback direct API
├── notes/
│   ├── ancient-egypt.html # Example notebook
│   └── asymptotics.html   # Example notebook
├── css/
│   ├── notebook-style.css # Notebook styling
│   └── dashboard.css      # Dashboard styling
└── docs/
    ├── QUICK_START.md     # Quick start guide
    └── VOICE_SETUP.md     # Full documentation
```

## 🔧 Configuration

### Ports

- **Backend**: 5001 (default, configurable via `PORT` env var)
- **Frontend**: 8000

**Note for macOS users**: Port 5000 is often used by AirPlay Receiver. We use 5001 by default.

### API Keys

Already configured in:
- `voice_server.py` - Claude & Fish API keys
- `config.json` - Claude API key (fallback)

### Backend Auto-Detection

Frontend automatically tries:
1. http://localhost:5001 ✅
2. http://localhost:5000
3. http://127.0.0.1:5001
4. http://127.0.0.1:5000

## 🛑 Stopping Servers

```bash
./stop.sh
```

Or press `Ctrl+C` if you used `./start.sh`

## 📝 API Endpoints

### POST /api/ask
Streams response with voice output

**Request:**
```json
{
  "question": "What are pyramids?",
  "context": "System context/notebook content",
  "history": [...]
}
```

**Response:** Server-Sent Events
```
{"type": "text", "content": "..."}
{"type": "audio", "content": "base64audio"}
{"type": "done"}
```

### POST /api/ask-text-only
Text-only (faster, no voice)

### GET /health
Backend status check

## 🐛 Troubleshooting

### Port Already in Use

```bash
# macOS: Disable AirPlay Receiver in System Settings
# Or use different port:
PORT=5002 python3 voice_server.py
```

### No Voice?

1. Click page first (browser audio policy)
2. Check 🔊 button is on (not 🔇)
3. Verify backend running: `curl http://localhost:5001/health`
4. Check browser console for errors

### Can't Connect?

1. Verify both servers running
2. Check ports: `lsof -i:5001` and `lsof -i:8000`
3. Try different port: `PORT=5002 python3 voice_server.py`

### Slow Responses?

1. Toggle voice off (🔇) for text-only
2. Check internet connection
3. Verify API quotas

## 📚 Documentation

- **QUICK_START.md** - Get started in minutes
- **VOICE_SETUP.md** - Complete technical guide

## 🎉 Ready!

Your voice-enabled study assistant is ready. Run `./start.sh` and start learning!

---

Made with Claude Code & Fish Audio 🚀
