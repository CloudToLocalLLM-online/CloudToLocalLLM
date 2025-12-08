#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { chromium, Browser, Page } from 'playwright';
import { z } from 'zod';

class PlaywrightServer {
  private server: McpServer;
  private browser: Browser | null = null;
  private page: Page | null = null;

  constructor() {
    this.server = new McpServer({
      name: "playwright",
      version: "0.1.0",
    });

    this.setupTools();
    this.setupLifecycle();
  }

  private async setupBrowser() {
    if (!this.browser) {
      this.browser = await chromium.launch();
      this.page = await this.browser.newPage();
    }
  }

  private setupTools() {
    this.server.tool(
      "browser_navigate",
      "Navigate to a URL",
      {
        url: z.string().describe("The URL to navigate to"),
      },
      async ({ url }) => {
        await this.setupBrowser();
        if (!this.page) throw new Error("Browser not initialized");
        await this.page.goto(url);
        return {
          content: [
            {
              type: "text",
              text: `Navigated to ${url}`,
            },
          ],
        };
      }
    );

    this.server.tool(
      "browser_click",
      "Click an element on the page",
      {
        selector: z.string().describe("CSS selector of the element to click"),
      },
      async ({ selector }) => {
        await this.setupBrowser();
        if (!this.page) throw new Error("Browser not initialized");
        await this.page.click(selector);
        return {
          content: [
            {
              type: "text",
              text: `Clicked element ${selector}`,
            },
          ],
        };
      }
    );

    this.server.tool(
      "browser_type",
      "Type text into an input field",
      {
        selector: z.string().describe("CSS selector of the input element"),
        text: z.string().describe("Text to type"),
      },
      async ({ selector, text }) => {
        await this.setupBrowser();
        if (!this.page) throw new Error("Browser not initialized");
        await this.page.fill(selector, text);
        return {
          content: [
            {
              type: "text",
              text: `Typed "${text}" into ${selector}`,
            },
          ],
        };
      }
    );

    this.server.tool(
      "browser_take_screenshot",
      "Take a screenshot of the current page",
      {
        fullPage: z.boolean().optional().describe("Whether to take a full page screenshot"),
      },
      async ({ fullPage = false }) => {
        await this.setupBrowser();
        if (!this.page) throw new Error("Browser not initialized");
        const screenshot = await this.page.screenshot({ fullPage });
        return {
          content: [
            {
              type: "image",
              data: screenshot.toString('base64'),
              mimeType: "image/png",
            },
          ],
        };
      }
    );

    this.server.tool(
      "browser_evaluate",
      "Evaluate JavaScript on the page",
      {
        script: z.string().describe("JavaScript code to evaluate"),
      },
      async ({ script }) => {
        await this.setupBrowser();
        if (!this.page) throw new Error("Browser not initialized");
        const result = await this.page.evaluate(script);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result),
            },
          ],
        };
      }
    );
  }

  private setupLifecycle() {
    process.on('SIGINT', async () => {
      if (this.browser) {
        await this.browser.close();
      }
      process.exit(0);
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Playwright MCP server running on stdio');
  }
}

const server = new PlaywrightServer();
server.run().catch(console.error);