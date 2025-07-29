#!/usr/bin/env node

/**
 * Script to provide Auth0 API configuration instructions for CloudToLocalLLM
 * This resolves the "Service not found: https://app.cloudtolocalllm.online" error
 */

console.log('🔧 AUTH0 API CONFIGURATION FOR CLOUDTOLOCALLLM');
console.log('='.repeat(50));
console.log('');
console.log('❌ ISSUE: "Service not found: https://app.cloudtolocalllm.online"');
console.log('✅ SOLUTION: Create Auth0 API (Resource Server)');
console.log('');

console.log('📝 REQUIRED API CONFIGURATION:');
console.log('  - Name: CloudToLocalLLM API');
console.log('  - Identifier: https://app.cloudtolocalllm.online');
console.log('  - Signing Algorithm: RS256');
console.log('  - Scopes: read:profile, write:profile');
console.log('');

console.log('🔧 MANUAL CONFIGURATION STEPS:');
console.log('1. Go to: https://manage.auth0.com/dashboard/us/dev-v2f2p008x3dr74ww/apis');
console.log('2. Click "Create API"');
console.log('3. Fill in:');
console.log('   - Name: CloudToLocalLLM API');
console.log('   - Identifier: https://app.cloudtolocalllm.online');
console.log('   - Signing Algorithm: RS256');
console.log('4. Click "Create"');
console.log('');
console.log('5. AUTHORIZE APPLICATION:');
console.log('   - Go to Applications → Applications');
console.log('   - Find app: FuXPnevXpp311CdYHGsbNZe9t3D8Ts7A');
console.log('   - Go to APIs tab');
console.log('   - Click "Authorize" for CloudToLocalLLM API');
console.log('   - Grant scopes: read:profile, write:profile');
console.log('');
console.log('6. VERIFY CALLBACK URLS:');
console.log('   - In application settings, ensure:');
console.log('   - Allowed Callback URLs: http://localhost:8080/callback');
console.log('   - Allowed Web Origins: http://localhost:8080');
console.log('   - Allowed Origins (CORS): http://localhost:8080');
console.log('');
console.log('✅ After creating the API, restart the Flutter app to test authentication.');
console.log('🎯 This will resolve the HTTP 400 tunnel connection errors.');
console.log('');
