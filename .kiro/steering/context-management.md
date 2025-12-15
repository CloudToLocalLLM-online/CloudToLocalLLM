# Context Management Guidelines

## CRITICAL: Manage Context Efficiently

Keep steering rules concise to preserve context window for actual work.

## Rules

### 1. Read Files Strategically
- Use `readFile` with line ranges for large files
- Use `grepSearch` to find specific content first
- Read multiple related files together with `readMultipleFiles`

### 2. Steering Rules Must Be Concise
- Max 20 lines per steering rule
- Focus on essential information only
- Move detailed examples to documentation

### 3. Use Sequential Thinking for Complex Analysis
- Don't load large files into context for analysis
- Use Sequential Thinking to plan approach first
- Then read specific sections as needed

### 4. Consolidate Information
- Delete redundant files immediately
- Combine related documentation
- Archive unused workflows/code

### 5. Context-Aware Tool Usage
- Use `fileSearch` before `readFile` for unknown locations
- Use `listDirectory` to understand structure first
- Use `grepSearch` to locate specific patterns

## Don't Do This
- ❌ Read entire large files without purpose
- ❌ Keep redundant documentation
- ❌ Load verbose steering rules
- ❌ Read files multiple times for same information