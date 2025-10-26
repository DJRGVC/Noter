# Voice-Enabled Study Assistant Setup

This guide will help you set up the voice-enabled study assistant with Fish Audio TTS integration.

## Features

- **Context-Aware AI Assistant**: Learns the content of each notebook when you open it
- **Voice Output**: Realistic TTS using Fish Audio API
- **Emotional Expression**: Fish API tags for natural, expressive voice
  - Emotional tags: `(calm)`, `(confident)`, `(excited)`, `(thoughtful)`, etc.
  - Vocal cues: "um", "ahh", "hmm", "well" for natural speech
- **Streaming**: Real-time text and audio streaming
- **Toggle Voice**: Can switch between voice and text-only modes

## Prerequisites

- Python 3.8 or higher
- Modern web browser (Chrome, Firefox, Safari, Edge)
- Fish Audio API key
- Anthropic Claude API key

## Installation

### 1. Install Python Dependencies

```bash
cd /Users/haoming/Desktop/calhacks
pip install -r requirements.txt
```

### 2. Verify API Keys

The API keys are already configured in:
- `config.json` - Claude API key (for frontend fallback)
- `voice_server.py` - Both Claude and Fish API keys

### 3. Start the Backend Server

**Option 1: Use the startup script (recommended)**
```bash
./start.sh
```

**Option 2: Manual start**
```bash
PORT=5001 python3 voice_server.py
```

**Note for macOS users:** Port 5000 is often used by AirPlay Receiver. Use port 5001 or disable AirPlay in System Settings.

You should see:
```
🎙️  Voice-enabled Study Assistant Server
==================================================
Starting server on http://localhost:5001
Endpoints:
  - POST /api/ask (with voice)
  - POST /api/ask-text-only (text only)
  - GET /health
==================================================
```

### 4. Start the Frontend Server

In a new terminal:

```bash
cd /Users/haoming/Desktop/calhacks
python3 -m http.server 8000
```

### 5. Open in Browser

Navigate to: `http://localhost:8000`

## How It Works

### Architecture

```
┌─────────────┐
│   Browser   │
│  (Frontend) │
└──────┬──────┘
       │
       │ HTTP POST /api/ask
       │
       ▼
┌─────────────────┐
│  Voice Server   │
│  (Flask/Python) │
└────┬───────┬────┘
     │       │
     │       │ WebSocket
     │       │
     ▼       ▼
┌─────────┐ ┌──────────┐
│ Claude  │ │   Fish   │
│   API   │ │ Audio API│
└─────────┘ └──────────┘
```

### Workflow

1. **User asks a question** → Frontend sends to backend
2. **Backend streams from Claude API** → Generates response with Fish API tags
3. **Response processing**:
   - Full text (with tags) → Sent to Fish API for TTS
   - Clean text (without tags) → Sent to frontend for display
4. **Audio streaming** → Fish API generates audio chunks
5. **Frontend plays audio** → Real-time playback while text appears

### Fish API Emotional Tags

The assistant automatically uses Fish API tags for natural voice:

**Example Claude Output:**
```
Well (confident) the pyramids were built um around 2500 BC (excited)!
They're amazing structures (calm) that took about 20 years to complete.
Hmm (thoughtful) the precision of their construction is remarkable!
```

**What Fish API receives:**
```
Well (confident) the pyramids were built um around 2500 BC (excited)! ...
```

**What user sees on screen:**
```
Well the pyramids were built around 2500 BC! They're amazing structures...
```

### Available Emotional Tags

- `(calm)` - Explanatory, peaceful content
- `(confident)` - Facts and teaching
- `(excited)` - Interesting topics
- `(curious)` - Questions
- `(thoughtful)` - Complex concepts
- `(encouraging)` - Motivation

### Vocal Cues

- `um` - Transitioning between ideas
- `ahh` - Realization moments
- `hmm` - Thinking
- `well` - Starting responses

## Usage

### Opening a Notebook

1. Click on any notebook card (e.g., "Ancient Egypt")
2. The assistant will:
   - Show: "Just a moment, I'm reading through your notes..."
   - Extract all notebook content
   - Feed it to Claude as context
   - Greet you: "Hi! I've learned all about [Topic]..."

