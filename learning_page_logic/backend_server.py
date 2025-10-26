#!/usr/bin/env python3
"""
Backend server for note management, flashcard and quiz generation
"""

from flask import Flask, request, Response, jsonify, send_from_directory
from flask_cors import CORS
import anthropic
import json
import os
from pathlib import Path
from bs4 import BeautifulSoup
import subprocess
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__, static_folder='.')
CORS(app)

# API Key from environment
ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY')
if not ANTHROPIC_API_KEY:
    raise ValueError("ANTHROPIC_API_KEY not found in environment variables. Please check your .env file.")
claude_client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

# Paths
BASE_DIR = Path(__file__).parent
NOTES_DIR = BASE_DIR / 'calhacks25'

@app.route('/api/list-notes', methods=['GET'])
def list_notes():
    """List all notes organized by class"""
    try:
        notes_structure = {}

        # Scan calhacks25 directory for classes
        if NOTES_DIR.exists():
            for class_dir in NOTES_DIR.iterdir():
                if class_dir.is_dir() and not class_dir.name.startswith('.'):
                    class_name = class_dir.name
                    notes_structure[class_name] = []

                    # Find all HTML notes in this class
                    for html_file in sorted(class_dir.glob('*.html')):
                        note_info = {
                            'filename': html_file.name,
                            'path': f'calhacks25/{class_name}/{html_file.name}',
                            'title': extract_title_from_html(html_file),
                            'class': class_name
                        }
                        notes_structure[class_name].append(note_info)

        return jsonify({
            'classes': notes_structure,
            'total_classes': len(notes_structure)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def extract_title_from_html(html_path):
    """Extract title from HTML file"""
    try:
        with open(html_path, 'r', encoding='utf-8') as f:
            content = f.read()
            soup = BeautifulSoup(content, 'html.parser')
            # Try to find h1 or title tag
            h1 = soup.find('h1')
            if h1:
                return h1.get_text().strip()
            title = soup.find('title')
            if title:
                return title.get_text().strip()
            return html_path.stem
    except:
        return html_path.stem

@app.route('/api/generate-flashcards', methods=['POST'])
def generate_flashcards():
    """Generate flashcards from notebook HTML"""
    try:
        data = request.json
        notebook_html = data.get('notebook_html', '')
        title = data.get('title', 'Notes')

        # Extract text content from HTML
        soup = BeautifulSoup(notebook_html, 'html.parser')
        text_content = soup.get_text(separator='\n')

        # Call Claude to generate flashcards
        prompt = f"""Based on these notes titled "{title}", generate 10 flashcards to help students study.

NOTES:
{text_content[:8000]}

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
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        response_text = message.content[0].text

        # Extract JSON from response
        if '```json' in response_text:
            json_text = response_text.split('```json')[1].split('```')[0].strip()
        elif '```' in response_text:
            json_text = response_text.split('```')[1].split('```')[0].strip()
        else:
            json_text = response_text.strip()

        try:
            flashcard_data = json.loads(json_text)
        except json.JSONDecodeError as je:
            print(f"JSON Parse Error: {je}")
            print(f"Response text: {response_text[:500]}")
            return jsonify({'error': f'Failed to parse JSON. Raw response: {response_text[:200]}'}), 500

        return jsonify(flashcard_data)

    except Exception as e:
        print(f"Flashcard generation error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/api/generate-quiz', methods=['POST'])
def generate_quiz():
    """Generate quiz from notebook HTML"""
    try:
        data = request.json
        notebook_html = data.get('notebook_html', '')
        title = data.get('title', 'Notes')

        # Extract text content from HTML
        soup = BeautifulSoup(notebook_html, 'html.parser')
        text_content = soup.get_text(separator='\n')

        # Call Claude to generate quiz
        prompt = f"""Based on these notes titled "{title}", generate 5 quiz questions (mix of multiple choice and free response).

NOTES:
{text_content[:8000]}

You MUST respond with ONLY valid JSON in exactly this format, with no additional text before or after:
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

Make 3 multiple choice and 2 free response questions. Return ONLY the JSON, nothing else."""

        message = claude_client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=4096,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        response_text = message.content[0].text

        # Extract JSON from response
        if '```json' in response_text:
            json_text = response_text.split('```json')[1].split('```')[0].strip()
        elif '```' in response_text:
            json_text = response_text.split('```')[1].split('```')[0].strip()
        else:
            json_text = response_text

        quiz_data = json.loads(json_text)
        return jsonify(quiz_data)

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/evaluate-answers', methods=['POST'])
def evaluate_answers():
    """Evaluate free response answers"""
    try:
        data = request.json
        questions = data.get('questions', [])

        scores = {}
        for q in questions:
            user_answer = q.get('userAnswer', '')
            sample_answer = q.get('sample_answer', '')
            question_text = q.get('question', '')
            idx = q.get('index')

            prompt = f"""Evaluate this student's answer:

Question: {question_text}

Student's Answer: {user_answer}

Sample Answer: {sample_answer}

Give a score from 0 to 1 (0 = completely wrong, 0.5 = partially correct, 1 = fully correct).
Provide brief feedback.

Respond in JSON:
{{
  "score": 0.0,
  "feedback": "feedback here"
}}"""

            message = claude_client.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=512,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )

            response_text = message.content[0].text

            # Extract JSON from response
            if '```json' in response_text:
                json_text = response_text.split('```json')[1].split('```')[0].strip()
            elif '```' in response_text:
                json_text = response_text.split('```')[1].split('```')[0].strip()
            else:
                json_text = response_text

            evaluation = json.loads(json_text)
            scores[idx] = evaluation

        return jsonify({'scores': scores})

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/generate-manim', methods=['POST'])
def generate_manim():
    """Generate Manim animation code"""
    try:
        data = request.json
        topic = data.get('topic', '')
        quiz_questions = data.get('quiz_questions', [])

        prompt = f"""Generate a Manim (Mathematical Animation Engine) Python script to create an educational animation about: {topic}

Based on these quiz questions:
{json.dumps(quiz_questions, indent=2)[:2000]}

Create a complete, working Manim script that:
1. Explains key concepts visually
2. Uses animations to illustrate the topic
3. Is educational and engaging

Return ONLY the Python code, ready to run with Manim."""

        message = claude_client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=4096,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        code = message.content[0].text

        # Extract code if wrapped in markdown
        if '```python' in code:
            code = code.split('```python')[1].split('```')[0].strip()
        elif '```' in code:
            code = code.split('```')[1].split('```')[0].strip()

        return jsonify({'code': code})

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/create-note', methods=['POST'])
def create_note():
    """Create a new note by calling txt_to_note.py"""
    try:
        data = request.json
        class_name = data.get('class_name', '')
        lecture_num = data.get('lecture_num', '')

        if not class_name or not lecture_num:
            return jsonify({'error': 'class_name and lecture_num required'}), 400

        # Path to the class directory
        class_dir = NOTES_DIR / class_name

        if not class_dir.exists():
            return jsonify({'error': f'Class directory {class_name} does not exist'}), 404

        # Call txt_to_note.py
        txt_to_note_script = NOTES_DIR / 'txt_to_note.py'

        result = subprocess.run(
            [sys.executable, str(txt_to_note_script), '--course', str(class_dir), '--lecture', str(lecture_num)],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            return jsonify({'error': f'Script failed: {result.stderr}'}), 500

        return jsonify({
            'success': True,
            'output': result.stdout,
            'path': f'calhacks25/{class_name}/l{lecture_num}.html'
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/ask-about-note', methods=['POST'])
def ask_about_note():
    """Answer questions about note content"""
    try:
        data = request.json
        question = data.get('question', '')
        note_content = data.get('noteContent', '')
        note_title = data.get('noteTitle', 'the note')

        if not question or not note_content:
            return jsonify({'error': 'question and noteContent required'}), 400

        # Create context-aware prompt
        prompt = f"""You are a helpful study assistant. A student is reading their notes titled "{note_title}" and has a question.

Here is the content of their notes:

{note_content[:10000]}

Student's question: {question}

Please provide a helpful, concise answer based on the notes. If the answer isn't in the notes, say so and offer general guidance if appropriate."""

        message = claude_client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=1024,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        answer = message.content[0].text

        return jsonify({'answer': answer})

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/create-class', methods=['POST'])
def create_class():
    """Create a new class directory"""
    try:
        data = request.json
        class_name = data.get('class_name', '').lower().replace(' ', '_')

        if not class_name:
            return jsonify({'error': 'class_name required'}), 400

        # Create class directory
        class_dir = NOTES_DIR / class_name
        class_dir.mkdir(exist_ok=True)

        return jsonify({
            'success': True,
            'class_name': class_name,
            'path': f'calhacks25/{class_name}'
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/v1/code/generation', methods=['POST'])
def generate_animation_code():
    """Generate Manim animation code from a prompt"""
    try:
        data = request.json
        prompt_content = data.get('prompt', '')
        model = data.get('model', 'claude-3-haiku-20240307')

        if not prompt_content:
            return jsonify({'error': 'Prompt is required'}), 400

        general_system_prompt = """
You are an assistant that knows about Manim. Manim is a mathematical animation engine that is used to create videos programmatically.

The following is an example of the code:
```
from manim import *
from math import *

class GenScene(Scene):
    def construct(self):
        c = Circle(color=BLUE)
        self.play(Create(c))
```

# Rules
1. Always use GenScene as the class name, otherwise, the code will not work.
2. Always use self.play() to play the animation, otherwise, the code will not work.
3. Do not use text to explain the code, only the code.
4. Do not explain the code, only the code.
5. Create educational and visually appealing animations.
"""

        # Call Claude to generate Manim code
        message = claude_client.messages.create(
            model=model,
            max_tokens=4096,
            system=general_system_prompt,
            messages=[
                {"role": "user", "content": prompt_content}
            ]
        )

        code = message.content[0].text

        return jsonify({'code': code})

    except Exception as e:
        print(f"Code generation error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/v1/video/rendering', methods=['POST'])
def render_animation_video():
    """Render a Manim video from code"""
    try:
        data = request.json
        code = data.get('code', '')
        file_class = data.get('file_class', 'GenScene')
        aspect_ratio = data.get('aspect_ratio', '16:9')
        stream = data.get('stream', False)

        if not code:
            return jsonify({'error': 'Code is required'}), 400

        # Determine frame size and width based on aspect ratio
        if aspect_ratio == "16:9":
            frame_size = (3840, 2160)
            frame_width = 14.22
        elif aspect_ratio == "9:16":
            frame_size = (1080, 1920)
            frame_width = 8.0
        elif aspect_ratio == "1:1":
            frame_size = (1080, 1080)
            frame_width = 8.0
        else:
            frame_size = (3840, 2160)
            frame_width = 14.22

        # Modify the Manim script to include configuration settings
        modified_code = f"""
from manim import *
from math import *
config.frame_size = {frame_size}
config.frame_width = {frame_width}

{code}
"""

        # Create a unique file name
        import os
        import random
        file_name = f"scene_{''.join(random.choices('0123456789abcdef', k=4))}.py"
        file_path = os.path.join(BASE_DIR, file_name)

        # Write the code to the file
        with open(file_path, 'w') as f:
            f.write(modified_code)

        try:
            # Run manim to render the video
            import subprocess
            command = [
                'manim',
                file_path,
                file_class,
                '--format=mp4',
                '--media_dir', '.',
                '--custom_folders'
            ]

            if stream:
                # Streaming mode - send progress updates
                def generate():
                    process = subprocess.Popen(
                        command,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        cwd=str(BASE_DIR),
                        text=True,
                        bufsize=1
                    )

                    import re
                    current_animation = -1
                    current_percentage = 0

                    while True:
                        stderr_line = process.stderr.readline()
                        if stderr_line == '' and process.poll() is not None:
                            break

                        if stderr_line:
                            # Parse progress from stderr
                            animation_match = re.search(r'Animation (\d+):', stderr_line)
                            if animation_match:
                                current_animation = int(animation_match.group(1))
                                yield f'{{"animationIndex": {current_animation}, "percentage": 0}}\n'

                            percentage_match = re.search(r'(\d+)%', stderr_line)
                            if percentage_match:
                                current_percentage = int(percentage_match.group(1))
                                yield f'{{"animationIndex": {current_animation}, "percentage": {current_percentage}}}\n'

                    if process.returncode == 0:
                        # Video rendered successfully
                        video_file_path = os.path.join(BASE_DIR, f"{file_class}.mp4")

                        if os.path.exists(video_file_path):
                            # Serve the video file
                            video_url = f"http://127.0.0.1:5001/video/{file_class}.mp4"
                            yield f'{{"video_url": "{video_url}"}}\n'
                        else:
                            yield f'{{"error": "Video file not found"}}\n'
                    else:
                        yield f'{{"error": "Rendering failed"}}\n'

                return Response(generate(), content_type='text/event-stream')
            else:
                # Non-streaming mode
                result = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    cwd=str(BASE_DIR)
                )

                if result.returncode == 0:
                    video_file_path = os.path.join(BASE_DIR, f"{file_class}.mp4")

                    if os.path.exists(video_file_path):
                        video_url = f"http://127.0.0.1:5001/video/{file_class}.mp4"
                        return jsonify({
                            'message': 'Video rendered successfully',
                            'video_url': video_url
                        })
                    else:
                        return jsonify({'error': 'Video file not found'}), 500
                else:
                    return jsonify({
                        'error': 'Rendering failed',
                        'details': result.stderr
                    }), 500

        finally:
            # Clean up the temporary Python file
            if os.path.exists(file_path):
                os.remove(file_path)

    except Exception as e:
        print(f"Video rendering error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/video/<filename>')
def serve_video(filename):
    """Serve rendered video files"""
    return send_from_directory(str(BASE_DIR), filename)

# Serve static files
@app.route('/')
def serve_index():
    return send_from_directory('.', 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory('.', path)

if __name__ == '__main__':
    print("Starting backend server on http://localhost:5001")
    print(f"Notes directory: {NOTES_DIR}")
    app.run(host='127.0.0.1', port=5001, debug=True)
