// Note Assistant - Context-aware assistant for individual notebooks

document.addEventListener('DOMContentLoaded', async function() {
    // Get elements
    const claudeContainer = document.getElementById('claudeAskContainer');
    const minimizeBtn = document.getElementById('minimizeBtn');
    const claudeHeader = document.querySelector('.claude-header');
    const sendBtn = document.getElementById('sendBtn');
    const claudeInput = document.getElementById('claudeInput');
    const claudeMessages = document.getElementById('claudeMessages');

    let isLearning = true;
    let isProcessing = false;

    // Initialize Claude service with correct config path
    await initClaudeService('../config.json');

    // Extract notebook content and "teach" the assistant
    async function learnNotebookContent() {
        const notebookPage = document.querySelector('.notebook-page');
        if (!notebookPage) {
            console.error('Notebook page not found');
            return;
        }

        // Extract all text content from the notebook
        const title = document.querySelector('.notebook-header h1')?.textContent || 'Unknown';
        const subtitle = document.querySelector('.notebook-header .subtitle')?.textContent || '';

        // Get all sections
        const sections = [];
        document.querySelectorAll('.section').forEach(section => {
            const heading = section.querySelector('h2')?.textContent || '';
            const content = section.innerText;
            sections.push(`## ${heading}\n${content}`);
        });

        const fullContent = sections.join('\n\n');

        // Create a comprehensive system prompt
        const systemPrompt = `You are a helpful study assistant. The student is currently reading their notes titled "${title}".

Here is the complete content of their notes:

# ${title}
${subtitle}

${fullContent}

Your role is to:
1. Help the student understand the material in these notes
2. Answer questions based on the content provided
3. Explain concepts in a clear, educational way
4. Provide examples when helpful
5. Ask clarifying questions if needed

Important: Base your answers primarily on the content provided in these notes. If a question goes beyond the notes, you can provide additional context but make it clear what's from the notes vs. additional information.

Be friendly, encouraging, and focused on helping the student learn!`;

        // Set the context in Claude service
        if (claudeService) {
            claudeService.setContext(systemPrompt);
            console.log('Assistant has learned the notebook content!');
        }

        isLearning = false;

        // Clear the messages and add a welcome message
        claudeMessages.innerHTML = '';
        addBotMessage(`Hi! I've learned all about "${title}". I'm ready to help you understand this material. Ask me anything!`);
    }

    // Learn the content when page loads
    addBotMessage('Just a moment, I\'m reading through your notes...');
    try {
        await learnNotebookContent();
    } catch (error) {
        console.error('Error learning notebook content:', error);
        addBotMessage('I had trouble reading the notes, but I\'ll do my best to help! What would you like to know?');
        isLearning = false;
    }

    // Toggle minimize/maximize
    function toggleClaudeWindow() {
        claudeContainer.classList.toggle('minimized');
        if (claudeContainer.classList.contains('minimized')) {
            minimizeBtn.textContent = '+';
        } else {
            minimizeBtn.textContent = '−';
        }
    }

    // Event listeners for minimize
    minimizeBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        toggleClaudeWindow();
    });

    claudeHeader.addEventListener('click', function() {
        if (claudeContainer.classList.contains('minimized')) {
            toggleClaudeWindow();
        }
    });

    // Add user message
    function addUserMessage(text) {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'claude-message user-message';
        const p = document.createElement('p');
        p.textContent = text;
        messageDiv.appendChild(p);
        claudeMessages.appendChild(messageDiv);
        scrollToBottom();
    }

    // Add bot message
    function addBotMessage(text, isMarkdown = false) {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'claude-message bot-message';
        const p = document.createElement('p');

        if (isMarkdown) {
            // Simple markdown rendering for better formatting
            p.innerHTML = text
                .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                .replace(/\*(.*?)\*/g, '<em>$1</em>')
                .replace(/\n/g, '<br>');
        } else {
            p.textContent = text;
        }

        messageDiv.appendChild(p);
        claudeMessages.appendChild(messageDiv);
        scrollToBottom();
    }

    // Add typing indicator
    function addTypingIndicator() {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'claude-message bot-message typing-indicator';
        messageDiv.id = 'typing-indicator';
        messageDiv.innerHTML = '<p>Thinking<span class="dots"><span>.</span><span>.</span><span>.</span></span></p>';
        claudeMessages.appendChild(messageDiv);
        scrollToBottom();
        return messageDiv;
    }

    // Remove typing indicator
    function removeTypingIndicator() {
        const indicator = document.getElementById('typing-indicator');
        if (indicator) {
            indicator.remove();
        }
    }

    // Scroll to bottom of messages
    function scrollToBottom() {
        claudeMessages.scrollTop = claudeMessages.scrollHeight;
    }

    // Handle sending messages
    async function sendMessage() {
        const message = claudeInput.value.trim();
        if (message === '' || isProcessing || isLearning) return;

        // Check if Claude service is initialized
        if (!claudeService) {
            addBotMessage('Sorry, the assistant is not ready yet. Please refresh the page and try again.');
            return;
        }

        // Add user message
        addUserMessage(message);
        claudeInput.value = '';
        isProcessing = true;
        sendBtn.disabled = true;
        claudeInput.disabled = true;

        // Add typing indicator
        const typingIndicator = addTypingIndicator();

        try {
            // Call Claude API with the question
            const response = await claudeService.askClaude(message, { useHistory: true });

            // Remove typing indicator and add response
            removeTypingIndicator();
            addBotMessage(response, true);
        } catch (error) {
            console.error('Error getting response:', error);
            removeTypingIndicator();
            addBotMessage('I apologize, but I encountered an error. Please try again. Error: ' + error.message);
        } finally {
            isProcessing = false;
            sendBtn.disabled = false;
            claudeInput.disabled = false;
            claudeInput.focus();
        }
    }

    // Send message on button click
    sendBtn.addEventListener('click', sendMessage);

    // Send message on Enter key
    claudeInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    // Make Claude window draggable
    let isDragging = false;
    let currentX;
    let currentY;
    let initialX;
    let initialY;

    claudeHeader.addEventListener('mousedown', function(e) {
        if (e.target === minimizeBtn) return;

        isDragging = true;
        initialX = e.clientX - claudeContainer.offsetLeft;
        initialY = e.clientY - claudeContainer.offsetTop;
        claudeHeader.style.cursor = 'grabbing';
    });

    document.addEventListener('mousemove', function(e) {
        if (isDragging) {
            e.preventDefault();
            currentX = e.clientX - initialX;
            currentY = e.clientY - initialY;

            // Keep within viewport
            const maxX = window.innerWidth - claudeContainer.offsetWidth;
            const maxY = window.innerHeight - claudeContainer.offsetHeight;

            currentX = Math.max(0, Math.min(currentX, maxX));
            currentY = Math.max(0, Math.min(currentY, maxY));

            claudeContainer.style.right = 'auto';
            claudeContainer.style.bottom = 'auto';
            claudeContainer.style.left = currentX + 'px';
            claudeContainer.style.top = currentY + 'px';
        }
    });

    document.addEventListener('mouseup', function() {
        isDragging = false;
        claudeHeader.style.cursor = 'pointer';
    });
});
