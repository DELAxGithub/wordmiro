# WordMiro BFF (Backend-for-Frontend) Implementation Guide

## Overview

This document provides the complete implementation specification for the WordMiro BFF service to replace direct LLM API calls from the client.

## Architecture Requirements

### 1. Technology Stack
- **Recommended**: Cloudflare Workers + Redis/KV Store
- **Alternative**: FastAPI + Redis + Docker
- **Deployment**: Auto-scaling serverless with global edge locations

### 2. Core Features
- JSON Schema validation with auto-repair pipeline
- Redis caching with ETags and TTL management
- Rate limiting per device/IP with quota management
- Anonymous device authentication with usage tracking
- Comprehensive audit logging and metrics

## API Specification

### POST /expand

**Request Format:**
```json
{
  "lemma": "ubiquitous",
  "locale": "ja",
  "max_related": 12
}
```

**Response Format (Success):**
```json
{
  "lemma": "ubiquitous",
  "pos": "adjective",
  "register": "ややフォーマル",
  "explanation_ja": "350-450文字の詳細説明...",
  "example_en": "English example sentence",
  "example_ja": "対応する日本語例文",
  "related": [
    {
      "term": "omnipresent",
      "relation": "synonym"
    }
  ],
  "metadata": {
    "cached": false,
    "validation_passed": true,
    "auto_repaired": false,
    "response_time_ms": 1250
  }
}
```

**Error Responses:**
```json
// 422 - Validation Failed
{
  "error": "validation_failed",
  "details": {
    "explanation_ja": "Too short (245 chars, minimum 350)",
    "related": "Too many synonym relations (4, maximum 3)"
  },
  "auto_repair_attempted": true,
  "auto_repair_success": false
}

// 429 - Rate Limited
{
  "error": "rate_limited",
  "limit": 60,
  "window": "1 minute",
  "retry_after": 45
}

// 500 - LLM Service Error
{
  "error": "llm_service_unavailable",
  "fallback_available": false,
  "retry_recommended": true
}
```

## JSON Schema Validation

### Schema Definition
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["lemma", "explanation_ja", "related"],
  "properties": {
    "lemma": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100,
      "pattern": "^[a-zA-Z\\s\\-']+$"
    },
    "explanation_ja": {
      "type": "string",
      "minLength": 350,
      "maxLength": 450
    },
    "related": {
      "type": "array",
      "maxItems": 12,
      "items": {
        "type": "object",
        "required": ["term", "relation"],
        "properties": {
          "term": {
            "type": "string",
            "minLength": 1,
            "maxLength": 50
          },
          "relation": {
            "enum": ["synonym", "antonym", "associate", "etymology", "collocation"]
          }
        }
      }
    },
    "pos": {
      "type": "string",
      "maxLength": 50
    },
    "register": {
      "type": "string",
      "maxLength": 50
    },
    "example_en": {
      "type": "string",
      "maxLength": 200
    },
    "example_ja": {
      "type": "string",
      "maxLength": 200
    }
  }
}
```

### Content Validation Rules

#### Explanation Quality
```typescript
function validateExplanationQuality(explanation: string): ValidationResult {
  const checks = [
    hasEtymologyInfo(explanation),
    hasUsageContext(explanation),
    hasNuanceDescription(explanation),
    hasFormalityLevel(explanation),
    avoidColloquialisms(explanation)
  ];
  
  const score = checks.filter(Boolean).length / checks.length;
  return {
    passed: score >= 0.8,
    score,
    issues: checks.map((passed, i) => !passed ? QUALITY_ISSUES[i] : null).filter(Boolean)
  };
}
```

#### Relationship Validation
```typescript
function validateRelationships(related: RelatedWord[]): ValidationResult {
  // Max 3 per relation type
  const typeCounts = groupBy(related, 'relation');
  const typeViolations = Object.entries(typeCounts)
    .filter(([type, words]) => words.length > 3)
    .map(([type, words]) => `${type}: ${words.length}/3`);
  
  // No duplicates
  const terms = related.map(w => w.term.toLowerCase());
  const duplicates = terms.filter((term, i) => terms.indexOf(term) !== i);
  
  // No self-references
  const selfRefs = related.filter(w => w.term.toLowerCase() === lemma.toLowerCase());
  
  return {
    passed: typeViolations.length === 0 && duplicates.length === 0 && selfRefs.length === 0,
    typeViolations,
    duplicates,
    selfReferences: selfRefs
  };
}
```

## Auto-Repair Pipeline

### Repair Strategies
```typescript
class AutoRepair {
  static async repairResponse(response: ExpandResponse): Promise<RepairResult> {
    const repairs: RepairAction[] = [];
    
    // Fix explanation length
    if (response.explanation_ja.length > 450) {
      response.explanation_ja = this.truncateAtSentence(response.explanation_ja, 450);
      repairs.push({ type: 'truncate_explanation', details: 'Shortened to 450 chars' });
    }
    
    if (response.explanation_ja.length < 350) {
      response.explanation_ja = await this.expandExplanation(response.explanation_ja, response.lemma);
      repairs.push({ type: 'expand_explanation', details: 'Added etymology and usage' });
    }
    
    // Fix relationship limits
    const typeGroups = groupBy(response.related, 'relation');
    for (const [type, words] of Object.entries(typeGroups)) {
      if (words.length > 3) {
        response.related = response.related.filter(w => 
          w.relation !== type || words.slice(0, 3).includes(w)
        );
        repairs.push({ type: 'limit_relations', details: `${type}: ${words.length} → 3` });
      }
    }
    
    // Remove duplicates
    const seen = new Set<string>();
    response.related = response.related.filter(w => {
      const key = w.term.toLowerCase();
      if (seen.has(key)) {
        repairs.push({ type: 'remove_duplicate', details: w.term });
        return false;
      }
      seen.add(key);
      return true;
    });
    
    return {
      success: true,
      response,
      repairs
    };
  }
}
```

## Caching Strategy

### Redis Cache Implementation
```typescript
class CacheManager {
  private redis: Redis;
  private ttl = 7 * 24 * 60 * 60; // 7 days
  
