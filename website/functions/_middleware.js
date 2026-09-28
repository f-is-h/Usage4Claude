// Canonical host. Only the production pages.dev host is redirected, so preview
// deployments (<hash>.usage4claude.pages.dev) keep working on their own URLs.
const CANONICAL_HOST = 'u4c.fi5h.xyz';
const LEGACY_HOST = 'usage4claude.pages.dev';

// Homepage languages other than English, which lives at /. Keep in sync with
// LANGUAGES in website/build.py.
const LANGUAGES = ['ja', 'ko', 'zh-cn', 'zh-tw', 'fr', 'de'];

// Set by the language menu (js/site.js) when a visitor picks a language.
const LANGUAGE_COOKIE = 'u4c_lang';

export async function onRequest(context) {
  const url = new URL(context.request.url);

  // Old host and old paths are fixed in a single hop.
  const legacy = legacyPath(url.pathname);
  if (url.hostname === LEGACY_HOST || legacy) {
    if (url.hostname === LEGACY_HOST) url.hostname = CANONICAL_HOST;
    if (legacy) url.pathname = legacy;
    return Response.redirect(url.toString(), 301);
  }

  if (url.pathname === '/') {
    const lang = preferredLanguage(context.request);
    if (lang !== 'en') {
      url.pathname = `/${lang}/`;
      return new Response(null, {
        status: 302,
        headers: {
          Location: url.toString(),
          Vary: 'Accept-Language, Cookie',
          'Cache-Control': 'private, no-store'
        }
      });
    }
  }

  const response = await context.next();

  // Only the legal notice carries placeholders; every other response passes through
  // untouched so its caching headers survive.
  if (url.pathname !== '/legal' && url.pathname !== '/legal.html') {
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

// The homepages used to be /index.<lang>.html (served as /index.<lang>).
function legacyPath(pathname) {
  const match = pathname.match(/^\/index\.([a-z-]+?)(\.html)?$/);
  if (match && LANGUAGES.includes(match[1])) {
    return `/${match[1]}/`;
  }
  return null;
}

// A language picked in the menu wins; otherwise the first supported entry in
// Accept-Language decides. English, or nothing supported, stays on /.
function preferredLanguage(request) {
  const cookie = request.headers.get('Cookie') || '';
  const picked = cookie.match(new RegExp(`(?:^|;\\s*)${LANGUAGE_COOKIE}=([a-z-]+)`));
  if (picked && (picked[1] === 'en' || LANGUAGES.includes(picked[1]))) {
    return picked[1];
  }

  const entries = (request.headers.get('Accept-Language') || '')
    .split(',')
    .map((part) => {
      const [tag, ...params] = part.trim().toLowerCase().split(';');
      const q = params.find((p) => p.trim().startsWith('q='));
      return { tag, q: q ? parseFloat(q.trim().slice(2)) : 1 };
    })
    .filter((entry) => entry.tag && entry.q > 0)
    .sort((a, b) => b.q - a.q);

  for (const { tag } of entries) {
    const lang = matchLanguage(tag);
    if (lang) return lang;
  }
  return 'en';
}

function matchLanguage(tag) {
  if (tag === 'en' || tag.startsWith('en-')) return 'en';
  if (tag.startsWith('zh')) {
    return /^zh-(tw|hk|mo|hant)/.test(tag) ? 'zh-tw' : 'zh-cn';
  }
  const base = tag.split('-')[0];
  return LANGUAGES.includes(base) ? base : null;
}