### Asking Questions

1. Type your question in the input field
2. Press Enter or click "Send"
3. Watch the response appear in real-time
4. Hear the voice output simultaneously

### Voice Controls

- **Toggle Voice**: Click the 🔊 button to turn voice on/off
  - 🔊 = Voice enabled
  - 🔇 = Voice disabled (text only, faster)

### Example Questions

**For Ancient Egypt notebook:**
- "What were the main periods of Ancient Egypt?"
- "Tell me about the Nile flood cycle"
- "Who were the important pharaohs?"
- "Explain the mummification process"

**For Algorithm Asymptotics notebook:**
- "What is time complexity?"
- "Explain Big O notation"
- "How do I analyze an algorithm?"
- "What's the difference between O(n) and O(n²)?"

## Troubleshooting

### Backend Issues

**"Failed to connect to backend"**
- Ensure `voice_server.py` is running on port 5000
- Check: `curl http://localhost:5000/health`

**"Fish TTS error"**
- Verify Fish API key is correct
- Check Fish API quota/limits
- Look at server console for error messages

**"Claude streaming error"**
- Verify Anthropic API key is correct
- Check API rate limits
- Ensure internet connection is stable

### Frontend Issues

**"No audio playing"**
- Click anywhere on the page first (browser audio policy)
- Check browser console for errors
- Verify backend is sending audio chunks

**"Tags showing in text"**
- Clear browser cache
- Verify `strip_fish_tags()` is working
- Check browser console for errors

### Performance

**Slow responses**
- Use text-only mode (toggle voice off)
- Check network connection
- Verify server isn't overloaded

**Audio stuttering**
- Close other browser tabs
- Check CPU usage
- Reduce audio buffer size (in code)

## API Endpoints

### POST /api/ask
Streams response with voice output

**Request:**
```json
{
  "question": "What are pyramids?",
  "context": "System context/notebook content",
  "history": [
    {"role": "user", "content": "Previous question"},
    {"role": "assistant", "content": "Previous response"}
  ]
}
```

**Response:** Server-Sent Events stream
```
{"type": "text", "content": "The pyramids"}
{"type": "audio", "content": "base64encodedaudio"}
{"type": "done"}
```

### POST /api/ask-text-only
Streams response without voice (faster)

Same request/response format, but no audio chunks.

### GET /health
Check backend status

**Response:**
```json
{
  "status": "healthy",
  "services": {
    "claude": "connected",
    "fish_tts": "ready"
  }
}
```

## File Structure

```
calhacks/
├── voice_server.py          # Backend Flask server
├── requirements.txt         # Python dependencies
├── config.json             # API keys configuration
├── js/
│   ├── voice-service.js    # Frontend voice service
│   ├── note-assistant-voice.js  # Voice-enabled assistant
│   ├── dashboard.js        # Dashboard assistant
│   └── claude-service.js   # Fallback direct API
├── notes/
│   ├── ancient-egypt.html  # Example notebook
│   └── asymptotics.html    # Example notebook
└── css/
    ├── notebook-style.css  # Styling
    └── dashboard.css       # Dashboard styling
```

## Development

### Adding New Emotional Tags

1. Update `fish_instructions` in `voice_server.py`
2. Add tag to `strip_fish_tags()` regex if needed
3. Test with Fish API

### Adding New Notebooks

1. Create HTML file in `notes/` directory
2. Include:
   ```html
   <script src="../js/voice-service.js"></script>
   <script src="../js/note-assistant-voice.js"></script>
   ```
3. Add voice toggle button to header
4. Add Claude Ask Container

### Customizing Voice

Fish API supports various voice parameters. Check Fish Audio SDK documentation for:
- Voice models
- Speed control
- Pitch adjustment
- Audio format options

## Credits

- **Claude API**: Anthropic
- **Fish Audio SDK**: fish.audio
- **Frontend Framework**: Vanilla JavaScript
- **Backend**: Flask (Python)

## License

See main project license

## Support

For issues:
1. Check console logs (browser + server)
2. Verify API keys and quotas
3. Test `/health` endpoint
4. Review troubleshooting section above
