export async function onRequest(context) {
  const response = await context.next();

  const contentType = response.headers.get('content-type');
  if (!contentType || !contentType.includes('text/html')) {
    return response;
  }

  let html = await response.text();
  const realAddress = context.env.REAL_ADDRESS || '[ADDRESS_PLACEHOLDER]';
  html = html.replace(/\[ADDRESS_PLACEHOLDER[^\]]*\]/g, realAddress);

  return new Response(html, {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers
  });
}