  async get(lemma: string, locale: string): Promise<CachedResponse | null> {
    const key = this.generateKey(lemma, locale);
    const cached = await this.redis.get(key);
    
    if (cached) {
      const response = JSON.parse(cached);
      response.metadata = { ...response.metadata, cached: true };
      return response;
    }
    
    return null;
  }
  
  async set(lemma: string, locale: string, response: ExpandResponse): Promise<void> {
    const key = this.generateKey(lemma, locale);
    const etag = this.generateETag(response);
    
    await this.redis.setex(key, this.ttl, JSON.stringify({
      ...response,
      etag,
      cached_at: new Date().toISOString()
    }));
  }
  
  private generateKey(lemma: string, locale: string): string {
    return `wordmiro:expand:${locale}:${lemma.toLowerCase()}`;
  }
  
  private generateETag(response: ExpandResponse): string {
    const content = `${response.lemma}-${response.explanation_ja.length}-${response.related.length}`;
    return createHash('md5').update(content).digest('hex');
  }
}
```

### Cache Headers
```typescript
// Request headers
{
  "If-None-Match": "\"abc123def456\""
}

// Response headers (cache hit)
{
  "ETag": "\"abc123def456\"",
  "Cache-Control": "public, max-age=604800",
  "X-Cache": "HIT",
  "X-Cache-Age": "3600"
}

// Response headers (cache miss)
{
  "ETag": "\"xyz789abc123\"",
  "Cache-Control": "public, max-age=604800", 
  "X-Cache": "MISS"
}
```

## Rate Limiting

### Implementation
```typescript
class RateLimiter {
  private redis: Redis;
  
  async checkRate(deviceId: string, ip: string): Promise<RateLimitResult> {
    const window = 60; // 1 minute
    const limit = 60; // requests per minute
    
    const key = `rate:${deviceId}:${Math.floor(Date.now() / (window * 1000))}`;
    const current = await this.redis.incr(key);
    await this.redis.expire(key, window);
    
    return {
      allowed: current <= limit,
      remaining: Math.max(0, limit - current),
      resetTime: Date.now() + (window * 1000),
      limit
    };
  }
}
```

### Rate Limiting Headers
```typescript
{
  "X-RateLimit-Limit": "60",
  "X-RateLimit-Remaining": "45",
  "X-RateLimit-Reset": "1692123456",
  "X-RateLimit-Window": "60"
}
```

## Device Authentication

### Anonymous Token System
```typescript
class DeviceAuth {
  static generateDeviceToken(): string {
    return `device_${crypto.randomUUID().replace(/-/g, '')}`;
  }
  
