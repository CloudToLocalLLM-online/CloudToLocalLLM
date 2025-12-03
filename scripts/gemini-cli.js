#!/usr/bin/env node

// Simple Gemini CLI wrapper for version analysis

const https = require('https');

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const prompt = process.argv.slice(2).join(' ');

if (!GEMINI_API_KEY) {
  console.error('Error: GEMINI_API_KEY environment variable not set');
  process.exit(1);
}

if (!prompt) {
  console.error('Usage: gemini-cli <prompt>');
  process.exit(1);
}

const data = JSON.stringify({
  contents: [{
    parts: [{
      text: prompt
    }]
  }]
});

const options = {
  hostname: 'generativelanguage.googleapis.com',
  port: 443,
  path: `/v1beta/models/gemini-pro:generateContent?key=${GEMINI_API_KEY}`,
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
      if (response.candidates && response.candidates[0] && response.candidates[0].content) {
        const text = response.candidates[0].content.parts[0].text;
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

