# Quick Start Guide - Voice-Enabled Study Assistant

## 🚀 Super Quick Start (Easiest Way)

```bash
cd /Users/haoming/Desktop/calhacks
./start.sh
```

Then open: **http://localhost:8000**

That's it! The script starts both servers automatically.

---

## 🚀 Manual Start (3 Steps)

### Step 1: Install Dependencies
```bash
cd /Users/haoming/Desktop/calhacks
pip3 install -r requirements.txt
```

### Step 2: Start Backend (Voice Server)
```bash
PORT=5001 python3 voice_server.py
```

**Note for macOS users:** Port 5000 is often used by AirPlay Receiver. We use port 5001 instead.

You should see:
```
🎙️  Voice-enabled Study Assistant Server
==================================================
Starting server on http://localhost:5001
```

### Step 3: Start Frontend (in a NEW terminal)
```bash
cd /Users/haoming/Desktop/calhacks
python3 -m http.server 8000
```

### Step 4: Open Browser
Navigate to: **http://localhost:8000**

---

## 🛑 To Stop Servers

```bash
./stop.sh
```

Or press `Ctrl+C` if you used `./start.sh`

---

## 🎯 How to Use

### On the Dashboard
1. See all your notebooks
2. General study assistant available (bottom right)
3. Click any notebook to dive in

### Inside a Notebook
1. **Wait** for: "Just a moment, I'm reading through your notes..."
2. **Then**: "Hi! I've learned all about [Topic]..."
3. **Ask questions** about the content
4. **Hear responses** with realistic voice
5. **Toggle voice** with 🔊/🔇 button

---

## 🎤 Voice Features

### Emotional Expression
The AI uses Fish API tags to sound natural:

**Introductions:**
- (welcoming) - Warm greeting
- (enthusiastic) - Energetic start
- (friendly) - Building rapport

**Explanations:**
- (calm) - Clear teaching
- (patient) - Complex topics
- (clear) - Emphasis on clarity

**Questions:**
- (curious) - Genuine interest
- (encouraging) - Motivation
- (thoughtful) - Consideration

**Praise:**
- (proud) - Student progress
- (delighted) - Success moments
- (impressed) - Good insights

### What You See vs. What Fish Hears

**Claude Generates:**
```
(welcoming) Hi there! (enthusiastic) I've learned all about Ancient Egypt!
```

**Fish API Receives:** (for natural voice)
```
(welcoming) Hi there! (enthusiastic) I've learned all about Ancient Egypt!
```

**You See on Screen:** (clean text)
```
Hi there! I've learned all about Ancient Egypt!
```

---

## 📝 Example Questions

### Ancient Egypt Notebook
- "What were the main periods of Ancient Egypt?"
- "Tell me about the pyramid construction"
- "How did the Nile flood cycle work?"
- "What gods did they worship?"

### Algorithm Asymptotics Notebook
- "What is Big O notation?"
- "Explain time complexity"
- "How do I analyze an algorithm?"
- "What's the difference between O(n) and O(n²)?"

---

## 🔧 Troubleshooting

### No Voice?
1. Click anywhere on the page (browser audio policy)
2. Check 🔊 button is on (not 🔇)
3. Verify voice_server.py is running

### Can't Connect?
1. Check backend: `curl http://localhost:5000/health`
2. Verify both servers are running
3. Check console for errors

### Slow Responses?
1. Toggle voice off (🔇) for faster text-only
2. Check internet connection
3. Verify API quotas

---

## 📁 Key Files

```
voice_server.py          ← Backend with Fish TTS
js/voice-service.js      ← Frontend audio handling
js/note-assistant-voice.js ← Voice-enabled assistant
notes/ancient-egypt.html ← Example notebook
notes/asymptotics.html   ← Example notebook
```

---

## 🎓 Tips

1. **First Time**: Click on page before talking (browser audio policy)
2. **Better Performance**: Use text mode for quick questions
3. **Voice Mode**: Best for longer explanations
4. **Context**: Assistant remembers conversation within each notebook
5. **Learning**: Assistant reads all note content when you open it

---

## 📚 Full Documentation

See `VOICE_SETUP.md` for complete details:
- Architecture diagrams
- API endpoints
- Customization options
- Advanced troubleshooting
- Development guide

---

## 🎉 Ready to Learn!

Your voice-enabled study assistant is ready. Open a notebook and start asking questions!

**Have fun learning!** 🚀📚🎓
