// Dashboard Assistant - General-purpose study assistant

document.addEventListener('DOMContentLoaded', async function() {
    // Get elements
    const claudeContainer = document.getElementById('claudeAskContainer');
    const minimizeBtn = document.getElementById('minimizeBtn');
    const claudeHeader = document.querySelector('.claude-header');
    const sendBtn = document.getElementById('sendBtn');
    const claudeInput = document.getElementById('claudeInput');
    const claudeMessages = document.getElementById('claudeMessages');

    let isProcessing = false;

    // Initialize Claude service with correct config path
    await initClaudeService('config/config.json');

    // Set up general study assistant context
    const systemPrompt = `You are a helpful and encouraging study assistant. You help students organize their learning, understand concepts, and stay motivated.

The student is currently on their notes dashboard where they can see all their study notes. They have notes on various topics.

Your role is to:
1. Help them think about their study goals and organization
2. Provide general study advice and learning strategies
3. Answer questions about effective note-taking and studying
4. Encourage them to explore their notes
5. Be supportive and motivating

When they click on a specific note, a specialized assistant will help them with that specific topic. For now, focus on being a general study companion.

Be friendly, concise, and helpful!`;

    if (claudeService) {
        claudeService.setContext(systemPrompt);
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
        if (message === '' || isProcessing) return;

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

    // Add some helpful suggestions after a short delay
    setTimeout(() => {
        if (claudeMessages.children.length === 1) { // Only the welcome message
            addBotMessage('Try asking me about study strategies, or click on a note to dive into a specific topic!');
        }
    }, 3000);
});
