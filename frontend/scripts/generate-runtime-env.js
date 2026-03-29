const fs = require('fs');
const path = require('path');

const isProd = process.env.NODE_ENV === 'production';
const apiUrl = isProd
    ? (process.env.API_URL || '')
    : 'http://localhost:8080';

const content = `window.__env = { API_URL: '${apiUrl}' };`;

const outPath = path.join(__dirname, '../public/runtime-env.js');
fs.writeFileSync(outPath, content);

console.log('=== runtime-env.js generated ===');
console.log('isProd:', isProd);
console.log('API_URL env var:', process.env.API_URL);
console.log('Generated content:', content);
console.log('Output path:', outPath);
