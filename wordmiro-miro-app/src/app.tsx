import * as React from 'react';
import { createRoot } from 'react-dom/client';
import { LLMService } from './services/LLMService';
import { MiroWordService } from './services/MiroWordService';

import '../src/assets/style.css';

const App: React.FC = () => {
  const [word, setWord] = React.useState<string>('');
  const [apiKey, setApiKey] = React.useState<string>('');
  const [provider, setProvider] = React.useState<'openai' | 'anthropic'>('openai');
  const [isExpanding, setIsExpanding] = React.useState<boolean>(false);
  const [miroWordService, setMiroWordService] = React.useState<MiroWordService | null>(null);

  // Initialize services
  React.useEffect(() => {
    const initializeServices = async () => {
      try {
        if (apiKey && !miroWordService) {
          const llmService = new LLMService(apiKey, provider);
          const wordService = new MiroWordService(miro, llmService);
          await wordService.initialize();
          setMiroWordService(wordService);
          
          miro.board.notifications.showInfo('WordMiro services initialized!');
        }
      } catch (error) {
        console.error('Service initialization failed:', error);
        miro.board.notifications.showError('Failed to initialize services');
      }
    };

    initializeServices();
  }, [apiKey, provider]);

  const handleExpandWord = React.useCallback(
    async (event: React.FormEvent) => {
      event.preventDefault();
      
      if (!miroWordService) {
        miro.board.notifications.showError('Please configure API key first');
        return;
      }

      if (!word.trim()) {
        miro.board.notifications.showError('Please enter a word to expand');
        return;
      }

      setIsExpanding(true);

      try {
        const nodeId = await miroWordService.expandWordOnBoard(word.trim());
        miro.board.notifications.showInfo(`Successfully expanded: ${word}`);
        setWord(''); // Clear input
        
        // Focus on the created word tree  
        const wordGraph = miroWordService.getWordGraph();
        const rootNode = wordGraph.nodes.get(nodeId);
        if (rootNode && rootNode.miroItemId) {
          await miro.board.viewport.zoomTo([rootNode.miroItemId]);
        }
      } catch (error: any) {
        console.error('Word expansion failed:', error);
        miro.board.notifications.showError(`Failed to expand word: ${error?.message || 'Unknown error'}`);
      } finally {
        setIsExpanding(false);
      }
    },
    [word, miroWordService]
  );

  const handleClearBoard = React.useCallback(async () => {
    if (!miroWordService) return;

    try {
      await miroWordService.clearBoard();
      miro.board.notifications.showInfo('Board cleared successfully');
    } catch (error) {
      console.error('Clear board failed:', error);
      miro.board.notifications.showError('Failed to clear board');
    }
  }, [miroWordService]);

  const handleExportGraph = React.useCallback(() => {
    if (!miroWordService) return;

    try {
      const graphData = miroWordService.exportGraphData();
      
      // Create download
      const blob = new Blob([graphData], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `wordmiro-graph-${Date.now()}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      
      miro.board.notifications.showInfo('Graph data exported successfully');
    } catch (error) {
      console.error('Export failed:', error);
      miro.board.notifications.showError('Failed to export graph data');
    }
  }, [miroWordService]);

  return (
    <div className="grid wrapper">
      <div className="cs1 ce12">
        <h1>🌸 WordMiro</h1>
        <p>Create interactive vocabulary trees on your Miro board</p>
      </div>

      {/* API Configuration */}
      <div className="cs1 ce12">
        <div className="form-group">
          <label htmlFor="provider">LLM Provider</label>
          <select 
            id="provider" 
            className="input"
            value={provider} 
            onChange={(e) => setProvider(e.target.value as 'openai' | 'anthropic')}
          >
            <option value="openai">OpenAI (GPT-4)</option>
            <option value="anthropic">Anthropic (Claude)</option>
          </select>
        </div>
        
        <div className="form-group">
          <label htmlFor="apiKey">API Key</label>
          <input
            type="password"
            className="input"
            id="apiKey"
            placeholder={`Enter your ${provider.toUpperCase()} API key`}
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
          />
        </div>
      </div>

      {/* Word Expansion */}
      <div className="cs1 ce12">
        <form onSubmit={handleExpandWord}>
          <div className="form-group">
            <label htmlFor="word">Word to Expand</label>
            <input
              type="text"
              className="input"
              id="word"
              placeholder="Enter an English word (e.g., 'sophisticated')"
              value={word}
              onChange={(e) => setWord(e.target.value)}
              disabled={!miroWordService || isExpanding}
            />
          </div>
          <div className="form-group">
            <button 
              className="button button-primary" 
              type="submit"
              disabled={!miroWordService || isExpanding || !word.trim()}
            >
              {isExpanding ? '🔄 Creating Word Tree...' : '🌱 Expand Word'}
            </button>
          </div>
        </form>
      </div>

      {/* Actions */}
      {miroWordService && (
        <div className="cs1 ce12">
          <div className="form-group" style={{ display: 'flex', gap: '10px' }}>
            <button 
              className="button button-secondary" 
              onClick={handleClearBoard}
            >
              🗑️ Clear Board
            </button>
            <button 
              className="button button-secondary" 
              onClick={handleExportGraph}
            >
              📥 Export Graph
            </button>
          </div>
        </div>
      )}

      {/* Status */}
      <div className="cs1 ce12">
        <div style={{ 
          padding: '12px', 
          backgroundColor: miroWordService ? '#e6f7ff' : '#fff7e6',
          borderRadius: '4px',
          border: `1px solid ${miroWordService ? '#91d5ff' : '#ffd591'}`
        }}>
          <strong>Status:</strong> {
            miroWordService 
              ? '✅ Ready to create word trees!'
              : '⚠️ Please configure your API key to get started'
          }
        </div>
      </div>

      {/* Help */}
      <div className="cs1 ce12">
        <details style={{ marginTop: '20px' }}>
          <summary style={{ cursor: 'pointer', fontWeight: 'bold' }}>ℹ️ How to Use</summary>
          <div style={{ padding: '10px 0' }}>
            <ol>
              <li>Select your preferred LLM provider (OpenAI or Anthropic)</li>
              <li>Enter your API key (required for word expansion)</li>
              <li>Type an English word you want to explore</li>
              <li>Click "Expand Word" to create a vocabulary tree</li>
              <li>The app will create sticky notes showing:
                <ul>
                  <li>📝 Japanese explanations</li>
                  <li>🔗 Related words (synonyms, antonyms, etc.)</li>
                  <li>📚 Usage examples</li>
                </ul>
              </li>
            </ol>
            <p><strong>Target Level:</strong> IELTS Reading 7.5-8.0</p>
          </div>
        </details>
      </div>
    </div>
  );
};

const container = document.getElementById('root');
if (container) {
  const root = createRoot(container);
  root.render(<App />);
}
