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

  class AddressReplacer {
    element(element) {
      const content = element.getAttribute('innerHTML');
      if (content && content.includes('[ADDRESS_PLACEHOLDER]')) {
        element.setInnerContent(content.replace(/\[ADDRESS_PLACEHOLDER\]/g, realAddress));
      }
    }

    text(text) {
      if (text.text.includes('[ADDRESS_PLACEHOLDER]')) {
        text.replace(text.text.replace(/\[ADDRESS_PLACEHOLDER\]/g, realAddress));
      }
    }
  }

  return new HTMLRewriter()
    .on('p', new AddressReplacer())
    .on('span', new AddressReplacer())
    .on('div', new AddressReplacer())
    .transform(response);
}
