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
  path: `/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}`,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
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
        if (response.candidates && response.candidates.length > 0) {
          console.log(response.candidates[0].content.parts[0].text);
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

