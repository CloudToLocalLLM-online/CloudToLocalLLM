#!/usr/bin/env node

const https = require('https');
const http = require('http');

// KiloCode API configuration
const KILOCODE_API_BASE = 'https://api.kilocode.com'; // Placeholder - update with actual API endpoint
const KILOCODE_API_KEY = process.env.KILOCODE_API_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbnYiOiJwcm9kdWN0aW9uIiwia2lsb1VzZXJJZCI6ImUyNGFjNjUwLTY2MzgtNGJmMi1hMjM0LTc0ODdlMmVkYTJmYyIsImFwaVRva2VuUGVwcGVyIjpudWxsLCJ2ZXJzaW9uIjozLCJpYXQiOjE3NjYyNTkwMDcsImV4cCI6MTkyNDA0NzAwN30.vnJ8IN5FRK_AVqCqc7PjCkW5otyZf1_n9kqYTk6Dscs';

async function makeKiloCodeRequest(prompt, options = {}) {
  const {
    model = 'grok-code-fast-1',
    outputFormat = 'json',
    maxTokens = 4096,
    temperature = 0.7
  } = options;

  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      prompt,
      model,
      output_format: outputFormat,
      max_tokens: maxTokens,
      temperature
    });

    const url = new URL('/v1/chat/completions', KILOCODE_API_BASE);
    const requestOptions = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${KILOCODE_API_KEY}`,
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
    console.error('Usage: kilocode-cli "Your prompt here" [--model grok-code-fast-1] [--output-format json]');
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
    }
  }

  try {
    const response = await makeKiloCodeRequest(prompt, options);

    if (options.outputFormat === 'json') {
      console.log(JSON.stringify({
        response: response.choices?.[0]?.message?.content || response.content || response,
        model: response.model || options.model,
        usage: response.usage || {}
      }));
    } else {
      console.log(response.choices?.[0]?.message?.content || response.content || response);
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

module.exports = { makeKiloCodeRequest };