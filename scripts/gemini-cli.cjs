#!/usr/bin/env node

// Simple Gemini CLI wrapper for version analysis using GitHub Copilot

const https = require('https');

const prompt = process.argv.slice(2).join(' ');
const apiKey = process.env.GEMINI_API_KEY;

if (!prompt) {
  console.error('Usage: gemini-cli <prompt>');
  process.exit(1);
}

if (!apiKey) {
  console.error('Error: GEMINI_API_KEY environment variable is not set.');
  process.exit(1);
}

const data = JSON.stringify({
  contents: [{
    parts: [{ text: prompt }]
  }],
  generationConfig: {
    temperature: 0.1,
    maxOutputTokens: 1024
  }
});

const options = {
  hostname: 'generativelanguage.googleapis.com',
  port: 443,
  path: `/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  },
  timeout: 60000 // 60 seconds timeout
};

const makeRequest = (retryCount = 0) => {
  const req = https.request(options, (res) => {
    let body = '';
    res.on('data', (chunk) => {
      body += chunk;
    });

    res.on('end', () => {
      if (res.statusCode >= 400) {
        console.error(`Gemini API Error (${res.statusCode}):`, body);
        process.exit(1);
      }

      try {
        const response = JSON.parse(body);
        if (response.candidates && response.candidates[0] && response.candidates[0].content && response.candidates[0].content.parts[0]) {
          console.log(response.candidates[0].content.parts[0].text);
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

  req.on('timeout', () => {
    console.error('Request timed out after 180 seconds');
    req.destroy();
    process.exit(1);
  });

  req.write(data);
  req.end();
};

makeRequest();

