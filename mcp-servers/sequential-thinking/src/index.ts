import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

interface Thought {
  thought: string;
  thoughtNumber: number;
  totalThoughts: number;
  nextThoughtNeeded: boolean;
  isRevision?: boolean;
  revisesThought?: number;
  branchFromThought?: number;
  branchId?: string;
  needsMoreContext?: boolean;
}

class SequentialThinkingServer {
  private server: Server;
  private thoughtHistory: Thought[] = [];

  constructor() {
    this.server = new Server(
      {
        name: "sequential-thinking",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
    this.server.onerror = (error) => console.error("[MCP Error]", error);
  }

  private formatThought(thought: Thought): string {
    const { thoughtNumber, totalThoughts, isRevision, revisesThought, branchFromThought, branchId } = thought;
    let prefix = `Thought ${thoughtNumber}/${totalThoughts}`;
    if (isRevision) prefix += ` (Revision of ${revisesThought})`;
    if (branchFromThought) prefix += ` (Branch from ${branchFromThought}${branchId ? ` [${branchId}]` : ""})`;

    const header = "─".repeat(prefix.length + 4);
    return `
${header}
  ${prefix}
${header}

${thought.thought}
`;
  }

  private setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "sequentialthinking",
          description: "A tool for dynamic and reflective problem-solving through a structured sequence of thoughts. " +
            "This tool helps break down complex problems, generate hypotheses, and refine strategies iteratively.",
          inputSchema: {
            type: "object",
            properties: {
              thought: {
                type: "string",
                description: "The current thinking process or step.",
              },
              thoughtNumber: {
                type: "integer",
                description: "The current step in the thinking sequence.",
              },
              totalThoughts: {
                type: "integer",
                description: "The estimated total number of thoughts needed.",
              },
              nextThoughtNeeded: {
                type: "boolean",
                description: "Whether more thinking is required after this step.",
              },
              isRevision: {
                type: "boolean",
                description: "Whether this thought revises a previous one.",
              },
              revisesThought: {
                type: "integer",
                description: "The thought number being revised.",
              },
              branchFromThought: {
                type: "integer",
                description: "The thought number to branch from.",
              },
              branchId: {
                type: "string",
                description: "Identifier for the current branch.",
              },
              needsMoreContext: {
                type: "boolean",
                description: "Whether more external information is needed.",
              },
            },
            required: ["thought", "thoughtNumber", "totalThoughts", "nextThoughtNeeded"],
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      if (request.params.name !== "sequentialthinking") {
        throw new Error("Unknown tool");
      }

      const thought = request.params.arguments as unknown as Thought;
      this.thoughtHistory.push(thought);

      return {
        content: [
          {
            type: "text",
            text: this.formatThought(thought),
          },
        ],
      };
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Sequential Thinking MCP server running on stdio");
  }
}

const server = new SequentialThinkingServer();
server.run().catch(console.error);
