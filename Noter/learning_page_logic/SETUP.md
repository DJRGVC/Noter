# StudyHub - Setup & Usage Guide

## Overview
StudyHub is an AI-powered note organization and study platform with flashcard and quiz generation capabilities.

## New Features ✨

### 1. **Class-Based Organization**
   - Notes are now organized by classes (CS, Bio, History, Philosophy, etc.)
   - Each class displays all its notes in an expandable section
   - Notes are automatically discovered from the `calhacks25/` folder

### 2. **Add New Class**
   - Click "➕ Add New Class" on the dashboard
   - Enter a class name (e.g., "Math", "Physics")
   - A new folder will be created in `calhacks25/`

### 3. **Record New Note**
   - Click "📝 Record New Note"
   - Select a class from the dropdown
   - Enter a lecture number
   - The system will call `txt_to_note.py` to generate a beautiful HTML note

   **Prerequisites:** Before recording a note, you must create:
   - `l{num}.txt` - Lecture transcript (required)
   - `l{num}.pdf` - Lecture slides (optional)
   - `l{num}.py` - Code examples (optional)

### 4. **Dynamic Flashcards**
   - Flashcards now work with ALL notes from all classes
   - Select any note to generate flashcards
   - AI generates 10 flashcards per note

### 5. **Dynamic Quizzes**
   - Quizzes now work with ALL notes from all classes
   - Mix of multiple choice and free response questions
   - AI evaluates free response answers
   - Includes Manim animation code generation

## Quick Start

### 1. Start the Backend Server

```bash
# Option 1: Use the startup script
./start.sh

# Option 2: Manual start
python3 backend_server.py
```

The server will start on `http://localhost:5001`

### 2. Open the Frontend

Open a new terminal and start a simple HTTP server:

```bash
# Using Python 3
python3 -m http.server 8000

# Then open in browser:
# http://localhost:8000
```

## File Structure

```
calhacks/
├── backend_server.py          # Main backend API server (NEW)
├── voice_server.py            # Voice TTS server
├── start.sh                   # Startup script (NEW)
├── requirements.txt           # Python dependencies
├── index.html                 # Dashboard (UPDATED)
├── pages/
│   ├── flashcards-view.html  # Flashcards (UPDATED)
│   └── quizzes.html          # Quizzes (UPDATED)
├── calhacks25/               # Notes directory
│   ├── cs/                   # Computer Science notes
│   ├── bio/                  # Biology notes
│   ├── history/              # History notes
│   ├── philo/                # Philosophy notes
│   └── txt_to_note.py        # Note generator script
└── notes/                    # Legacy notes folder
```

## API Endpoints

The backend server (`http://localhost:5001`) provides:

- `GET /api/list-notes` - List all notes organized by class
- `POST /api/generate-flashcards` - Generate flashcards from note HTML
- `POST /api/generate-quiz` - Generate quiz questions from note HTML
- `POST /api/evaluate-answers` - Evaluate free response quiz answers
- `POST /api/generate-manim` - Generate Manim animation code
- `POST /api/create-class` - Create a new class directory
- `POST /api/create-note` - Generate a new note from transcript

## Creating a New Note

### Step 1: Prepare Your Files

In the class folder (e.g., `calhacks25/cs/`), create:

```
l13.txt    # Lecture transcript
l13.pdf    # (Optional) Lecture slides
l13.py     # (Optional) Code examples
```

### Step 2: Generate the Note

1. Click "📝 Record New Note" on dashboard
2. Select "CS" from dropdown
3. Enter "13" as lecture number
4. Click "Generate Note"

The system will:
- Call the AI to convert transcript → beautiful HTML
- Save as `l13.html` in the cs folder
- Display the new note on the dashboard

## Troubleshooting

### Backend not connecting
- Make sure `backend_server.py` is running on port 5001
- Check the terminal for error messages
- Verify all packages are installed: `pip3 install -r requirements.txt`

### Notes not showing
- Check that HTML files exist in `calhacks25/{class}/` folders
- Refresh the page
- Check browser console for errors (F12)

### Flashcards/Quiz generation fails
- Ensure backend server is running
- Check that you have a valid Anthropic API key in `backend_server.py`
- Check browser console and terminal for error messages

## Known Issues Fixed

1. ✅ Fixed: `/notes/null/api/ask` error (note-assistant API call path)
2. ✅ Fixed: Hardcoded note lists - now dynamically loaded
3. ✅ Fixed: Flashcards and quizzes only working with 2 notes
4. ✅ Added: Class-based organization
5. ✅ Added: Add new class functionality
6. ✅ Added: Record new note functionality

## Technologies Used

- **Frontend:** HTML, CSS, JavaScript
- **Backend:** Python Flask
- **AI:** Anthropic Claude API
- **Text-to-Speech:** Fish Audio SDK (optional)
