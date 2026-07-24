const fs = require('fs');
const path = require('path');

const isProd = process.env.NODE_ENV === 'production';

const envConfig = {
    API_URL: process.env.API_URL || (isProd ? '' : 'http://localhost:8080'),
    SUPABASE_URL: process.env.SUPABASE_URL || '',
    SUPABASE_KEY: process.env.SUPABASE_KEY || '',
    LOG_LEVEL: process.env.LOG_LEVEL || (isProd ? 'WARN' : 'DEBUG'),
    SENTRY_DSN_FRONTEND: process.env.SENTRY_DSN_FRONTEND || '',
    SENTRY_ENVIRONMENT: process.env.SENTRY_ENVIRONMENT || (isProd ? 'production' : 'development'),
    SENTRY_RELEASE: process.env.SENTRY_RELEASE || ''
};

const content = `window.__env = ${JSON.stringify(envConfig, null, 2)};`;

const outPath = path.join(__dirname, '../public/runtime-env.js');
fs.writeFileSync(outPath, content);

console.log('=== runtime-env.js generated ===');
console.log('Environment:', isProd ? 'Production' : 'Development');
// console.log('API_URL:', envConfig.API_URL);
// console.log('SUPABASE_URL:', envConfig.SUPABASE_URL);
// console.log('Output path:', outPath);
