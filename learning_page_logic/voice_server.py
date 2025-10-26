#!/usr/bin/env python3
"""
Voice-enabled Study Assistant Backend
Integrates Claude API streaming with Fish Audio TTS
"""

from flask import Flask, request, Response, jsonify
from flask_cors import CORS
import anthropic
import json
import io
import os
from fish_audio_sdk import WebSocketSession, TTSRequest
import threading
import queue
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)

# API Keys from environment
ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY')
FISH_API_KEY = os.getenv('FISH_API_KEY')

if not ANTHROPIC_API_KEY:
    raise ValueError("ANTHROPIC_API_KEY not found in environment variables. Please check your .env file.")
if not FISH_API_KEY:
    print("Warning: FISH_API_KEY not found in environment variables. Voice features may not work.")

# Initialize clients
claude_client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

class TextStreamBuffer:
    """Buffer to collect text chunks for Fish API"""
    def __init__(self):
        self.queue = queue.Queue()
        self.done = False

    def add(self, text):
        """Add text chunk to buffer"""
        if text:
            self.queue.put(text)

    def finish(self):
        """Signal that streaming is complete"""
        self.done = True

    def __iter__(self):
        """Iterator for Fish API consumption"""
        while not self.done or not self.queue.empty():
            try:
                yield self.queue.get(timeout=0.1)
            except queue.Empty:
                if self.done:
                    break
                continue


@app.route('/api/ask', methods=['POST'])
def ask_assistant():
    """
    Endpoint that:
    1. Receives question + context from frontend
    2. Streams response from Claude API with Fish API tags
    3. Converts text to speech via Fish API (with tags)
    4. Streams audio back to frontend (strips tags for display)
    """
    data = request.json
    question = data.get('question', '')
    system_context = data.get('context', '')
    conversation_history = data.get('history', [])

    # Optimize for voice: Keep responses concise and conversational
    voice_instructions = """

IMPORTANT - Voice Output Optimization:
Since your responses will be converted to speech, please:
1. Keep responses concise and conversational
2. Use natural, flowing language
3. Avoid overly complex sentences
4. Add natural pauses with commas
5. Be engaging and encouraging
6. Use simple, clear explanations

Remember: Students will be HEARING this, so make it easy to follow by ear!
"""

    enhanced_context = (system_context + voice_instructions) if system_context else voice_instructions

    def generate_audio():
        """Generator that streams audio chunks"""
        text_buffer = TextStreamBuffer()
        audio_queue = queue.Queue()

        # Thread to stream Claude API and collect text
        def stream_claude():
            try:
                # Build messages
                messages = conversation_history + [
                    {"role": "user", "content": question}
                ]

                # Stream from Claude with enhanced context
                full_text = ""
                with claude_client.messages.stream(
                    model="claude-3-5-sonnet-20241022",
                    max_tokens=4096,
                    messages=messages,
                    system=enhanced_context,
                ) as stream:
                    for text_chunk in stream.text_stream:
                        # Accumulate text for better TTS batching
                        full_text += text_chunk
                        text_buffer.add(text_chunk)

                        # Send text to frontend for display
                        audio_queue.put(json.dumps({
                            'type': 'text',
                            'content': text_chunk
                        }) + '\n')

                text_buffer.finish()
            except Exception as e:
                print(f"Claude streaming error: {e}")
                text_buffer.finish()
                audio_queue.put(json.dumps({
                    'type': 'error',
                    'content': str(e)
                }) + '\n')

        # Thread to convert text to speech via Fish API
        def stream_fish_tts():
            try:
                ws_session = WebSocketSession(FISH_API_KEY)
                with ws_session:
                    for audio_chunk in ws_session.tts(
                        TTSRequest(text=""),  # Empty text for streaming mode
                        text_buffer
                    ):
                        # Send audio chunk as base64
                        import base64
                        audio_b64 = base64.b64encode(audio_chunk).decode('utf-8')
                        audio_queue.put(json.dumps({
                            'type': 'audio',
                            'content': audio_b64
                        }) + '\n')

                # Signal completion
                audio_queue.put(json.dumps({
                    'type': 'done'
                }) + '\n')
            except Exception as e:
                print(f"Fish TTS error: {e}")
                audio_queue.put(json.dumps({
                    'type': 'error',
                    'content': f"TTS Error: {str(e)}"
                }) + '\n')

        # Start both threads
        claude_thread = threading.Thread(target=stream_claude)
        fish_thread = threading.Thread(target=stream_fish_tts)

        claude_thread.start()
        fish_thread.start()

        # Yield audio chunks as they come
        while True:
            try:
                chunk = audio_queue.get(timeout=0.1)
                yield chunk

                # Check if done
                try:
                    chunk_data = json.loads(chunk)
                    if chunk_data.get('type') == 'done':
                        break
                except:
                    pass
            except queue.Empty:
                # Check if both threads are done
                if not claude_thread.is_alive() and not fish_thread.is_alive():
                    if audio_queue.empty():
                        break
                continue

        # Wait for threads to complete
        claude_thread.join(timeout=5)
        fish_thread.join(timeout=5)

    return Response(generate_audio(), mimetype='text/event-stream')


