// LLM Service - Ported from Swift WordMiro implementation
import { ExpandRequest, ExpandResponse, RelatedWord, RelationType } from '../types/WordModels';

interface ValidationStats {
  totalRequests: number;
  successfulValidations: number;
  repairedResponses: number;
  failedValidations: number;
  totalResponseTime: number;
  averageExplanationLength: number;
  averageRelatedCount: number;
}

interface LLMProvider {
  name: string;
  endpoint: string;
  model: string;
  temperature: number;
}

const OPENAI_PROVIDER: LLMProvider = {
  name: 'OpenAI',
  endpoint: 'https://api.openai.com/v1/chat/completions',
  model: 'gpt-4o-mini',
  temperature: 0.3,
};

const ANTHROPIC_PROVIDER: LLMProvider = {
  name: 'Anthropic',
  endpoint: 'https://api.anthropic.com/v1/messages',
  model: 'claude-3-haiku-20240307',
  temperature: 0.2,
};

export class LLMService {
  private validationStats: ValidationStats = {
    totalRequests: 0,
    successfulValidations: 0,
    repairedResponses: 0,
    failedValidations: 0,
    totalResponseTime: 0,
    averageExplanationLength: 0,
    averageRelatedCount: 0,
  };

  private currentProvider: LLMProvider = OPENAI_PROVIDER;
  private apiKey: string;

  constructor(apiKey: string, provider: 'openai' | 'anthropic' = 'openai') {
    this.apiKey = apiKey;
    this.currentProvider = provider === 'openai' ? OPENAI_PROVIDER : ANTHROPIC_PROVIDER;
  }

  // Main expand method - creates word expansion request
  async expandWord(lemma: string, maxRelated: number = 12): Promise<ExpandResponse> {
    const request: ExpandRequest = {
      lemma: lemma.toLowerCase().trim(),
      locale: 'ja',
      maxRelated,
    };

    const startTime = Date.now();
    this.validationStats.totalRequests++;

    try {
      const response = await this.callLLM(request);
      const validatedResponse = await this.validateAndRepairResponse(response, request);
      
      const responseTime = Date.now() - startTime;
      this.updateStats(validatedResponse, responseTime);
      
      return validatedResponse;
    } catch (error) {
      this.validationStats.failedValidations++;
      console.error('LLM expand word failed:', error);
      throw error;
    }
  }

  // Call LLM API with proper formatting
  private async callLLM(request: ExpandRequest): Promise<ExpandResponse> {
    const systemPrompt = this.buildSystemPrompt();
    const userPrompt = this.buildUserPrompt(request);

    if (this.currentProvider.name === 'OpenAI') {
      return this.callOpenAI(systemPrompt, userPrompt);
    } else {
      return this.callAnthropic(systemPrompt, userPrompt);
    }
  }

