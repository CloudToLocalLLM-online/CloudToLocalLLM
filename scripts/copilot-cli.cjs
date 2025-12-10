#!/usr/bin/env node

// Simple Copilot CLI wrapper for version analysis using GitHub Copilot

const http = require('http');

const prompt = process.argv.slice(2).join(' ');

if (!prompt) {
  console.error('Usage: copilot-cli <prompt>');
  process.exit(1);
}

const data = JSON.stringify({
  model: 'llama3.2:1b',
  messages: [{
    role: 'user',
    content: prompt
  }],
  stream: false
});

const options = {
  hostname: 'localhost',
  port: 11434,
  path: '/api/chat',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const makeRequest = (retryCount = 0) => {
  const req = http.request(options, (res) => {
    let body = '';
    res.on('data', (chunk) => {
      body += chunk;
    });

    res.on('end', () => {
      try {
        const response = JSON.parse(body);
        if (response.message && response.message.content) {
          console.log(response.message.content);
        } else {
          console.error('Unexpected response format:', body);
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

