// Notebook Script - Claude Ask Window Functionality

document.addEventListener('DOMContentLoaded', function() {
    // Get elements
    const claudeContainer = document.getElementById('claudeAskContainer');
    const minimizeBtn = document.getElementById('minimizeBtn');
    const claudeHeader = document.querySelector('.claude-header');
    const sendBtn = document.getElementById('sendBtn');
    const claudeInput = document.getElementById('claudeInput');
    const claudeMessages = document.getElementById('claudeMessages');

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
    function addBotMessage(text) {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'claude-message bot-message';
        const p = document.createElement('p');
        p.textContent = text;
        messageDiv.appendChild(p);
        claudeMessages.appendChild(messageDiv);
        scrollToBottom();
    }

    // Scroll to bottom of messages
    function scrollToBottom() {
        claudeMessages.scrollTop = claudeMessages.scrollHeight;
    }

    // Handle sending messages
    function sendMessage() {
        const message = claudeInput.value.trim();
        if (message === '') return;

        // Add user message
        addUserMessage(message);
        claudeInput.value = '';

        // Simulate typing indicator
        setTimeout(() => {
            const response = generateResponse(message.toLowerCase());
            addBotMessage(response);
        }, 800);
    }

    // Generate responses based on keywords
    function generateResponse(message) {
        // Pyramid-related questions
        if (message.includes('pyramid')) {
            return "The pyramids were built during the Old Kingdom period (ca 2575-2150 B.C.), often called the 'Age of the Pyramids.' The Great Pyramid of Khufu at Giza was about 480 feet tall and remained the world's tallest structure for nearly 4,000 years!";
        }

        // Pharaoh-related questions
        if (message.includes('pharaoh')) {
            return "Pharaohs were the rulers of ancient Egypt, considered both political leaders and divine beings. Famous pharaohs include Tutankhamun (the boy king), Hatshepsut (a female pharaoh), and Ramses II who built more monuments than any other pharaoh.";
        }

        // Nile-related questions
        if (message.includes('nile')) {
            return "The Nile River was the lifeblood of ancient Egypt! It flooded annually, leaving behind fertile soil. The flood cycle had three seasons: Akhet (flooding, June-September), Peret (growing, October-February), and Shemu (harvest, March-May).";
        }

        // Mummy/afterlife questions
        if (message.includes('mummy') || message.includes('mummif') || message.includes('afterlife')) {
            return "Ancient Egyptians believed in an afterlife that would be like their earthly life, but without sadness or illness. Mummification preserved the body so the soul could enter the afterlife. Tombs were filled with food, games, and even pets to accompany them!";
        }

        // God-related questions
        if (message.includes('god') || message.includes('goddess') || message.includes('ra') || message.includes('osiris') || message.includes('isis') || message.includes('anubis')) {
            return "Ancient Egypt had over 2,000 documented gods! Some key ones include: Ra (sun god), Osiris (ruler of the underworld), Isis (goddess of magic and healing), Anubis (guide of souls), Horus (falcon god of kingship), and Tefnut (rain goddess).";
        }

        // Timeline/history questions
        if (message.includes('when') || message.includes('timeline') || message.includes('history')) {
            return "Ancient Egypt lasted over 3,000 years! Major periods include: Early Dynastic (ca 3100 B.C.), Old Kingdom/Age of Pyramids (ca 2575 B.C.), Middle Kingdom (ca 1938 B.C.), and New Kingdom (ca 1540 B.C.) - the most prosperous period.";
        }

        // Daily life questions
        if (message.includes('life') || message.includes('live') || message.includes('farmer') || message.includes('work')) {
            return "Most ancient Egyptians were farmers living in mud brick houses near the Nile. They grew wheat, barley, lettuce, and papyrus. During flood season, when they couldn't farm, many worked building pyramids and monuments. They also enjoyed swimming, board games, music, and dancing!";
        }

        // Women's rights questions
        if (message.includes('women') || message.includes('female')) {
            return "Women in ancient Egypt had more freedom than in most other ancient cultures! They could be scribes, priests, and doctors, just like men. They had equal rights and could own homes and businesses. Hatshepsut even ruled as pharaoh for 21 years!";
        }

        // Construction/engineering questions
        if (message.includes('build') || message.includes('construct') || message.includes('how')) {
            return "The pyramids were engineering marvels! Stone blocks weighing 2-15 tons were precisely aligned to cardinal directions. The Great Pyramid took about 20 years to build with thousands of workers. During flood season, farmers joined the construction effort.";
        }

        // General/default responses
        const defaultResponses = [
            "That's an interesting question! Based on the notes, ancient Egypt was one of the world's most fascinating civilizations. What specific aspect would you like to know more about?",
            "Great question! Ancient Egypt's history spans over 3,000 years with incredible achievements in architecture, art, and government. Can you be more specific about what you'd like to learn?",
            "I'd be happy to help! The notes cover many topics about ancient Egypt including pyramids, daily life, religion, and the afterlife. What interests you most?",
            "Thanks for asking! Ancient Egypt had a rich culture and advanced society. Try asking about specific topics like pyramids, pharaohs, gods, the Nile, or daily life for detailed answers!"
        ];

        return defaultResponses[Math.floor(Math.random() * defaultResponses.length)];
    }

    // Send message on button click
    sendBtn.addEventListener('click', sendMessage);

    // Send message on Enter key
    claudeInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
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

    // Add some helpful prompts after initial load
    setTimeout(() => {
        addBotMessage("💡 Tip: Try asking me about pyramids, pharaohs, the Nile River, Egyptian gods, or daily life in ancient Egypt!");
    }, 2000);
});