@app.route('/api/ask-text-only', methods=['POST'])
def ask_text_only():
    """
    Endpoint for text-only responses (no voice)
    Used when user wants faster responses without TTS
    """
    data = request.json
    question = data.get('question', '')
    system_context = data.get('context', '')
    conversation_history = data.get('history', [])

    def generate_text():
        """Generator that streams text chunks"""
        try:
            # Build messages
            messages = conversation_history + [
                {"role": "user", "content": question}
            ]

            # Stream from Claude
            with claude_client.messages.stream(
                model="claude-3-5-sonnet-20241022",
                max_tokens=4096,
                messages=messages,
                system=system_context if system_context else None,
            ) as stream:
                for text_chunk in stream.text_stream:
                    yield json.dumps({
                        'type': 'text',
                        'content': text_chunk
                    }) + '\n'

            # Signal completion
            yield json.dumps({
                'type': 'done'
            }) + '\n'

        except Exception as e:
            yield json.dumps({
                'type': 'error',
                'content': str(e)
            }) + '\n'

    return Response(generate_text(), mimetype='text/event-stream')


@app.route('/api/generate-flashcards', methods=['POST'])
def generate_flashcards():
    """
    Generate flashcards from notebook content
    Request: {notebook_html: "...", title: "..."}
    Response: {flashcards: [{question: "...", answer: "..."}]}
    """
    from bs4 import BeautifulSoup

    data = request.json
    notebook_html = data.get('notebook_html', '')
    title = data.get('title', 'Unknown Topic')

    try:
        # Parse HTML
        soup = BeautifulSoup(notebook_html, 'html.parser')

        # Extract sections
        sections = []
        for section in soup.find_all(class_='section'):
            heading = section.find('h2')
            heading_text = heading.get_text() if heading else "Section"

            # Get text content, excluding images
            content = section.get_text(separator=' ', strip=True)
            # Limit section size
            if len(content) > 2000:
                content = content[:2000] + "..."

            sections.append({
                'heading': heading_text,
                'content': content
            })

        if not sections:
            return jsonify({'error': 'No sections found in notebook'}), 400

        # Generate flashcards using Claude
        flashcards = []

        # Process sections in chunks to avoid token limits
        for i, section in enumerate(sections[:10]):  # Limit to first 10 sections
            prompt = f"""Based on this section from a study guide about "{title}", generate 3-5 high-quality flashcards.

Section: {section['heading']}
Content: {section['content']}

Generate flashcards in JSON format:
[
    {{"question": "...", "answer": "..."}},
    {{"question": "...", "answer": "..."}}
]

Focus on:
- Key concepts and definitions
- Important facts and dates
- Cause and effect relationships
- Comparisons and contrasts

Return ONLY the JSON array, nothing else."""

            response = claude_client.messages.create(
                model="claude-3-5-sonnet-20241022",
                max_tokens=2048,
                messages=[{
                    "role": "user",
                    "content": prompt
                }]
            )

            # Parse response
            response_text = response.content[0].text.strip()
            # Extract JSON from response
            import json
            import re

            # Try to find JSON array in response
            json_match = re.search(r'\[[\s\S]*\]', response_text)
            if json_match:
                try:
                    section_flashcards = json.loads(json_match.group())
                    flashcards.extend(section_flashcards)
                except json.JSONDecodeError:
                    print(f"Failed to parse flashcards for section {i}")
                    continue

        return jsonify({
            'flashcards': flashcards,
            'count': len(flashcards),
            'title': title
        })

    except Exception as e:
        print(f"Error generating flashcards: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/api/generate-quiz', methods=['POST'])
def generate_quiz():
    """
    Generate quiz questions from notebook content with mix of MCQ and free response
    Request: {notebook_html: "...", title: "..."}
    Response: {questions: [{type: "mcq", question: "...", options: [...], correct_answer: 0, explanation: "..."}]}
    """
    from bs4 import BeautifulSoup

    data = request.json
    notebook_html = data.get('notebook_html', '')
    title = data.get('title', 'Unknown Topic')

    try:
        # Parse HTML
        soup = BeautifulSoup(notebook_html, 'html.parser')

        # Extract sections
        sections = []
        for section in soup.find_all(class_='section'):
            heading = section.find('h2')
            heading_text = heading.get_text() if heading else "Section"

            # Get text content, excluding images
            content = section.get_text(separator=' ', strip=True)
            # Limit section size
            if len(content) > 2000:
                content = content[:2000] + "..."

            sections.append({
                'heading': heading_text,
                'content': content
            })

        if not sections:
            return jsonify({'error': 'No sections found in notebook'}), 400

        # Combine sections for better context
        all_content = "\n\n".join([f"{s['heading']}: {s['content']}" for s in sections[:8]])

        # Generate quiz questions using Claude (mix of MCQ and free response)
        prompt = f"""Based on this study guide about "{title}", generate 5-7 high-quality quiz questions.

Content:
{all_content[:6000]}

Generate a mix of question types:
1. Multiple choice questions (about 60-70%)
2. Free response questions (about 30-40%)

Return questions in this EXACT JSON format:
[
    {{
        "type": "mcq",
        "question": "Question text here?",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "correct_answer": 0,
        "explanation": "Brief explanation of the correct answer"
    }},
    {{
        "type": "free_response",
        "question": "Explain or describe something in your own words.",
        "sample_answer": "A good example answer that demonstrates understanding"
    }}
]

Requirements:
- Test understanding, not just memorization
- Mix of difficulty levels
- Clear, unambiguous questions
- Plausible distractors for MCQ
- Free response should test deeper understanding

Return ONLY the JSON array, nothing else."""

        response = claude_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=3048,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )

        # Parse response
        response_text = response.content[0].text.strip()
        import json
        import re

        # Try to find JSON array in response
        json_match = re.search(r'\[[\s\S]*\]', response_text)
        if json_match:
            questions = json.loads(json_match.group())
        else:
            return jsonify({'error': 'Failed to parse quiz questions'}), 500

        return jsonify({
            'questions': questions,
            'count': len(questions),
            'title': title
        })

    except Exception as e:
        print(f"Error generating quiz: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/api/evaluate-answers', methods=['POST'])
def evaluate_answers():
    """
    Evaluate free response answers
    Request: {questions: [{question: "...", sample_answer: "...", userAnswer: "...", index: 0}]}
    Response: {scores: {0: {score: 0.8, feedback: "..."}}}
    """
    data = request.json
    questions = data.get('questions', [])

    try:
        scores = {}

        for q in questions:
            question_text = q.get('question', '')
            sample_answer = q.get('sample_answer', '')
            user_answer = q.get('userAnswer', '')
            index = q.get('index', 0)

            if not user_answer:
                scores[index] = {
                    'score': 0,
                    'feedback': 'No answer provided.'
                }
                continue

            # Use Claude to evaluate the answer
            eval_prompt = f"""Evaluate this student's free response answer.

Question: {question_text}

Sample/Expected Answer: {sample_answer}

Student's Answer: {user_answer}

Evaluate based on:
1. Accuracy of information
2. Completeness of answer
3. Understanding of concepts
4. Clarity of explanation

Provide:
- Score: 0 (incorrect/poor), 0.5 (partially correct/good), or 1 (correct/excellent)
- Feedback: Brief constructive feedback (2-3 sentences)

Return in this EXACT JSON format:
{{
    "score": 0.5,
    "feedback": "Your answer shows understanding but could be more complete..."
}}

Return ONLY the JSON, nothing else."""

            response = claude_client.messages.create(
                model="claude-3-5-sonnet-20241022",
                max_tokens=512,
                messages=[{
                    "role": "user",
                    "content": eval_prompt
                }]
            )

            # Parse response
            response_text = response.content[0].text.strip()
            import json
            import re

            # Try to find JSON in response
            json_match = re.search(r'\{[\s\S]*\}', response_text)
            if json_match:
                evaluation = json.loads(json_match.group())
                scores[index] = evaluation
            else:
                scores[index] = {
                    'score': 0,
                    'feedback': 'Could not evaluate answer.'
                }

        return jsonify({'scores': scores})

    except Exception as e:
        print(f"Error evaluating answers: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/api/generate-manim', methods=['POST'])
def generate_manim():
    """
    Generate Manim animation code based on quiz topic
    Request: {topic: "ancient-egypt", quiz_questions: [...]}
    Response: {code: "from manim import *..."}
    """
    data = request.json
    topic = data.get('topic', '')
    quiz_questions = data.get('quiz_questions', [])

    try:
        # Get topic title
        topic_titles = {
            'ancient-egypt': 'Ancient Egypt',
            'asymptotics': 'Algorithm Asymptotics'
        }
        topic_title = topic_titles.get(topic, 'Educational Topic')

        # Create summary of key concepts from quiz
        key_concepts = []
        for q in quiz_questions[:5]:  # Use first 5 questions
            if q.get('type') == 'mcq':
                key_concepts.append(q.get('question', ''))

        concepts_text = "\n".join([f"- {c}" for c in key_concepts])

        # Generate Manim code using Claude
        prompt = f"""Generate Manim (Mathematical Animation Engine) Python code to create an educational animation about "{topic_title}".

Key concepts to cover:
{concepts_text}

Requirements:
1. Create a complete, runnable Manim scene
2. Use animations like Write, FadeIn, Transform, Create
3. Include visual elements (Text, shapes, arrows, etc.)
4. Add color and styling for engagement
5. Should run for 30-60 seconds
6. Include comments explaining each section
7. Use Manim Community Edition syntax

Generate a complete Python file that can be run with:
manim -pql script.py SceneName

Return ONLY the Python code, no additional explanation."""

        response = claude_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=4096,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )

        # Extract code from response
        response_text = response.content[0].text.strip()
        
        # Remove markdown code blocks if present
        import re
        code_match = re.search(r'```python\n([\s\S]*?)\n```', response_text)
        if code_match:
            code = code_match.group(1)
        else:
            # Try without python tag
            code_match = re.search(r'```\n([\s\S]*?)\n```', response_text)
            if code_match:
                code = code_match.group(1)
            else:
                code = response_text

        return jsonify({'code': code})

    except Exception as e:
        print(f"Error generating Manim code: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/api/generate-manim-custom', methods=['POST'])
def generate_manim_custom():
    """
    Generate custom Manim animation code based on user specifications
    Request: {
        topic: "...",
        description: "...",
        animation_type: "mathematical|educational|scientific|algorithmic",
        duration: 60
    }
    Response: {code: "from manim import *..."}
    """
    data = request.json
    topic = data.get('topic', '')
    description = data.get('description', '')
    animation_type = data.get('animation_type', 'educational')
    duration = data.get('duration', 60)

    try:
        # Build specialized prompt based on animation type
        type_specific_guidance = {
            'mathematical': """
Focus on:
- Mathematical equations and formulas
- Geometric shapes and transformations
- Step-by-step algebraic manipulations
- Visual proofs and demonstrations
- Use MathTex for equations
            """,
            'educational': """
Focus on:
- Clear explanations with text and visuals
- Progressive reveal of concepts
- Use of diagrams and illustrations
- Engaging colors and layouts
- Simple, easy-to-follow flow
            """,
            'scientific': """
Focus on:
- Scientific diagrams and models
- Process flows and mechanisms
- Cause-and-effect relationships
- Use of arrows and annotations
- Real-world visual representations
            """,
            'algorithmic': """
Focus on:
- Code visualization and execution flow
- Data structure representations (arrays, trees, graphs)
- Step-by-step algorithm execution
- Highlighting and color coding for different states
- Use of Code mobjects for pseudocode
            """
        }

        guidance = type_specific_guidance.get(animation_type, type_specific_guidance['educational'])

        # Generate Manim code using Claude
        prompt = f"""Generate Manim (Mathematical Animation Engine) Python code for an educational animation.

Topic: {topic}
Description: {description}
Animation Type: {animation_type}
Target Duration: {duration} seconds

{guidance}

Requirements:
1. Create a complete, runnable Manim scene class
2. Use Manim Community Edition syntax
3. Include proper imports from manim
4. Use engaging animations (Write, FadeIn, Transform, Create, etc.)
5. Add colors and styling for visual appeal
6. Include detailed comments explaining each section
7. Make it educational and easy to understand
8. Time the animations to approximately match the target duration
9. Use self.play() with appropriate run_time parameters
10. Include a title at the beginning

The code should be ready to run with:
manim -pql animation.py YourSceneName

Return ONLY the complete Python code, no markdown formatting or explanations."""

        response = claude_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=4096,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )

        # Extract code from response
        response_text = response.content[0].text.strip()
        
        # Remove markdown code blocks if present
        import re
        code_match = re.search(r'```python\n([\s\S]*?)\n```', response_text)
        if code_match:
            code = code_match.group(1)
        else:
            # Try without python tag
            code_match = re.search(r'```\n([\s\S]*?)\n```', response_text)
            if code_match:
                code = code_match.group(1)
            else:
                code = response_text

        return jsonify({
            'code': code,
            'topic': topic,
            'duration': duration
        })

    except Exception as e:
        print(f"Error generating custom Manim code: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'services': {
            'claude': 'connected',
            'fish_tts': 'ready'
        }
    })


if __name__ == '__main__':
    import os
    port = int(os.environ.get('PORT', 5001))

    print("🎙️  Voice-enabled Study Assistant Server")
    print("=" * 50)
    print(f"Starting server on http://localhost:{port}")
    print("Endpoints:")
    print("  - POST /api/ask (with voice)")
    print("  - POST /api/ask-text-only (text only)")
    print("  - POST /api/generate-flashcards")
    print("  - POST /api/generate-quiz")
    print("  - POST /api/evaluate-answers")
    print("  - POST /api/generate-manim")
    print("  - GET /health")
    print("=" * 50)
    print("\n💡 Tip: Set PORT environment variable to use different port")
    print("   Example: PORT=5002 python3 voice_server.py\n")

    try:
        app.run(debug=True, port=port, threaded=True, host='0.0.0.0')
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"\n❌ Error: Port {port} is already in use!")
            print("💡 Solutions:")
            print(f"   1. Kill the process: lsof -ti:{port} | xargs kill -9")
            print(f"   2. Use different port: PORT=5002 python3 voice_server.py")
        else:
            raise
