// Miro + WordMiro Integration Service
import { 
  WordNode, 
  WordEdge, 
  WordGraph, 
  RelationType, 
  RELATION_TYPE_CONFIGS,
  createWordNode,
  createWordEdge,
  MiroPosition,
  MiroStickyNote,
  MiroConnector 
} from '../types/WordModels';
import { LLMService } from './LLMService';

export class MiroWordService {
  private miro: any; // Miro Web SDK
  private llmService: LLMService;
  private wordGraph: WordGraph;
  private currentBoardId?: string;

  constructor(miroSdk: any, llmService: LLMService) {
    this.miro = miroSdk;
    this.llmService = llmService;
    this.wordGraph = {
      nodes: new Map(),
      edges: new Map(),
    };
  }

  // Initialize with current Miro board
  async initialize(): Promise<void> {
    try {
      const boardInfo = await this.miro.board.getInfo();
      this.currentBoardId = boardInfo.id;
      console.log('MiroWordService initialized with board:', this.currentBoardId);
    } catch (error) {
      console.error('Failed to initialize MiroWordService:', error);
      throw error;
    }
  }

  // Main method: Create word expansion starting from a root word
  async expandWordOnBoard(lemma: string, position?: MiroPosition): Promise<string> {
    try {
      // 1. Get LLM expansion
      const expansion = await this.llmService.expandWord(lemma);
      
      // 2. Create root node
      const rootNode = createWordNode(
        expansion.lemma,
        expansion.explanation_ja,
        expansion.pos,
        expansion.register
      );
      
      // Set position (center if not specified)
      if (position) {
        rootNode.x = position.x;
        rootNode.y = position.y;
      } else {
        const viewport = await this.miro.board.viewport.get();
        rootNode.x = viewport.x + viewport.width / 2;
        rootNode.y = viewport.y + viewport.height / 2;
      }

      // 3. Create Miro sticky note for root
      const rootStickyNote = await this.createStickyNoteFromNode(rootNode, true);
      rootNode.miroItemId = rootStickyNote.id;
      rootNode.expanded = true;

      // 4. Add to graph
      this.wordGraph.nodes.set(rootNode.id, rootNode);
      this.wordGraph.rootNodeId = rootNode.id;

      // 5. Create related words and connections
      await this.createRelatedWordsOnBoard(rootNode, expansion.related);

      return rootNode.id;
    } catch (error) {
      console.error('Failed to expand word on board:', error);
      throw error;
    }
  }

  // Create related words as sticky notes and connect them
  private async createRelatedWordsOnBoard(
    parentNode: WordNode, 
    relatedWords: Array<{ term: string; relation: string }>
  ): Promise<void> {
    const relatedNodes: WordNode[] = [];
    const edges: WordEdge[] = [];

    // Create nodes for related words
    for (const related of relatedWords) {
      const relationType = related.relation as RelationType;
      if (!Object.values(RelationType).includes(relationType)) {
        console.warn(`Skipping invalid relation type: ${related.relation}`);
        continue;
      }

      // Create simple node (without full LLM expansion for now)
      const relatedNode = createWordNode(
        related.term,
        `Related to ${parentNode.lemma} (${RELATION_TYPE_CONFIGS[relationType].displayName})`
      );

      relatedNodes.push(relatedNode);

      // Create edge
      const edge = createWordEdge(parentNode.id, relatedNode.id, relationType);
      edges.push(edge);
    }

    // Calculate positions in a circle around parent
    const radius = 250;
    const angleStep = (2 * Math.PI) / relatedNodes.length;

    for (let i = 0; i < relatedNodes.length; i++) {
      const node = relatedNodes[i];
      const angle = i * angleStep;
      
      node.x = parentNode.x + radius * Math.cos(angle);
      node.y = parentNode.y + radius * Math.sin(angle);

      // Create sticky note on Miro board
      const stickyNote = await this.createStickyNoteFromNode(node, false);
      node.miroItemId = stickyNote.id;

      // Add to graph
      this.wordGraph.nodes.set(node.id, node);
    }

    // Create connectors on Miro board
    for (const edge of edges) {
      const connector = await this.createConnectorFromEdge(edge);
      edge.miroItemId = connector.id;
      this.wordGraph.edges.set(edge.id, edge);
    }
  }

  // Create Miro sticky note from WordNode
  private async createStickyNoteFromNode(node: WordNode, isRoot: boolean): Promise<MiroStickyNote> {
    const config = isRoot 
      ? { color: 'light_yellow', shape: 'rectangle' as const }
      : { color: 'light_blue', shape: 'square' as const };

    const content = this.formatNodeContent(node);

    const stickyNote = await this.miro.board.createStickyNote({
      content,
      shape: config.shape,
      style: {
        fillColor: config.color,
        textAlign: 'center',
        textAlignVertical: 'middle',
      },
      x: node.x,
      y: node.y,
      width: isRoot ? 300 : 200,
      height: isRoot ? 200 : 150,
    });

    return {
      id: stickyNote.id,
      content,
      position: { x: node.x, y: node.y },
      color: config.color,
      shape: config.shape,
    };
  }