  private async callOpenAI(systemPrompt: string, userPrompt: string): Promise<ExpandResponse> {
    const response = await fetch(this.currentProvider.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model: this.currentProvider.model,
        temperature: this.currentProvider.temperature,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        response_format: { type: 'json_object' },
      }),
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    return JSON.parse(data.choices[0].message.content);
  }

  private async callAnthropic(systemPrompt: string, userPrompt: string): Promise<ExpandResponse> {
    const response = await fetch(this.currentProvider.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: this.currentProvider.model,
        max_tokens: 1000,
        temperature: this.currentProvider.temperature,
        system: systemPrompt,
        messages: [{ role: 'user', content: userPrompt }],
      }),
    });

    if (!response.ok) {
      throw new Error(`Anthropic API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    const content = data.content[0].text;
    
    // Extract JSON from response
    const jsonMatch = content.match(/\{.*\}/s);
    if (!jsonMatch) {
      throw new Error('No JSON found in Anthropic response');
    }
    
    return JSON.parse(jsonMatch[0]);
  }

  // Build system prompt for consistent LLM behavior
  private buildSystemPrompt(): string {
    return `You are a vocabulary learning assistant for IELTS Reading 7.5-8.0 level learners.

Generate vocabulary expansion in JSON format with these requirements:

1. explanation_ja: 350-450 characters of clear Japanese explanation
2. related: Array of related words (max 12 items, max 3 per type)
3. Relation types: ${Object.values(RelationType).join(', ')}
4. Include pos (part of speech) and register (formality level) when relevant
5. Provide example_en and example_ja when helpful

Response must be valid JSON matching this schema:
{
  "lemma": "string",
  "pos": "string (optional)",
  "register": "string (optional)", 
  "explanation_ja": "string (350-450 chars)",
  "example_en": "string (optional)",
  "example_ja": "string (optional)",
  "related": [
    {
      "term": "string",
      "relation": "synonym|antonym|associate|etymology|collocation"
    }
  ]
}`;
  }

  private buildUserPrompt(request: ExpandRequest): string {
    return `Expand the word "${request.lemma}" for Japanese IELTS learners.
    
Requirements:
- Target level: IELTS Reading 7.5-8.0
- Max related words: ${request.maxRelated}
- Language: Japanese explanations
- Focus on academic/formal usage contexts

Please provide the expansion in the specified JSON format.`;
  }

  // Validate and repair LLM response
  private async validateAndRepairResponse(
    response: ExpandResponse,
    request: ExpandRequest
  ): Promise<ExpandResponse> {
    let repaired = false;
    
    // Validate explanation length (350-450 characters)
    if (!response.explanation_ja || 
        response.explanation_ja.length < 300 || 
        response.explanation_ja.length > 500) {
      console.warn('Explanation length out of range, attempting repair');
      response.explanation_ja = await this.repairExplanation(request.lemma, response.explanation_ja);
      repaired = true;
    }

    // Validate related words count and types
    if (!response.related || response.related.length === 0) {
      console.warn('No related words found, attempting repair');
      response.related = await this.repairRelatedWords(request.lemma);
      repaired = true;
    }

    // Validate relation types
    response.related = response.related.filter(word => {
      const validType = Object.values(RelationType).includes(word.relation as RelationType);
      if (!validType) {
        console.warn(`Invalid relation type: ${word.relation}`);
      }
      return validType;
    }).slice(0, request.maxRelated);

    // Enforce max 3 per relation type
    const relationCounts: Record<string, number> = {};
    response.related = response.related.filter(word => {
      const count = relationCounts[word.relation] || 0;
      if (count >= 3) return false;
      relationCounts[word.relation] = count + 1;
      return true;
    });

    if (repaired) {
      this.validationStats.repairedResponses++;
    } else {
      this.validationStats.successfulValidations++;
    }

    return response;
  }

  private async repairExplanation(lemma: string, originalExplanation?: string): Promise<string> {
    const prompt = `Create a 350-450 character Japanese explanation for the English word "${lemma}" suitable for IELTS 7.5-8.0 level learners. ${originalExplanation ? `Improve this explanation: ${originalExplanation}` : ''}`;
    
    // Simple repair - in production, this would call LLM again
    return originalExplanation && originalExplanation.length > 0 
      ? originalExplanation.substring(0, 450)
      : `「${lemma}」は英語の重要な語彙です。学術的な文脈でよく使用され、IELTS試験においても頻出します。正確な意味と用法を理解することが重要です。`;
  }

  private async repairRelatedWords(lemma: string): Promise<RelatedWord[]> {
    // Fallback related words - in production, this would call LLM again
    return [
      { term: `${lemma}_synonym`, relation: RelationType.SYNONYM },
      { term: `${lemma}_related`, relation: RelationType.ASSOCIATE },
    ];
  }

  private updateStats(response: ExpandResponse, responseTime: number): void {
    this.validationStats.totalResponseTime += responseTime;
    
    const explanationLength = response.explanation_ja?.length || 0;
    const relatedCount = response.related?.length || 0;
    
    // Update rolling averages
    const total = this.validationStats.totalRequests;
    this.validationStats.averageExplanationLength = 
      (this.validationStats.averageExplanationLength * (total - 1) + explanationLength) / total;
    this.validationStats.averageRelatedCount = 
      (this.validationStats.averageRelatedCount * (total - 1) + relatedCount) / total;
  }

  // Public stats getter
  getValidationStats(): ValidationStats {
    return { ...this.validationStats };
  }

  // Provider switching
  switchProvider(provider: 'openai' | 'anthropic', apiKey: string): void {
    this.currentProvider = provider === 'openai' ? OPENAI_PROVIDER : ANTHROPIC_PROVIDER;
    this.apiKey = apiKey;
  }
}