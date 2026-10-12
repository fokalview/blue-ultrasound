interface Env { ASSETS: Fetcher }

const headers = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
};

export const capabilities = {
  version: 1,
  mode: 'local-research',
  cloudSync: false,
  patientDataUpload: false,
  primaryVendor: 'clarius',
  clarius: {
    implementation: 'not-implemented',
    hardwareVerified: false,
    routes: ['solum-oem-native', 'cast-companion-native'],
    requirements: ['Native platform adapter', 'Matching SDK and firmware', 'Applicable probe license', 'Physical device verification'],
    guide: 'https://github.com/fokalview/blue-ultrasound/blob/main/docs/CLARIUS.md',
  },
  adapters: [
    {id: 'demo', source: 'simulated', available: true, freeze: true, capture: true},
    {id: 'ge-vscan', source: 'hardware', available: false, reason: 'Deferred; Clarius is the primary integration target'},
    {id: 'clarius', source: 'hardware', available: false, reason: 'Licensed SDK and hardware verification required'},
    {id: 'butterfly', source: 'hardware', available: false, reason: 'SDK access and platform verification required'},
  ],
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const {pathname} = new URL(request.url);
    if (!pathname.startsWith('/api/')) return env.ASSETS.fetch(request);
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return Response.json({error: 'cloud_storage_disabled', message: 'This release does not accept study uploads.'}, {status: 503, headers});
    }
    const body = pathname === '/api/health'
      ? {status: 'ok', version: '0.1.0', mode: 'local-research', storage: 'disabled'}
      : pathname === '/api/v1/device-capabilities' ? capabilities : null;
    if (!body) return Response.json({error: 'not_found'}, {status: 404, headers});
    return new Response(request.method === 'HEAD' ? null : JSON.stringify(body), {headers});
  },
};
