#!/usr/bin/env node

const https = require('https');
const http = require('http');

// AI API configuration
const AI_API_BASE = process.env.AI_API_BASE || 'https://api.kilocode.com'; // Configurable API endpoint
const AI_API_KEY = process.env.AI_API_KEY || process.env.KILOCODE_API_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbnYiOiJwcm9kdWN0aW9uIiwia2lsb1VzZXJJZCI6ImUyNGFjNjUwLTY2MzgtNGJmMi1hMjM0LTc0ODdlMmVkYTJmYyIsImFwaVRva2VuUGVwcGVyIjpudWxsLCJ2ZXJzaW9uIjozLCJpYXQiOjE3NjYyNTkwMDcsImV4cCI6MTkyNDA0NzAwN30.vnJ8IN5FRK_AVqCqc7PjCkW5otyZf1_n9kqYTk6Dscs';

async function makeAIRequest(prompt, options = {}) {
  const {
    model = 'grok-code-fast-1',
    outputFormat = 'json',
    maxTokens = 4096,
    temperature = 0.7
  } = options;

  // Perform real API call
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      prompt,
      model,
      output_format: outputFormat,
      max_tokens: maxTokens,
      temperature
    });

    const url = new URL('/v1/chat/completions', AI_API_BASE);
    const requestOptions = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AI_API_KEY}`,
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = (url.protocol === 'https:' ? https : http).request(requestOptions, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            const response = JSON.parse(data);
            resolve(response);
          } else {
            reject(new Error(`API request failed with status ${res.statusCode}: ${data}`));
          }
        } catch (error) {
          reject(new Error(`Failed to parse API response: ${error.message}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`Request failed: ${error.message}`));
    });

    req.write(postData);
    req.end();
  });
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: ai-agent "Your prompt here" [--model grok-code-fast-1] [--output-format json]');
    process.exit(1);
  }

  const prompt = args[0];
  const options = {};

  // Parse additional options
  for (let i = 1; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--model' && i + 1 < args.length) {
      options.model = args[i + 1];
      i++;
    } else if (arg === '--output-format' && i + 1 < args.length) {
      options.outputFormat = args[i + 1];
      i++;
    } else if (arg === '--max-tokens' && i + 1 < args.length) {
      options.maxTokens = parseInt(args[i + 1]);
      i++;
    } else if (arg === '--temperature' && i + 1 < args.length) {
      options.temperature = parseFloat(args[i + 1]);
      i++;
    } else if (arg === '--json') {
      options.jsonOnly = true;
    }
  }

  try {
    const response = await makeAIRequest(prompt, options);

    if (options.outputFormat === 'json') {
      // For workflows, return the expected format with 'response' field
      console.log(JSON.stringify({
        response: response.response,
        model: response.model || options.model,
        usage: response.usage || {}
      }));
    } else if (options.outputFormat === 'json-only' || options.jsonOnly) {
      // Return only the AI response, attempting to parse it as JSON if possible to ensure validity
      try {
        const jsonMatch = response.response.match(/\{[\s\S]*\}|\[[\s\S]*\]/);
        if (jsonMatch) {
          console.log(jsonMatch[0]);
        } else {
          console.log(response.response);
        }
      } catch (e) {
        console.log(response.response);
      }
    } else {
      console.log(response.response);
    }
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`Unexpected error: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { makeAIRequest };