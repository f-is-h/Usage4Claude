// Canonical host. Only the production pages.dev host is redirected, so preview
// deployments (<hash>.usage4claude.pages.dev) keep working on their own URLs.
const CANONICAL_HOST = 'u4c.fi5h.xyz';
const LEGACY_HOST = 'usage4claude.pages.dev';

export async function onRequest(context) {
  const url = new URL(context.request.url);
  if (url.hostname === LEGACY_HOST) {
    url.hostname = CANONICAL_HOST;
    return Response.redirect(url.toString(), 301);
  }

  const response = await context.next();

  const contentType = response.headers.get('content-type');
  if (!contentType || !contentType.includes('text/html')) {
    return response;
  }

  let html = await response.text();

  // Replace placeholders with environment variables
  const realName = context.env.REAL_NAME || '[NAME_PLACEHOLDER]';
  const realEmail = context.env.REAL_EMAIL || '[EMAIL_PLACEHOLDER]';
  const realAddress = context.env.REAL_ADDRESS || '[ADDRESS_PLACEHOLDER]';

  html = html.replace(/\[NAME_PLACEHOLDER[^\]]*\]/g, realName);
  html = html.replace(/\[EMAIL_PLACEHOLDER[^\]]*\]/g, realEmail);
  html = html.replace(/\[ADDRESS_PLACEHOLDER[^\]]*\]/g, realAddress);

  return new Response(html, {
    status: response.status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8'
    }
  });
}
