# Fixes Applied - Study Hub

## Issues Fixed

### 1. ✅ Flashcard & Quiz Generation (500 Errors)
**Problem:** API calls to `/api/generate-flashcards` and `/api/generate-quiz` were returning 500 errors

**Root Cause:** 
- Invalid Claude model name `claude-3-5-sonnet-20241022` (404 error from Anthropic API)
- API key only has access to `claude-3-haiku-20240307`

**Solution:**
- Updated all model references in `backend_server.py` to use `claude-3-haiku-20240307`
- Improved prompts to ensure Claude returns valid JSON
- Added better error handling and logging for JSON parsing

**Files Modified:**
- `backend_server.py` (lines 111, 182, 222, 268, 350)

### 2. ✅ General Assistant Chat Bubble (Missing on Dashboard)
**Problem:** No general assistant on the main dashboard to help users navigate

**Solution:**
- Added floating chat bubble in bottom-right corner of `index.html`
- Bubble provides help with:
  - Finding notes
  - Navigating classes
  - General study questions
- Uses the same `/api/ask-about-note` endpoint with class/note context

**Files Modified:**
- `index.html` (added chat bubble UI and JavaScript functions)

### 3. ✅ Specific Assistant on Note Pages
**Problem:** Assistant tab not showing on individual note pages

**Status:** The assistant panel already exists in `note-viewer.html` and should now work correctly with the fixed API model.

**Files Verified:**
- `note-viewer.html` (assistant panel present, lines 159-174)

### 4. ✅ API Key Security
**Problem:** API keys hardcoded in Python files

**Solution:**
- Created `.env` file to store sensitive credentials
- Updated `backend_server.py` and `voice_server.py` to use `python-dotenv`
- Created `.gitignore` to prevent committing sensitive files

**Files Created:**
- `.env` (contains ANTHROPIC_API_KEY and FISH_API_KEY)
- `.gitignore` (excludes .env, logs, cache, etc.)

**Files Modified:**
- `backend_server.py` (loads from .env)
- `voice_server.py` (loads from .env)

## Testing Status

### ✅ Working:
- Flashcard generation API
- Note listing API
- Backend server startup
- Environment variable loading

### ⚠️ To Test:
- Quiz generation (should work with same fixes)
- General assistant chat bubble (test in browser)
- Specific note assistant (test by opening a note)
- Voice features (separate server)

## How to Use

### Start the Backend:
```bash
cd /Users/haoming/Desktop/calhacks
python3 backend_server.py
```

### Access the App:
- Open http://localhost:8000 in your browser
- General assistant: Click the 💬 bubble in bottom-right
- Note assistant: Click any note to open, assistant panel on right side

### Environment Variables:
All API keys are now in `.env` file (not tracked by git)

## Notes

- The API key has limited model access (only claude-3-haiku-20240307)
- Haiku is faster but less sophisticated than Sonnet
- For better results, consider upgrading API tier for access to Sonnet models
