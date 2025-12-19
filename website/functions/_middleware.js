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
  html = html.replace(/\[ADDRESS_PLACEHOLDER[^\]]*\]/g, realAddress);

  return new Response(html, {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers
  });
}
