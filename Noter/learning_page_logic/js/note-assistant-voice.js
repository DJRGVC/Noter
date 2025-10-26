// Note Assistant with Voice - Context-aware assistant with TTS

document.addEventListener('DOMContentLoaded', async function() {
    // Get elements
    const claudeContainer = document.getElementById('claudeAskContainer');
    const minimizeBtn = document.getElementById('minimizeBtn');
    const claudeHeader = document.querySelector('.claude-header');
    const sendBtn = document.getElementById('sendBtn');
    const claudeInput = document.getElementById('claudeInput');
    const claudeMessages = document.getElementById('claudeMessages');
    const voiceToggle = document.getElementById('voiceToggle');

    let isLearning = true;
    let isProcessing = false;

    // Initialize Voice service (will auto-detect backend)
    const backendReady = await initVoiceService();
    if (!backendReady) {
        console.warn('⚠️ Voice backend not available');
        console.warn('📝 Text-only mode active');
        console.warn('💡 To enable voice: Start voice_server.py in another terminal');

        // Optionally disable voice toggle if backend not available
        if (voiceToggle) {
            voiceToggle.disabled = true;
            voiceToggle.title = 'Voice unavailable - Start voice_server.py';
            voiceToggle.style.opacity = '0.5';
        }
    }

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

        // Get all sections - innerText preserves all content naturally
        const sections = [];
        document.querySelectorAll('.section').forEach(section => {
            const heading = section.querySelector('h2')?.textContent || '';
            // innerText gets all text content in document order without duplication
            const content = section.innerText.trim();
            sections.push(`## ${heading}\n\n${content}`);
        });

        const fullContent = sections.join('\n\n');

        // Create a comprehensive system prompt
        const systemPrompt = `You are a helpful study assistant. The student is currently reading their notes titled "${title}".

Here is the COMPLETE CONTENT of their notes (use this as your PRIMARY source for all answers):

=== START OF NOTES ===
# ${title}
${subtitle}

${fullContent}
=== END OF NOTES ===

CRITICAL INSTRUCTIONS:
1. **ALWAYS answer questions using the specific information from the notes above**
2. When asked "what does the note say about X", search the notes content and quote or summarize that specific section
3. If the student asks about topics in the notes (like "main crops", "Egyptian society", etc.), give them the SPECIFIC details from the notes
4. Keep answers conversational but factually accurate to the notes
5. If something isn't in the notes, say "The notes don't cover that specific topic, but I can tell you what they do say about [related topic]"

REMEMBER: These notes are your SOURCE OF TRUTH. Always refer back to them for answers. The student wants to learn what's IN these notes, not general knowledge.

Be friendly, encouraging, and focused on helping the student learn from THEIR notes! Keep responses concise and clear for voice output.`;

        // Set the context in voice service
        if (voiceService) {
            voiceService.setContext(systemPrompt);
            console.log('Assistant has learned the notebook content!');
        }

        isLearning = false;

        // Clear the messages and add a welcome message
        claudeMessages.innerHTML = '';
        addBotMessage(`Hi! I've learned all about "${title}". I'm ready to help you understand this material. Ask me anything!`, false, true);
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

    // Toggle voice
    if (voiceToggle) {
        voiceToggle.addEventListener('click', function() {
            if (voiceService) {
                const isEnabled = voiceService.toggleVoice();
                voiceToggle.textContent = isEnabled ? '🔊' : '🔇';
                voiceToggle.title = isEnabled ? 'Voice On' : 'Voice Off';

                // Stop current audio if disabling
                if (!isEnabled) {
                    voiceService.stopAudio();
                }
            }
        });
    }

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

    // Add bot message with streaming support
    function addBotMessage(text, isMarkdown = false, isComplete = false) {
        let messageDiv = claudeMessages.querySelector('.bot-message.streaming');

        if (!messageDiv || isComplete) {
            messageDiv = document.createElement('div');
            messageDiv.className = 'claude-message bot-message';
            if (!isComplete) {
                messageDiv.classList.add('streaming');
            }
            const p = document.createElement('p');
            messageDiv.appendChild(p);
            claudeMessages.appendChild(messageDiv);
        }

        const p = messageDiv.querySelector('p');

        if (isMarkdown) {
            // Simple markdown rendering for better formatting
            p.innerHTML = text
                .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                .replace(/\*(.*?)\*/g, '<em>$1</em>')
                .replace(/\n/g, '<br>');
        } else {
            p.textContent = text;
        }

        if (isComplete) {
            messageDiv.classList.remove('streaming');
        }

        scrollToBottom();
        return messageDiv;
    }

    // Update bot message (for streaming)
    function updateBotMessage(additionalText) {
        let messageDiv = claudeMessages.querySelector('.bot-message.streaming');
        if (!messageDiv) {
            return addBotMessage(additionalText, true, false);
        }

        const p = messageDiv.querySelector('p');
        const currentText = p.textContent;
        const newText = currentText + additionalText;

        // Simple markdown rendering
        p.innerHTML = newText
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            .replace(/\n/g, '<br>');

        scrollToBottom();
    }

    // Complete bot message
    function completeBotMessage() {
        const messageDiv = claudeMessages.querySelector('.bot-message.streaming');
        if (messageDiv) {
            messageDiv.classList.remove('streaming');
        }
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

        // Check if voice service is initialized
        if (!voiceService) {
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
            // Remove typing indicator before showing response
            setTimeout(() => removeTypingIndicator(), 300);

            // Start with empty message that will be updated
            addBotMessage('', true, false);

            // Use voice service (will stream both text and audio)
            await voiceService.askWithVoice(
                message,
                // onText callback
                (textChunk) => {
                    updateBotMessage(textChunk);
                },
                // onComplete callback
                (fullResponse) => {
                    completeBotMessage();
                },
                // onError callback
                (error) => {
                    removeTypingIndicator();
                    completeBotMessage();
                    addBotMessage('I apologize, but I encountered an error: ' + error, false, true);
                }
            );
        } catch (error) {
            console.error('Error getting response:', error);
            removeTypingIndicator();
            completeBotMessage();
            addBotMessage('I apologize, but I encountered an error. Please try again.', false, true);
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
        if (e.target === minimizeBtn || e.target === voiceToggle) return;

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
