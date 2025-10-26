#!/usr/bin/env python3
"""
Unified API Server for Noter iOS App
Wraps existing backend_server.py and animation logic into clean REST endpoints
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional
import anthropic
import json
import os
import sys
from pathlib import Path
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import asyncio
import uuid

# Load environment variables
load_dotenv()

# Add animation module to path
sys.path.insert(0, str(Path(__file__).parent / "animation"))

app = FastAPI(title="Noter Backend API", version="1.0.0")

# CORS for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to your app
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Key from environment
ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY')
if not ANTHROPIC_API_KEY:
    print("Warning: ANTHROPIC_API_KEY not found in environment variables.")
    claude_client = None
else:
    claude_client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

# Paths
BASE_DIR = Path(__file__).parent
NOTES_DIR = BASE_DIR / 'calhacks25'

# ==================== DATA MODELS ====================

class NoteDTO(BaseModel):
    id: str
    content: str

class LectureDTO(BaseModel):
    id: str
    title: str
    summary: str = ""
    notes: List[NoteDTO] = []

class FlashcardDTO(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    question: str
    answer: str
    lectureID: str

class QuizQuestionDTO(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    question: str
    type: str  # "multipleChoice" or "freeResponse"
    options: List[str] = []
    correctAnswer: Optional[int] = None
    explanation: Optional[str] = None
    sampleAnswer: Optional[str] = None
    lectureID: str

class FlashcardsRequest(BaseModel):
    lecture: LectureDTO

class QuizRequest(BaseModel):
    lecture: LectureDTO

class AnimationRequest(BaseModel):
    topic: str
    lecture: Optional[LectureDTO] = None
    quizQuestions: List[QuizQuestionDTO] = []

class AnimationResponse(BaseModel):
    code: str
    jobId: str

class RenderRequest(BaseModel):
    code: str
    className: str = "GenScene"
    aspectRatio: str = "16:9"  # "16:9", "9:16", "1:1"

# ==================== HELPER FUNCTIONS ====================

def extract_notes_text(lecture: LectureDTO) -> str:
    """Extract plain text from lecture notes"""
    all_text = []
    if lecture.summary:
        all_text.append(f"Summary: {lecture.summary}")
    for note in lecture.notes:
        all_text.append(note.content)
    return "\n\n".join(all_text)

def parse_claude_json(response_text: str) -> dict:
    """Extract and parse JSON from Claude response"""
    # Handle code blocks
    if '```json' in response_text:
        json_text = response_text.split('```json')[1].split('```')[0].strip()
    elif '```' in response_text:
        json_text = response_text.split('```')[1].split('```')[0].strip()
    else:
        json_text = response_text.strip()
    
    try:
        return json.loads(json_text)
    except json.JSONDecodeError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to parse JSON from AI response: {str(e)}"
        )

# ==================== ENDPOINTS ====================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "anthropic_configured": ANTHROPIC_API_KEY is not None
    }

@app.post("/api/v1/generate/flashcards")
async def generate_flashcards(request: FlashcardsRequest):
    """Generate flashcards from lecture notes"""
    if not claude_client:
        raise HTTPException(status_code=503, detail="Anthropic API key not configured")
    
    try:
        lecture = request.lecture
        notes_text = extract_notes_text(lecture)
        
        if not notes_text.strip():
            raise HTTPException(status_code=400, detail="No notes content provided")
        
        prompt = f"""Based on these lecture notes titled "{lecture.title}", generate 10 flashcards to help students study.

NOTES:
{notes_text[:8000]}

You MUST respond with ONLY valid JSON in exactly this format, with no additional text before or after:
{{
  "flashcards": [
    {{
      "question": "question here",
      "answer": "answer here"
    }}
  ]
}}

Make questions clear and answers concise but informative. Return ONLY the JSON, nothing else."""

        message = claude_client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=4096,
            messages=[{"role": "user", "content": prompt}]
        )
        
        response_text = message.content[0].text
        data = parse_claude_json(response_text)
        
        # Convert to DTOs
        flashcards = [
            FlashcardDTO(
                question=fc["question"],
                answer=fc["answer"],
                lectureID=lecture.id
            )
            for fc in data.get("flashcards", [])
        ]
        
        return {"flashcards": [fc.dict() for fc in flashcards]}
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Flashcard generation failed: {str(e)}")

@app.post("/api/v1/generate/quiz")
async def generate_quiz(request: QuizRequest):
    """Generate quiz questions from lecture notes"""
    if not claude_client:
        raise HTTPException(status_code=503, detail="Anthropic API key not configured")
    
    try:
        lecture = request.lecture
        notes_text = extract_notes_text(lecture)
        
        if not notes_text.strip():
            raise HTTPException(status_code=400, detail="No notes content provided")
        
        prompt = f"""Based on these lecture notes titled "{lecture.title}", generate 5 quiz questions (3 multiple choice and 2 free response).

NOTES:
{notes_text[:8000]}

