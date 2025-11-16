# Writing Guidelines

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
