import { createFileRoute } from '@tanstack/react-router';

import { preflight } from '@/server/api';
import { requiredEnv } from '@/server/env';

/**
 * Same-origin reverse proxy to local Supabase so remote browsers only need
 * the CADAM URL (VPN/tunnel). Server still talks to VITE_SUPABASE_URL
 * (typically http://127.0.0.1:54321).
 *
 * Browser client URL becomes: {origin}{base}/api/supabase
 * which forwards to:          {VITE_SUPABASE_URL}/...
 */
export const Route = createFileRoute('/api/supabase/$')({
  server: {
    handlers: {
      GET: proxySupabase,
      POST: proxySupabase,
      PUT: proxySupabase,
      PATCH: proxySupabase,
      DELETE: proxySupabase,
      HEAD: proxySupabase,
      OPTIONS: preflight,
    },
  },
});

const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailers',
  'transfer-encoding',
  'upgrade',
  'host',
  'content-length',
]);

const FORWARD_REQUEST_HEADERS = [
  'authorization',
  'apikey',
  'content-type',
  'accept',
  'prefer',
  'range',
  'x-client-info',
  'x-supabase-api-version',
  'accept-profile',
  'content-profile',
  'x-upsert',
];

async function proxySupabase({ request }: { request: Request }) {
  const upstreamBase = requiredEnv('VITE_SUPABASE_URL').replace(/\/$/, '');
  const url = new URL(request.url);
  const routePath = '/api/supabase';
  const routeIndex = url.pathname.indexOf(routePath);
  const path =
    routeIndex === -1
      ? '/'
      : url.pathname.slice(routeIndex + routePath.length) || '/';

  const target = new URL(`${upstreamBase}${path}`);
  target.search = url.search;

  const headers = new Headers();
  for (const name of FORWARD_REQUEST_HEADERS) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }
  // Ensure GoTrue/PostgREST always see an apikey even if the client omitted it.
  if (!headers.has('apikey')) {
    headers.set('apikey', requiredEnv('VITE_SUPABASE_ANON_KEY'));
  }

  const body =
    request.method === 'GET' || request.method === 'HEAD'
      ? undefined
      : await request.arrayBuffer();

  const response = await fetch(target, {
    method: request.method,
    headers,
    body,
    redirect: 'manual',
  });

  const responseHeaders = new Headers();
  response.headers.forEach((value, key) => {
    if (HOP_BY_HOP.has(key.toLowerCase())) return;
    responseHeaders.set(key, value);
  });
  responseHeaders.set('Access-Control-Allow-Origin', '*');
  responseHeaders.set(
    'Access-Control-Allow-Headers',
    'authorization, x-client-info, apikey, content-type, prefer, range, x-supabase-api-version',
  );
  responseHeaders.set(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS',
  );

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: responseHeaders,
  });
}