  static async validateToken(token: string): Promise<DeviceInfo> {
    if (!token.startsWith('device_')) {
      throw new Error('Invalid device token format');
    }
    
    return {
      deviceId: token,
      createdAt: new Date(),
      requestCount: await this.getRequestCount(token),
      quotaRemaining: await this.getQuotaRemaining(token)
    };
  }
}
```

## Monitoring & Telemetry

### Metrics Collection
```typescript
interface BFFMetrics {
  requests: {
    total: number;
    successful: number;
    failed: number;
    cached: number;
  };
  validation: {
    passed: number;
    failed: number;
    repaired: number;
    repairSuccessRate: number;
  };
  performance: {
    averageResponseTime: number;
    p95ResponseTime: number;
    cacheHitRate: number;
    llmResponseTime: number;
  };
  errors: {
    llmErrors: number;
    validationErrors: number;
    rateLimitErrors: number;
  };
}
```

### Audit Logging
```typescript
interface AuditLog {
  timestamp: string;
  deviceId: string;
  ip: string;
  lemma: string;
  responseTime: number;
  cached: boolean;
  validationPassed: boolean;
  autoRepaired: boolean;
  errorType?: string;
}
```

## Performance Targets

### SLA Requirements
- **P95 Response Time**: < 2.5s (uncached), < 400ms (cached)
- **Availability**: 99.9% uptime
- **Cache Hit Rate**: > 70%
- **Validation Success Rate**: > 95%
- **Auto-Repair Success Rate**: > 80%

### Scaling Targets
- **Request Volume**: 1000 requests/minute sustained
- **Concurrent Users**: 500 simultaneous users
- **Geographic Distribution**: < 200ms additional latency per region

## Deployment

### Cloudflare Workers (Recommended)
```yaml
name: wordmiro-bff
compatibility_date: "2024-08-19"

[env.production]
KV_NAMESPACES = [
  { binding = "CACHE", id = "your-kv-namespace-id" }
]

[env.production.vars]
OPENAI_API_KEY = "your-openai-key"
ANTHROPIC_API_KEY = "your-anthropic-key" 
RATE_LIMIT_PER_MINUTE = "60"
CACHE_TTL_SECONDS = "604800"
```

### FastAPI Alternative
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Client Integration

### Updated LLMService
```swift
func expandWord(lemma: String, locale: String = "ja") -> AnyPublisher<ExpandResponse, Error> {
    let request = ExpandRequest(
        lemma: lemma,
        locale: locale,
        maxRelated: 12
    )
    
    var urlRequest = URLRequest(url: URL(string: "\(bffBaseURL)/expand")!)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
    
    // Add ETag if cached response exists
    if let etag = getCachedETag(for: lemma, locale: locale) {
        urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
    }
    
    urlRequest.httpBody = try? JSONEncoder().encode(request)
    
    return URLSession.shared.dataTaskPublisher(for: urlRequest)
        .map(\.data)
        .decode(type: ExpandResponse.self, decoder: JSONDecoder())
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
}
```

## Security Considerations

### Data Privacy
- No personal information stored or logged
- Device tokens are anonymous and rotatable
- IP addresses hashed for rate limiting
- Audit logs anonymized after 30 days

### Request Validation
- Input sanitization for all parameters
- SQL injection prevention (parameterized queries)
- XSS prevention (output encoding)
- CSRF protection via device tokens

### Infrastructure Security
- HTTPS only (TLS 1.3)
- API key rotation every 90 days
- Redis AUTH enabled
- Environment variable secrets management

## Testing Strategy

### Load Testing
```bash
# Target: 1000 requests/minute sustained
artillery run --target https://bff.wordmiro.app load-test.yml

# Test cache performance
siege -c 100 -t 60s https://bff.wordmiro.app/expand

# Test rate limiting
hey -n 100 -c 10 -m POST https://bff.wordmiro.app/expand
```

### Quality Assurance
```typescript
const testCases = [
  { lemma: "ubiquitous", expectedLength: [350, 450] },
  { lemma: "serendipity", expectedRelations: ["<=12"] },
  { lemma: "ephemeral", expectedQuality: ["etymology", "usage"] }
];
```

## Cost Management

### Resource Optimization
- Cloudflare Workers: ~$5/month for 100k requests
- Redis caching: ~$10/month for 1GB data
- LLM API costs: $50-100/month (with 70% cache hit rate)

### Usage Monitoring
- Daily cost alerts at $10 threshold
- Weekly usage reports by device
- Monthly capacity planning reviews

## Migration Plan

### Phase 1: BFF Deployment (Week 1)
1. Deploy BFF service with basic /expand endpoint
2. Implement JSON validation and caching
3. Set up monitoring and alerting

### Phase 2: Client Migration (Week 2)
1. Update iOS client to use BFF endpoint
2. Remove API key management from client
3. Test with limited user base

### Phase 3: Full Rollout (Week 3)
1. Deploy to production
2. Monitor performance and error rates
3. Optimize based on real usage patterns

### Phase 4: Enhancement (Week 4)
1. Add advanced caching strategies
2. Implement predictive prefetching
3. Add analytics and insights

This BFF implementation provides the foundation for secure, scalable, and maintainable LLM integration while meeting all performance and quality requirements specified in Issue #3.