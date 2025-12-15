# Sequential Thinking Guidelines

## MANDATORY: Use for Complex Problems

**ALWAYS use Sequential Thinking MCP for complex analysis, debugging, or multi-step reasoning.**

## When to Use
- CI/CD pipeline analysis and debugging
- Architecture and design decisions  
- Multi-component system issues
- Infrastructure planning
- Code analysis and refactoring

## Usage
```javascript
mcp_sequentialthinking_sequentialthinking({
  thought: "Analyzing [problem]. Let me understand the current state and key components.",
  nextThoughtNeeded: true,
  thoughtNumber: 1,
  totalThoughts: 5
})
```

## Best Practices
- Start with Sequential Thinking before jumping to tools
- Provide rich context and constraints
- Be adaptive - adjust `totalThoughts` as needed
- Use branching for multiple approaches
- Revise thoughts when new information emerges