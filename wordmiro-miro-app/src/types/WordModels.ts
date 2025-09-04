// WordMiro TypeScript Models - Ported from Swift

export enum RelationType {
  SYNONYM = 'synonym',
  ANTONYM = 'antonym',
  ASSOCIATE = 'associate',
  ETYMOLOGY = 'etymology',
  COLLOCATION = 'collocation'
}

export interface RelationTypeConfig {
  displayName: string;
  color: string;
  strokeStyle: 'solid' | 'dashed' | 'dotted';
}

export const RELATION_TYPE_CONFIGS: Record<RelationType, RelationTypeConfig> = {
  [RelationType.SYNONYM]: {
    displayName: 'Synonym',
    color: '#2563eb',
    strokeStyle: 'solid'
  },
  [RelationType.ANTONYM]: {
    displayName: 'Antonym',
    color: '#dc2626',
    strokeStyle: 'dashed'
  },
  [RelationType.ASSOCIATE]: {
    displayName: 'Associate',
    color: '#6b7280',
    strokeStyle: 'dotted'
  },
  [RelationType.ETYMOLOGY]: {
    displayName: 'Etymology',
    color: '#0d9488',
    strokeStyle: 'solid'
  },
  [RelationType.COLLOCATION]: {
    displayName: 'Collocation',
    color: '#4338ca',
    strokeStyle: 'solid'
  }
};

export interface WordNode {
  id: string;
  lemma: string;
  pos?: string;
  register?: string;
  explanationJA: string;
  exampleEN?: string;
  exampleJA?: string;
  x: number;
  y: number;
  expanded: boolean;
  ease: number;
  nextReviewAt?: Date;
  miroItemId?: string; // Miro board item ID for synchronization
}

export interface WordEdge {
  id: string;
  from: string; // WordNode ID
  to: string;   // WordNode ID
  type: RelationType;
  miroItemId?: string; // Miro connector ID for synchronization
}

// LLM API Request/Response types (ported from Swift)
export interface ExpandRequest {
  lemma: string;
  locale: string;
  maxRelated: number;
}

export interface RelatedWord {
  term: string;
  relation: string;
}

export interface ExpandResponse {
  lemma: string;
  pos?: string;
  register?: string;
  explanation_ja: string;
  example_en?: string;
  example_ja?: string;
  related: RelatedWord[];
}

// Miro-specific types
export interface MiroPosition {
  x: number;
  y: number;
}

export interface MiroStickyNote {
  id: string;
  content: string;
  position: MiroPosition;
  color: string;
  shape: 'square' | 'rectangle';
}

export interface MiroConnector {
  id: string;
  start: {
    item: string;
  };
  end: {
    item: string;
  };
  style: {
    strokeColor: string;
    strokeStyle: 'normal' | 'dashed' | 'dotted';
    strokeWidth: number;
  };
}

// WordMiro Graph structure
export interface WordGraph {
  nodes: Map<string, WordNode>;
  edges: Map<string, WordEdge>;
  rootNodeId?: string;
}

// Utility functions
export function createWordNode(
  lemma: string,
  explanationJA: string,
  pos?: string,
  register?: string
): WordNode {
  return {
    id: crypto.randomUUID(),
    lemma: lemma.toLowerCase().trim(),
    pos,
    register,
    explanationJA,
    x: 0,
    y: 0,
    expanded: false,
    ease: 2.3,
  };
}

export function createWordEdge(
  from: string,
  to: string,
  type: RelationType
): WordEdge {
  return {
    id: crypto.randomUUID(),
    from,
    to,
    type,
  };
}

// Export data for JSON serialization (ported from Swift exportData)
export function exportWordNode(node: WordNode): Record<string, any> {
  const data: Record<string, any> = {
    id: node.id,
    lemma: node.lemma,
    explanation_ja: node.explanationJA,
    x: node.x,
    y: node.y,
    expanded: node.expanded,
    ease: node.ease,
  };

  if (node.pos) data.pos = node.pos;
  if (node.register) data.register = node.register;
  if (node.exampleEN) data.example_en = node.exampleEN;
  if (node.exampleJA) data.example_ja = node.exampleJA;
  if (node.nextReviewAt) {
    data.next_review_at = node.nextReviewAt.toISOString();
  }
  if (node.miroItemId) data.miro_item_id = node.miroItemId;

  return data;
}

export function exportWordEdge(edge: WordEdge): Record<string, any> {
  return {
    id: edge.id,
    from: edge.from,
    to: edge.to,
    type: edge.type,
    miro_item_id: edge.miroItemId,
  };
}