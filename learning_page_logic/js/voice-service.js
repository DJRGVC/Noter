// Voice Service - Handles streaming TTS from backend

class VoiceService {
  constructor(backendUrl = null) {
    // Auto-detect backend URL if not provided
    if (!backendUrl) {
      // Try common ports (5001 first since 5000 is often used by macOS AirPlay)
      this.backendUrl = null; // Will be set in initAudio after health check
      this.possibleBackendUrls = [
        'http://localhost:5001',
        'http://localhost:5000',
        'http://127.0.0.1:5001',
        'http://127.0.0.1:5000'
      ];
    } else {
      this.backendUrl = backendUrl;
      this.possibleBackendUrls = [backendUrl];
    }
    this.audioContext = null;
    this.audioQueue = [];
    this.isPlaying = false;
    this.currentSource = null;
    this.voiceEnabled = true;
    this.conversationHistory = [];
    this.systemContext = '';
    this.backendReady = false;
  }

  // Initialize audio context
  initAudio() {
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    }
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

  // Toggle voice on/off
  toggleVoice() {
    this.voiceEnabled = !this.voiceEnabled;
    return this.voiceEnabled;
  }

  // Play audio chunk
  async playAudioChunk(base64Audio) {
    this.initAudio();

    try {
      // Decode base64 to array buffer
      const binaryString = atob(base64Audio);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }

      // Decode audio data
      const audioBuffer = await this.audioContext.decodeAudioData(bytes.buffer);

      // Queue for playback
      this.audioQueue.push(audioBuffer);

      // Start playback if not already playing
      if (!this.isPlaying) {
        this.playNextInQueue();
      }
    } catch (error) {
      console.error('Error playing audio chunk:', error);
    }
  }

  // Play next audio buffer in queue
  playNextInQueue() {
    if (this.audioQueue.length === 0) {
      this.isPlaying = false;
      return;
    }

    this.isPlaying = true;
    const audioBuffer = this.audioQueue.shift();

    const source = this.audioContext.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(this.audioContext.destination);

    source.onended = () => {
      this.playNextInQueue();
    };

    source.start(0);
    this.currentSource = source;
  }

  // Stop audio playback
  stopAudio() {
    if (this.currentSource) {
      this.currentSource.stop();
      this.currentSource = null;
    }
    this.audioQueue = [];
    this.isPlaying = false;
  }

  // Ask question with voice response
  async askWithVoice(question, onText, onComplete, onError) {
    this.initAudio();
    this.stopAudio(); // Stop any previous audio

    let fullResponse = '';

    try {
      const response = await fetch(`${this.backendUrl}/api/ask`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          question: question,
          context: this.systemContext,
          history: this.conversationHistory
        })
      });

      if (!response.ok) {
        throw new Error(`Backend error: ${response.status}`);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n').filter(line => line.trim());

        for (const line of lines) {
          try {
            const data = JSON.parse(line);

            if (data.type === 'text') {
              fullResponse += data.content;
              if (onText) {
                onText(data.content);
              }
            } else if (data.type === 'audio' && this.voiceEnabled) {
              await this.playAudioChunk(data.content);
            } else if (data.type === 'error') {
              if (onError) {
                onError(data.content);
              }
            } else if (data.type === 'done') {
              // Update conversation history
              this.conversationHistory.push({
                role: 'user',
                content: question
              });
              this.conversationHistory.push({
                role: 'assistant',
                content: fullResponse
              });

              if (onComplete) {
                onComplete(fullResponse);
              }
            }
          } catch (e) {
            console.error('Error parsing chunk:', e);
          }
        }
      }
    } catch (error) {
      console.error('Error in askWithVoice:', error);
      if (onError) {
        onError(error.message);
      }
    }
  }

  // Ask question without voice (text only, faster)
  async askTextOnly(question, onText, onComplete, onError) {
    let fullResponse = '';

    try {
      const response = await fetch(`${this.backendUrl}/api/ask-text-only`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          question: question,
          context: this.systemContext,
          history: this.conversationHistory
        })
      });

      if (!response.ok) {
        throw new Error(`Backend error: ${response.status}`);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n').filter(line => line.trim());

        for (const line of lines) {
          try {
            const data = JSON.parse(line);

            if (data.type === 'text') {
              fullResponse += data.content;
              if (onText) {
                onText(data.content);
              }
            } else if (data.type === 'error') {
              if (onError) {
                onError(data.content);
              }
            } else if (data.type === 'done') {
              // Update conversation history
              this.conversationHistory.push({
                role: 'user',
                content: question
              });
              this.conversationHistory.push({
                role: 'assistant',
                content: fullResponse
              });

              if (onComplete) {
                onComplete(fullResponse);
              }
            }
          } catch (e) {
            console.error('Error parsing chunk:', e);
          }
        }
      }
    } catch (error) {
      console.error('Error in askTextOnly:', error);
      if (onError) {
        onError(error.message);
      }
    }
  }

  // Health check with auto-detection
  async checkHealth() {
    // If backend URL is already set, just check it
    if (this.backendUrl && this.backendReady) {
      try {
        const response = await fetch(`${this.backendUrl}/health`, {
          method: 'GET',
          cache: 'no-cache'
        });
        if (response.ok) {
          return await response.json();
        }
      } catch (error) {
        console.warn('Backend health check failed:', error);
      }
    }

    // Try to find a working backend URL
    console.log('🔍 Searching for voice backend...');
    for (const url of this.possibleBackendUrls) {
      try {
        console.log(`  Trying ${url}...`);
        const response = await fetch(`${url}/health`, {
          method: 'GET',
          cache: 'no-cache',
          signal: AbortSignal.timeout(2000) // 2 second timeout
        });

        if (response.ok) {
          const data = await response.json();
          if (data.status === 'healthy') {
            this.backendUrl = url;
            this.backendReady = true;
            console.log(`✅ Found backend at ${url}`);
            return data;
          }
        }
      } catch (error) {
        console.log(`  ❌ ${url} not available`);
        continue;
      }
    }

    console.error('❌ No backend found. Voice features disabled.');
    console.log('💡 Start backend with: python3 voice_server.py');
    return {
      status: 'error',
      error: 'Backend not found. Please start voice_server.py'
    };
  }
}

// Initialize the service
let voiceService = null;

async function initVoiceService(backendUrl = null) {
  voiceService = new VoiceService(backendUrl);

  // Check if backend is healthy (will auto-detect if URL not provided)
  const health = await voiceService.checkHealth();

  if (health.status === 'healthy') {
    console.log('✅ Voice service ready:', health);
    return true;
  } else {
    console.warn('⚠️ Voice service unavailable:', health.error);
    console.log('📝 Continuing in text-only mode...');
    return false;
  }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { VoiceService, initVoiceService };
}
