# Sequential Thinking Guidelines

## MANDATORY: Use Sequential Thinking for Complex Problems

**ALWAYS use the Sequential Thinking MCP server for any complex analysis, debugging, or multi-step reasoning tasks.** This tool provides structured problem-solving capabilities that help break down complex issues into manageable steps.

## When to Use Sequential Thinking

### REQUIRED Scenarios (Use Sequential Thinking First)

1. **CI/CD Pipeline Analysis**
   - Workflow debugging and troubleshooting
   - Understanding deployment failures
   - Analyzing AI orchestrator decisions
   - Repository dispatch issues

2. **Architecture and Design Decisions**
   - System design choices
   - Technology migration planning
   - Infrastructure architecture
   - Performance optimization strategies

3. **Complex Debugging**
   - Multi-component system issues
   - Authentication and security problems
   - Cross-platform compatibility issues
   - Performance bottlenecks

4. **Infrastructure Planning**
   - AWS/Azure deployment strategies
   - Cost optimization analysis
   - Security architecture design
   - Disaster recovery planning

5. **Code Analysis and Refactoring**
   - Large-scale code changes
   - Legacy system modernization
   - API design decisions
   - Database schema changes

## Sequential Thinking Process

### Step 1: Initial Problem Analysis
Start with a clear problem statement and initial thoughts:

```javascript
mcp_sequentialthinking_sequentialthinking({
  thought: "I need to analyze [specific problem]. Let me start by understanding the current state and identifying the key components involved.",
  nextThoughtNeeded: true,
  thoughtNumber: 1,
  totalThoughts: 5  // Initial estimate
})
```

### Step 2: Iterative Deep Dive
Continue with deeper analysis, adjusting total thoughts as needed:

```javascript
mcp_sequentialthinking_sequentialthinking({
  thought: "Based on my initial analysis, I've identified three key areas to investigate. Let me focus on [specific area] first and examine [specific aspects].",
  nextThoughtNeeded: true,
  thoughtNumber: 2,
  totalThoughts: 7,  // Adjusted estimate
  needsMoreThoughts: true
})
```

### Step 3: Branching for Complex Scenarios
Use branching when exploring multiple approaches:

```javascript
mcp_sequentialthinking_sequentialthinking({
  thought: "I need to explore multiple solutions. Let me branch into evaluating the [specific approach] strategy.",
  nextThoughtNeeded: true,
  thoughtNumber: 3,
  totalThoughts: 10,
  branchFromThought: 2,
  branchId: "approach-a"
})
```

### Step 4: Revision and Course Correction
Revise previous thoughts when new information emerges:

```javascript
mcp_sequentialthinking_sequentialthinking({
  thought: "After investigating further, I realize my assumption in thought 2 was incorrect. The actual issue is [corrected understanding].",
  nextThoughtNeeded: true,
  thoughtNumber: 4,
  totalThoughts: 8,
  isRevision: true,
  revisesThought: 2
})
```

### Step 5: Conclusion and Action Plan
End with clear conclusions and next steps:

```javascript
mcp_sequentialthinking_sequentialthinking({
  thought: "Based on my complete analysis, the root cause is [conclusion]. The recommended solution is [action plan] with the following implementation steps: [steps].",
  nextThoughtNeeded: false,
  thoughtNumber: 8,
  totalThoughts: 8
})
```

## Best Practices

### 1. Start with Sequential Thinking
- **Always begin complex tasks** with Sequential Thinking
- Don't jump directly to specific tools or solutions
- Use it to plan your approach before implementation

### 2. Provide Rich Context
- Include all relevant background information
- Mention constraints (time, budget, technical limitations)
- Specify the desired outcome or decision needed

### 3. Be Adaptive
- Adjust `totalThoughts` as understanding evolves
- Use `needsMoreThoughts: true` when realizing more analysis is needed
- Don't hesitate to revise previous thoughts with new information

### 4. Use Branching Strategically
- Branch when exploring multiple approaches
- Use clear `branchId` names for tracking
- Return to main thread when branches converge

### 5. Think Step-by-Step
- Break complex problems into smaller components
- Build understanding incrementally
- Question assumptions and validate reasoning

## Integration with CloudToLocalLLM Workflows

### CI/CD Analysis Pattern
```javascript
// 1. Understand the problem
mcp_sequentialthinking_sequentialthinking({
  thought: "Analyzing CI/CD issue: [description]. Let me first understand the expected workflow and identify where it's failing.",
  nextThoughtNeeded: true,
  thoughtNumber: 1,
  totalThoughts: 6
})

// 2. Check workflow status (after Sequential Thinking analysis)
// Then use: gh run list --workflow="version-and-distribute.yml"

// 3. Investigate specific issues (guided by Sequential Thinking)
// Then use: mcp_grafana_* tools for monitoring data
```

### Architecture Decision Pattern
```javascript
// 1. Define the architectural challenge
mcp_sequentialthinking_sequentialthinking({
  thought: "Need to decide on [architectural choice]. Let me analyze the requirements, constraints, and evaluate different approaches.",
  nextThoughtNeeded: true,
  thoughtNumber: 1,
  totalThoughts: 8
})

// 2. Research options (after Sequential Thinking guidance)
// Then use: mcp_context7_* tools for documentation

// 3. Validate decisions (guided by Sequential Thinking)
// Then use: specific implementation tools
```

### Debugging Pattern
```javascript
// 1. Analyze the symptoms
mcp_sequentialthinking_sequentialthinking({
  thought: "Investigating [issue description]. Let me systematically analyze the symptoms, potential causes, and develop a debugging strategy.",
  nextThoughtNeeded: true,
  thoughtNumber: 1,
  totalThoughts: 7
})

// 2. Gather data (after Sequential Thinking plan)
// Then use: mcp_grafana_*, mcp_playwright_*, or other diagnostic tools

// 3. Test hypotheses (guided by Sequential Thinking)
// Then use: specific testing and validation tools
```

## Common Mistakes to Avoid

1. **Skipping Sequential Thinking**: Don't jump directly to tools without analysis
2. **Insufficient Context**: Provide complete problem description and constraints
3. **Rigid Planning**: Be willing to adjust `totalThoughts` and branch as needed
4. **Shallow Analysis**: Don't rush through thoughts; build understanding incrementally
5. **Ignoring Revisions**: Update previous thoughts when new information emerges

## Success Metrics

- **Clearer Problem Understanding**: Sequential Thinking should clarify the problem
- **Better Solution Quality**: Solutions should be more comprehensive and well-reasoned
- **Reduced Debugging Time**: Systematic analysis should lead to faster resolution
- **Improved Decision Making**: Architecture and design decisions should be better justified
- **Enhanced Learning**: The process should improve understanding of complex systems

Remember: Sequential Thinking is not just a tool—it's a methodology for approaching complex problems systematically and thoroughly.