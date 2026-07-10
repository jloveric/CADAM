/** Local/experiment mode: skip the login UI by auto-signing in. */
export const authBypass =
  import.meta.env.VITE_BYPASS_AUTH === 'true' ||
  import.meta.env.VITE_BYPASS_AUTH === '1';

export const bypassCredentials = {
  email:
    (import.meta.env.VITE_BYPASS_AUTH_EMAIL as string) || 'test@adamcad.com',
  password: (import.meta.env.VITE_BYPASS_AUTH_PASSWORD as string) || 'password',
};