  // Create Miro connector from WordEdge
  private async createConnectorFromEdge(edge: WordEdge): Promise<MiroConnector> {
    const fromNode = this.wordGraph.nodes.get(edge.from);
    const toNode = this.wordGraph.nodes.get(edge.to);

    if (!fromNode || !toNode || !fromNode.miroItemId || !toNode.miroItemId) {
      throw new Error('Cannot create connector: missing nodes or Miro IDs');
    }

    const config = RELATION_TYPE_CONFIGS[edge.type];
    
    const connector = await this.miro.board.createConnector({
      start: {
        item: fromNode.miroItemId,
      },
      end: {
        item: toNode.miroItemId,
      },
      style: {
        strokeColor: config.color,
        strokeStyle: config.strokeStyle === 'solid' ? 'normal' : config.strokeStyle,
        strokeWidth: 2,
      },
      captions: [{
        content: config.displayName,
        position: 0.5,
      }],
    });

    return {
      id: connector.id,
      start: { item: fromNode.miroItemId },
      end: { item: toNode.miroItemId },
      style: {
        strokeColor: config.color,
        strokeStyle: config.strokeStyle === 'solid' ? 'normal' : config.strokeStyle,
        strokeWidth: 2,
      },
    };
  }

  // Format node content for Miro sticky note
  private formatNodeContent(node: WordNode): string {
    let content = `**${node.lemma.toUpperCase()}**\n\n`;
    
    if (node.pos) {
      content += `*${node.pos}*\n`;
    }
    
    content += node.explanationJA;
    
    if (node.exampleEN) {
      content += `\n\n📝 ${node.exampleEN}`;
    }

    return content;
  }

  // Expand an existing node (when user clicks on it)
  async expandExistingNode(nodeId: string): Promise<void> {
    const node = this.wordGraph.nodes.get(nodeId);
    if (!node || node.expanded) {
      return;
    }

    try {
      const expansion = await this.llmService.expandWord(node.lemma);
      
      // Update node with full expansion data
      node.explanationJA = expansion.explanation_ja;
      node.pos = expansion.pos;
      node.register = expansion.register;
      node.exampleEN = expansion.example_en;
      node.exampleJA = expansion.example_ja;
      node.expanded = true;

      // Update Miro sticky note
      if (node.miroItemId) {
        await this.updateStickyNoteContent(node.miroItemId, this.formatNodeContent(node));
      }

      // Create related words if they exist
      if (expansion.related && expansion.related.length > 0) {
        await this.createRelatedWordsOnBoard(node, expansion.related);
      }
    } catch (error) {
      console.error('Failed to expand existing node:', error);
      throw error;
    }
  }

  // Update Miro sticky note content
  private async updateStickyNoteContent(miroItemId: string, content: string): Promise<void> {
    await this.miro.board.get({ id: miroItemId }).then((item: any) => {
      return item.sync({ content });
    });
  }

  // Get current word graph state
  getWordGraph(): WordGraph {
    return {
      nodes: new Map(this.wordGraph.nodes),
      edges: new Map(this.wordGraph.edges),
      rootNodeId: this.wordGraph.rootNodeId,
    };
  }

  // Clear current graph and Miro board items
  async clearBoard(): Promise<void> {
    try {
      // Delete all items created by this service
      const itemsToDelete = [];
      
      for (const node of this.wordGraph.nodes.values()) {
        if (node.miroItemId) {
          itemsToDelete.push(node.miroItemId);
        }
      }

      for (const edge of this.wordGraph.edges.values()) {
        if (edge.miroItemId) {
          itemsToDelete.push(edge.miroItemId);
        }
      }

      if (itemsToDelete.length > 0) {
        await this.miro.board.remove(itemsToDelete);
      }

      // Clear local graph
      this.wordGraph.nodes.clear();
      this.wordGraph.edges.clear();
      this.wordGraph.rootNodeId = undefined;
    } catch (error) {
      console.error('Failed to clear board:', error);
      throw error;
    }
  }

  // Export graph data (for backup/sharing)
  exportGraphData(): string {
    const exportData = {
      nodes: Array.from(this.wordGraph.nodes.values()),
      edges: Array.from(this.wordGraph.edges.values()),
      rootNodeId: this.wordGraph.rootNodeId,
      boardId: this.currentBoardId,
      timestamp: new Date().toISOString(),
    };

    return JSON.stringify(exportData, null, 2);
  }
}