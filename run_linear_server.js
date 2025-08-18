import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { LinearClient } from '@linear/sdk';

try {
  const API_KEY = process.env.LINEAR_API_KEY;
  if (!API_KEY) {
    throw new Error('LINEAR_API_KEY environment variable is required');
  }

  const linear = new LinearClient({ apiKey: API_KEY });

  const server = new McpServer({
    name: 'linear-server',
    version: '0.1.0',
  });

  server.tool(
    'issue_list',
    {
      filter: z.string().optional(),
      output: z.string().optional(),
      fields: z.string().optional(),
    },
    async ({ filter, output, fields }) => {
      try {
        const issues = await linear.issues({ filter: { attachments: { source: { type: { eq: 'github' } } } } });
        let result = issues.nodes;

        if (fields) {
          const fieldList = fields.split(',');
          result = issues.nodes.map(issue => {
            const newIssue = {};
            for (const field of fieldList) {
              // Handle nested properties like assignee.name
              const fieldParts = field.split('.');
              let value = issue;
              for (const part of fieldParts) {
                if (value && typeof value === 'object' && part in value) {
                  value = value[part];
                } else {
                  value = undefined;
                  break;
                }
              }
              newIssue[field] = value;
            }
            return newIssue;
          });
        }

        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Linear API error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    }
  );

  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Linear MCP server running on stdio');

} catch (e) {
  console.error(`Failed to start Linear MCP server: ${e.message}`);
  process.exit(1);
}