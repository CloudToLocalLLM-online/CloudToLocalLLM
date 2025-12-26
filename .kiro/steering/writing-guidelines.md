# Writing Guidelines & Documentation-First Methodology

## Documentation-First Requirement

**ALL development and technical tasks MUST adhere to a Documentation-First methodology.**

1.  **Review Before Execution**: Relevant documentation and steering files must be reviewed before any tool execution.
2.  **Pre-Code Documentation Updates**: Appropriate documentation updates MUST precede code changes. This ensures that the technical design and requirements are clarified and recorded before implementation begins.
3.  **Single Source of Truth**: Documentation must always reflect the current and intended state of the project.

## File Writing Best Practices

When creating or updating files, especially large documents:

1. **Write in smaller chunks**: Break large files into multiple write operations
   - Initial write with first section (< 50 lines)
   - Follow up with append operations for additional sections
   - This improves velocity and prevents timeouts

2. **Use fsWrite for initial creation**: Create the file with the first section
   
3. **Use fsAppend for additions**: Add subsequent sections incrementally

4. **Keep sections focused**: Each append should be a logical section (e.g., one major heading and its content)

## Example Pattern

```dart
// Initial write
fsWrite('design.md', '# Design Document\n\n## Overview\n...');

// Append sections
fsAppend('design.md', '\n## Architecture\n...');
fsAppend('design.md', '\n## Components\n...');
fsAppend('design.md', '\n## Implementation\n...');
```

## Benefits

- Faster file creation
- Better error recovery
- Easier to track progress
- Prevents timeout issues
- Improves user experience
