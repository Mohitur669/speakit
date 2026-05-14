const env = (window as any).__env || {};

export const environment = {
  production: false,
  apiUrl: env.API_URL || '',
  supabaseUrl: env.SUPABASE_URL || '',
  supabaseKey: env.SUPABASE_KEY || '',
};