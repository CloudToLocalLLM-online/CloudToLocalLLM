#!/usr/bin/env node

// Simple Copilot CLI wrapper for version analysis using GitHub Copilot

const https = require('https');

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const prompt = process.argv.slice(2).join(' ');

if (!GITHUB_TOKEN) {
  console.error('Error: GITHUB_TOKEN environment variable not set');
  process.exit(1);
}

if (!prompt) {
  console.error('Usage: copilot-cli <prompt>');
  process.exit(1);
}

const data = JSON.stringify({
  model: 'grok-code-fast-1',
  messages: [{
    role: 'user',
    content: prompt
  }]
});

const options = {
  hostname: 'api.github.com',
  port: 443,
  path: '/copilot/chat/completions',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${GITHUB_TOKEN}`,
    'User-Agent': 'Copilot-CLI/1.0',
    'Content-Length': data.length
  }
};

const makeRequest = (retryCount = 0) => {
  const req = https.request(options, (res) => {
    let body = '';
    res.on('data', (chunk) => {
      body += chunk;
    });

    res.on('end', () => {
      try {
        const response = JSON.parse(body);
        if (response.choices && response.choices.length > 0) {
          console.log(response.choices[0].message.content);
        } else if (res.statusCode === 503 && retryCount < 24) { // 24 retries * 5s delay = 120s = 2 minutes
          console.log(`Received 503, retrying in 5 seconds... (Attempt ${retryCount + 1})`);
          setTimeout(() => makeRequest(retryCount + 1), 5000);
        } else {
          console.error('Unexpected response format or max retries reached:', body);
          process.exit(1);
        }
      } catch (e) {
        console.error('Failed to parse response:', e.message);
        console.error('Body:', body);
        process.exit(1);
      }
    });
  });

  req.on('error', (e) => {
    console.error('Request failed:', e.message);
    process.exit(1);
  });

  req.write(data);
  req.end();
};

makeRequest();

