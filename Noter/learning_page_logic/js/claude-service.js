// Claude API Service
class ClaudeService {
  constructor(apiKey) {
    this.apiKey = apiKey;
    this.baseURL = 'https://api.anthropic.com/v1/messages';
    this.model = 'claude-3-5-sonnet-20241022';
    this.conversationHistory = [];
    this.systemContext = '';
  }

  // Set the system context (e.g., notebook content)
  setContext(context) {
    this.systemContext = context;
    this.conversationHistory = []; // Reset conversation when context changes
  }

  // Clear conversation history
  clearHistory() {
    this.conversationHistory = [];
  }

  // Ask Claude with conversation history
  async askClaude(question, options = {}) {
    const { useHistory = true, systemPrompt = '' } = options;

    const headers = {
      'Content-Type': 'application/json',
      'x-api-key': this.apiKey,
      'anthropic-version': '2023-06-01'
    };

    // Build messages array
    const messages = useHistory ? [...this.conversationHistory] : [];

    // Add the current question
    messages.push({
      role: 'user',
      content: question
    });

    // Build the request body
    const body = {
      model: this.model,
      max_tokens: 4096,
      messages: messages
    };

    // Add system prompt if provided or if there's context
    const finalSystemPrompt = systemPrompt || this.systemContext;
    if (finalSystemPrompt) {
      body.system = finalSystemPrompt;
    }

    try {
      const response = await fetch(this.baseURL, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(body)
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`API request failed: ${response.status} - ${errorText}`);
      }

      const data = await response.json();
      const assistantResponse = data.content[0].text;

      // Update conversation history if using history
      if (useHistory) {
        this.conversationHistory.push({
          role: 'user',
          content: question
        });
        this.conversationHistory.push({
          role: 'assistant',
          content: assistantResponse
        });
      }

      return assistantResponse;
    } catch (error) {
      console.error('Error calling Claude API:', error);
      throw error;
    }
  }
}

// Initialize the service (API key will be loaded from config)
let claudeService = null;

async function initClaudeService(configPath = '../config.json') {
  try {
    const response = await fetch(configPath);
    const config = await response.json();
    claudeService = new ClaudeService(config.claude.apiKey);
    return true;
  } catch (error) {
    console.error('Failed to initialize Claude service:', error);
    return false;
  }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ClaudeService, initClaudeService };
}