You MUST respond with ONLY valid JSON in exactly this format:
{{
  "questions": [
    {{
      "type": "mcq",
      "question": "question text",
      "options": ["option1", "option2", "option3", "option4"],
      "correct_answer": 0,
      "explanation": "explanation"
    }},
    {{
      "type": "free_response",
      "question": "question text",
      "sample_answer": "sample answer"
    }}
  ]
}}

Return ONLY the JSON, nothing else."""

        message = claude_client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=4096,
            messages=[{"role": "user", "content": prompt}]
        )
        
        response_text = message.content[0].text
        data = parse_claude_json(response_text)
        
        # Convert to DTOs
        quizzes = []
        for q in data.get("questions", []):
            quiz_type = "multipleChoice" if q.get("type") == "mcq" else "freeResponse"
            quizzes.append(
                QuizQuestionDTO(
                    question=q["question"],
                    type=quiz_type,
                    options=q.get("options", []),
                    correctAnswer=q.get("correct_answer"),
                    explanation=q.get("explanation"),
                    sampleAnswer=q.get("sample_answer"),
                    lectureID=lecture.id
                )
            )
        
        return {"quizzes": [q.dict() for q in quizzes]}
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quiz generation failed: {str(e)}")

@app.post("/api/v1/generate/animation")
async def generate_animation(request: AnimationRequest):
    """Generate Manim animation code from topic/lecture"""
    if not claude_client:
        raise HTTPException(status_code=503, detail="Anthropic API key not configured")
    
    try:
        topic = request.topic
        context = ""
        
        if request.lecture:
            context = f"\nLecture context:\n{extract_notes_text(request.lecture)[:4000]}"
        
        prompt = f"""Generate Python Manim code for an educational animation about: {topic}
{context}

Requirements:
- Create a class called GenScene that extends Scene
- Use clear, educational animations
- Include text explanations
- Make it visually engaging
- Code should be complete and runnable

Return ONLY the Python code, no explanations."""

        message = claude_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=4096,
            messages=[{"role": "user", "content": prompt}]
        )
        
        code = message.content[0].text
        
        # Extract code if wrapped in markdown
        if '```python' in code:
            code = code.split('```python')[1].split('```')[0].strip()
        elif '```' in code:
            code = code.split('```')[1].split('```')[0].strip()
        
        job_id = str(uuid.uuid4())
        
        return AnimationResponse(code=code, jobId=job_id)
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Animation generation failed: {str(e)}")

@app.post("/api/v1/animation/render")
async def render_animation(request: RenderRequest):
    """
    Render Manim animation and stream progress.
    This is a simplified version - full implementation would need manim installed
    """
    # Note: This requires manim to be installed in the environment
    # For now, return a mock response
    return {
        "message": "Rendering not yet implemented. Install manim and configure video.py integration.",
        "jobId": str(uuid.uuid4())
    }

@app.get("/api/v1/samples")
async def list_samples():
    """List available sample lectures from calhacks25"""
    try:
        samples = []
        
        if NOTES_DIR.exists():
            for class_dir in NOTES_DIR.iterdir():
                if class_dir.is_dir() and not class_dir.name.startswith('.'):
                    class_name = class_dir.name
                    
                    for html_file in sorted(class_dir.glob('*.html'))[:3]:  # Limit to 3 per class
                        samples.append({
                            "id": f"{class_name}_{html_file.stem}",
                            "title": html_file.stem.replace('_', ' ').title(),
                            "className": class_name
                        })
        
        return {"samples": samples}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/samples/{sample_id}")
async def get_sample(sample_id: str):
    """Get a specific sample lecture"""
    try:
        # Parse sample_id (format: classname_filename)
        parts = sample_id.split('_', 1)
        if len(parts) != 2:
            raise HTTPException(status_code=400, detail="Invalid sample ID format")
        
        class_name, file_stem = parts
        html_file = NOTES_DIR / class_name / f"{file_stem}.html"
        
        if not html_file.exists():
            raise HTTPException(status_code=404, detail="Sample not found")
        
        # Read and parse HTML
        with open(html_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        soup = BeautifulSoup(content, 'html.parser')
        text_content = soup.get_text(separator='\n')
        
        # Extract title
        h1 = soup.find('h1')
        title = h1.get_text().strip() if h1 else file_stem.replace('_', ' ').title()
        
        lecture = LectureDTO(
            id=sample_id,
            title=title,
            summary=f"Sample lecture from {class_name}",
            notes=[NoteDTO(id="1", content=text_content[:5000])]  # Limit size
        )
        
        return {"lecture": lecture.dict()}
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== STARTUP ====================

if __name__ == "__main__":
    import uvicorn
    print("🚀 Starting Noter Backend API Server...")
    print(f"📁 Notes directory: {NOTES_DIR}")
    print(f"🔑 Anthropic API configured: {ANTHROPIC_API_KEY is not None}")
    uvicorn.run(app, host="127.0.0.1", port=8000, reload=True)
