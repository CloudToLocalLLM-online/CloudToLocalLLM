#!/usr/bin/env node

// Kilo Code CLI wrapper for AI-powered operations
// Uses Grok API instead of Gemini

const https = require('https');

// Support both new and legacy environment variables
const API_KEY = process.env.KILOCODE_API_KEY || process.env.GEMINI_API_KEY;
const prompt = process.argv.slice(2).join(' ');

if (!API_KEY) {
  console.error('Error: KILOCODE_API_KEY (or GEMINI_API_KEY) environment variable not set');
  process.exit(1);
}

if (!prompt) {
  console.error('Usage: kilocode-cli <prompt>');
  process.exit(1);
}

const data = JSON.stringify({
  messages: [
    {
      role: "user",
      content: prompt
    }
  ],
  model: "grok-code-fast-1",
  stream: false,
  temperature: 0
});

const options = {
  hostname: 'generativelanguage.googleapis.com',
  port: 443,
  path: `/v1beta/models/gemini-2.5-flash:generateContent?key=${API_KEY}`,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = https.request(options, (res) => {
  let body = '';
  
  res.on('data', (chunk) => {
    body += chunk;
  });
  
  res.on('end', () => {
    try {
      const response = JSON.parse(body);
      if (response.choices && response.choices[0] && response.choices[0].message) {
        const text = response.choices[0].message.content;
        console.log(text);
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