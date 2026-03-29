const fs = require('fs');
const path = require('path');

const isProd = process.env.NODE_ENV === 'production';

const content = isProd
    ? `window.__env = { API_URL: '${process.env.API_URL || ''}' };`
    : `window.__env = { API_URL: 'http://localhost:8080' };`;

const outPath = path.join(__dirname, '../public/runtime-env.js');
fs.writeFileSync(outPath, content);

console.log(`runtime-env.js generated for ${isProd ? 'production' : 'development'}`);