import { createFileRoute } from '@tanstack/react-router';

import { json, methodNotAllowed, preflight } from '@/server/api';
import { env } from '@/server/env';
import { getAnonSupabaseClient } from '@/server/supabaseClient';

/**
 * Experiment-mode shared login. The server (which can reach local Supabase)
 * signs in as the seeded test user and returns tokens. Remote browsers call
 * this on the same CADAM origin, then supabase.auth.setSession(...).
 *
 * Only enabled when ENVIRONMENT=local or VITE_BYPASS_AUTH is set.
 */
export const Route = createFileRoute('/api/dev-session')({
  server: {
    handlers: {
      OPTIONS: preflight,
      GET: () => methodNotAllowed(),
      POST: async () => {
        const bypass =
          env('ENVIRONMENT') === 'local' ||
          env('VITE_BYPASS_AUTH') === 'true' ||
          env('VITE_BYPASS_AUTH') === '1';
        if (!bypass) {
          return json({ error: 'dev_session_disabled' }, 404);
        }

        const email = env('VITE_BYPASS_AUTH_EMAIL') || 'test@adamcad.com';
        const password = env('VITE_BYPASS_AUTH_PASSWORD') || 'password';

        const supabase = getAnonSupabaseClient({
          auth: { autoRefreshToken: false, persistSession: false },
        });
        const { data, error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (error || !data.session) {
          return json(
            {
              error: error?.message ?? 'sign_in_failed',
              hint: 'Is local Supabase running with seed.sql (test@adamcad.com)?',
            },
            502,
          );
        }

        return json({
          access_token: data.session.access_token,
          refresh_token: data.session.refresh_token,
          expires_at: data.session.expires_at,
          expires_in: data.session.expires_in,
          token_type: data.session.token_type,
          user: data.user,
        });
      },
    },
  },
});
