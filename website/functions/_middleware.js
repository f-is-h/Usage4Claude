export async function onRequest(context) {
  const response = await context.next();

  const url = new URL(context.request.url);
  if (!url.pathname.endsWith('.html') && url.pathname !== '/') {
    return response;
  }

  const contentType = response.headers.get('content-type');
  if (!contentType || !contentType.includes('text/html')) {
    return response;
  }

  let html = await response.text();

  const realAddress = context.env.REAL_ADDRESS || '[ENV_VAR_NOT_FOUND]';

  const debugInfo = `<!-- DEBUG: Middleware executed at ${new Date().toISOString()} -->
<!-- DEBUG: Env var exists: ${!!context.env.REAL_ADDRESS} -->
<!-- DEBUG: Env var length: ${context.env.REAL_ADDRESS ? context.env.REAL_ADDRESS.length : 0} -->
<!-- DEBUG: Placeholder found: ${html.includes('[ADDRESS_PLACEHOLDER')} -->
`;

  html = debugInfo + html;
  html = html.replace(/\[ADDRESS_PLACEHOLDER[^\]]*\]/g, realAddress);

  return new Response(html, {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers
  });
}
