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

  const realAddress = context.env.REAL_ADDRESS || '[ADDRESS_PLACEHOLDER]';

  let html = await response.text();

  const hasPlaceholder = html.includes('[ADDRESS_PLACEHOLDER');
  const envVarExists = !!context.env.REAL_ADDRESS;

  html = html.replace(/\[ADDRESS_PLACEHOLDER[^\]]*\]/g, realAddress);

  const newResponse = new Response(html, {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers
  });

  newResponse.headers.set('X-Debug-Placeholder-Found', hasPlaceholder ? 'yes' : 'no');
  newResponse.headers.set('X-Debug-Env-Var-Exists', envVarExists ? 'yes' : 'no');
  newResponse.headers.set('X-Debug-Env-Value-Length', context.env.REAL_ADDRESS ? context.env.REAL_ADDRESS.length : '0');

  return newResponse;
}
