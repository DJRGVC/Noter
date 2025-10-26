import anthropic
import os
from pathlib import Path
import argparse
import base64

class LectureNotesProcessor:
    
    def __init__(self, api_key=None):
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not self.api_key:
            raise ValueError("API key required. Set ANTHROPIC_API_KEY env var or pass api_key parameter")
        self.client = anthropic.Anthropic(api_key=self.api_key)
        
    def read_pdf_as_base64(self, pdf_path):
        with open(pdf_path, 'rb') as f:
            return base64.standard_b64encode(f.read()).decode('utf-8')
    
    def read_python_file(self, py_path):
        with open(py_path, 'r', encoding='utf-8') as f:
            return f.read()
    
    def craft_prompt(self, lecture_content, has_slides=False, code_content=None):
        
        prompt = f"""You are an expert web designer and educational content specialist. Transform this lecture transcript into a stunning, modern HTML document.

CRITICAL DESIGN REQUIREMENTS:

**Visual Design (PRIORITY):**
- Modern, premium aesthetic with beautiful typography
- Use a sophisticated color palette
- Add subtle gradients and shadows for depth
- Include smooth animations and transitions
- Implement a sticky navigation sidebar
- Use CSS Grid and Flexbox for modern layouts
- Add visual hierarchy with varied font sizes and weights
- Include decorative elements (subtle background patterns, accent lines)
- Make it look like a professional documentation site (think: Stripe, Vercel, or modern tech docs)

**Typography:**
- Use Inter, SF Pro, or system-ui font stack
- Large, bold headings (h1: 2.5rem+, h2: 2rem+)
- Generous line-height (1.6-1.8)
- Proper font weight variations (300 for body, 600+ for headings)
- Subtle text shadows or colors for depth

**Layout:**
- Fixed sidebar navigation on the left (20-25% width)
- Main content area with max-width 800px, centered
- Generous padding and whitespace
- Sticky table of contents with scroll spy
- Smooth scroll behavior

**Color & Style:**
- Dark mode friendly but with vibrant accents
- Code blocks: dark background with syntax highlighting colors
- Use colored badges/pills for important terms
- Subtle border-left accents on blockquotes and notes
- Box shadows on cards and containers
- Gradient backgrounds in header

**Interactive Elements:**
- Hover effects on links and navigation items
- Smooth scroll to anchors
- Expandable/collapsible sections if beneficial
- Active state highlighting in navigation

**Code Presentation:**
- Syntax highlighted code blocks with line numbers
- Dark theme (VS Code style)
- Copy button on code blocks (visual only, doesn't need to function)
- Language badge on top-right of code blocks

**Content Organization:**
{"- Seamlessly integrate PDF slide content into the narrative flow" if has_slides else ""}
{"- Present code examples in dedicated, beautifully styled sections" if code_content else ""}
- Key concepts in highlighted boxes/cards
- Definitions in distinct styled containers
- Examples in light-colored boxes
- Important notes in colored callout boxes

**Must Include:**
- Beautiful header with course title and lecture number
- Sticky table of contents with active section highlighting
- Summary/key takeaways in a special styled section
- Visual separators between major sections
- Breadcrumb or metadata at top
- Smooth animations on scroll

LECTURE CONTENT:
{lecture_content}
"""
        
        if code_content:
            prompt += f"""

CODE TO INTEGRATE:
```python
{code_content}
```
Present this code with beautiful syntax highlighting and context.
"""
        
        prompt += """

OUTPUT A COMPLETE HTML FILE that looks like it belongs on a premium educational platform. Make students WANT to study from these notes because they look so good. Think modern, clean, professional, and visually engaging."""
        
        return prompt
    
    def process_lecture(self, lecture_content, pdf_data=None, code_content=None, model="claude-sonnet-4-5-20250929"):
        
        messages_content = []
        
        if pdf_data:
            messages_content.append({
                "type": "document",
                "source": {
                    "type": "base64",
                    "media_type": "application/pdf",
                    "data": pdf_data
                }
            })
        
        prompt = self.craft_prompt(lecture_content, has_slides=(pdf_data is not None), code_content=code_content)
        messages_content.append({
            "type": "text",
            "text": prompt
        })
        
        try:
            message = self.client.messages.create(
                model=model,
                max_tokens=16000,
                temperature=0.3,
                messages=[
                    {
                        "role": "user",
                        "content": messages_content
                    }
                ]
            )
            
            html_content = message.content[0].text
            
            if html_content.startswith("```html"):
                html_content = html_content.split("```html")[1].split("```")[0].strip()
            elif html_content.startswith("```"):
                html_content = html_content.split("```")[1].split("```")[0].strip()
                
            return html_content
            
        except Exception as e:
            print(f"Error processing lecture: {str(e)}")
            raise
    
    def process_lecture_files(self, course_path, lecture_num):
        
        base_path = Path(course_path) / f"l{lecture_num}"
        
        txt_file = base_path.with_suffix('.txt')
        pdf_file = base_path.with_suffix('.pdf')
        py_file = base_path.with_suffix('.py')
        
        if not txt_file.exists():
            raise FileNotFoundError(f"Lecture transcript not found: {txt_file}")
        
        print(f"Processing lecture {lecture_num} from course: {course_path}")
        print(f"Transcript: {txt_file.name} ({'found' if txt_file.exists() else 'missing'})")
        print(f"Slides: {pdf_file.name} ({'found' if pdf_file.exists() else 'missing'})")
        print(f"Code: {py_file.name} ({'found' if py_file.exists() else 'missing'})")
        
        with open(txt_file, 'r', encoding='utf-8') as f:
            lecture_content = f.read()
        
        pdf_data = None
        if pdf_file.exists():
            print("Reading PDF slides...")
            pdf_data = self.read_pdf_as_base64(pdf_file)
        
        code_content = None
        if py_file.exists():
            print("Reading Python code...")
            code_content = self.read_python_file(py_file)
        
        print("Processing with Claude API...")
        html_content = self.process_lecture(lecture_content, pdf_data, code_content)
        
        output_file = base_path.with_suffix('.html')
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"✓ HTML file created: {output_file}")
        print(f"✓ Output size: {len(html_content)} characters")
        
        return output_file

def main():
    parser = argparse.ArgumentParser(description='Process lecture notes into HTML')
    parser.add_argument('--course', required=True, help='Course directory path')
    parser.add_argument('--lecture', required=True, help='Lecture number')
    parser.add_argument('--api-key', default="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",  help='Anthropic API key (optional if env var set)')
    
    args = parser.parse_args()
    
    try:
        processor = LectureNotesProcessor(api_key=args.api_key)
        output_file = processor.process_lecture_files(args.course, args.lecture)
        print(f"\n{'='*60}")
        print(f"Success! HTML generated: {output_file}")
        
    except Exception as e:
        print(f"\n{'='*60}")
        print(f"Error: {str(e)}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())