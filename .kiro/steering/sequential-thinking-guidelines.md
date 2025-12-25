# Sequential Thinking & Documentation-First Guidelines

## UNIVERSAL MANDATE: Documentation-First Methodology

**ALL tasks, regardless of complexity, MUST begin with a review of relevant project documentation and steering files.**

1.  **Context Acquisition**: Before executing any tool, Kilocode must review `docs/` or `.kiro/steering/` files relevant to the task.
2.  **Referencing**: The initial thought or action must explicitly reference the documentation reviewed to minimize external steering.
3.  **Technical Excellence**: Align all actions with the architectural structures and git workflows defined in the `.kiro` configuration.

## PRIMARY FRAMEWORK: Sequential Thinking for Complex Tasks

**The Sequential Thinking MCP is the MANDATORY primary framework for every complex task to ensure systematic reasoning and iterative analysis.**

## When to Use Sequential Thinking
- Architectural design and system evolution
- Multi-component debugging and root cause analysis
- CI/CD pipeline optimization and troubleshooting
- Infrastructure planning and security audits
- Complex code refactoring and logic verification

## Usage
```javascript
mcp_sequentialthinking_sequentialthinking({
  thought: "Reviewing [Specific Documentation]. Analyzing [problem] based on current state and architectural constraints.",
  nextThoughtNeeded: true,
  thoughtNumber: 1,
  totalThoughts: 5
})
```

## Best Practices
- **Analyze Before Action**: Always start with Sequential Thinking for multi-step problems.
- **Documentation Reference**: Explicitly cite the project documentation being followed.
- **Iterative Refinement**: Provide rich context and adjust `totalThoughts` as understanding deepens.
- Be adaptive - adjust `totalThoughts` as needed
- Use branching for multiple approaches
- Revise thoughts when new information emerges