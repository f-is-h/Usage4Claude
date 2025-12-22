export async function onRequest(context) {
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
