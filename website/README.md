# Usage4Claude Website

Product website for the Usage4Claude macOS application.

## Project Information

- **Tech Stack**: HTML5 + Tailwind CSS (CDN) + Vanilla JS
- **Deployment**: Cloudflare Pages
- **Languages**: 7, matching the app - English (main), Japanese, Korean, Simplified Chinese,
  Traditional Chinese, French, German
- **Website URL**: https://usage4claude.pages.dev

## Directory Structure

```
website/
├── index.html              # English homepage (main version)
├── index.zh-cn.html        # Simplified Chinese
├── index.ja.html           # Japanese
├── index.zh-tw.html        # Traditional Chinese
├── index.ko.html           # Korean
├── index.fr.html           # French
├── index.de.html           # German
├── legal.html              # Legal notice (JP/EN bilingual)
├── privacy.html            # Privacy policy (7 languages)
├── sitemap.xml             # Declared by robots.txt - keep new pages listed here
├── functions/              # Cloudflare Pages Functions (address placeholder replacement)
├── css/
│   └── custom.css          # Custom styles
├── js/
│   ├── main.js             # Basic interactions
│   ├── version.js          # Pulls the latest version from the GitHub Releases API
│   ├── i18n.js             # Multi-language switching
│   └── translations-privacy.js  # Privacy page translations
├── images/
│   ├── icon.png            # App icon
│   ├── og-image.png        # Social sharing image
│   └── screenshots/        # Product screenshots
├── favicon.ico
├── robots.txt
└── .gitignore
```

## Multi-Language Strategy

### Homepage: Multi-Page Approach
- Each language has its own HTML file
- Benefits: Perfect SEO, optimal performance, zero JS dependency
- Main version: `index.html` (English)
- All seven language files share an identical structure - when editing one, apply the same change to the others

### Legal Pages: Single-Page + JS Switching
- `legal.html`: Japanese/English bilingual switching
- `privacy.html`: 7-language switching (EN/JA/KO/ZH-CN/ZH-TW/FR/DE), first visit follows the browser language
- Benefits: Better UX, no need for SEO (noindex set)

## Local Development

### Start Local Server

```bash
cd website
python3 -m http.server 8000
```

Visit: http://localhost:8000

### Test URLs
- Homepage: http://localhost:8000/
- Legal Notice: http://localhost:8000/legal.html
- Privacy Policy: http://localhost:8000/privacy.html

## Deployment to Cloudflare Pages

### Build Configuration
```yaml
Build command: (leave empty)
Build output directory: /
Root directory: website
```

### Deployment Steps

1. **Connect Repository**
   - Go to Cloudflare Dashboard → Pages
   - Connect GitHub repository: `f-is-h/Usage4Claude`
   - Select root directory: `website`

2. **Address Placeholder**
   - `legal.html` keeps `[NAME_PLACEHOLDER]` and `[ADDRESS_PLACEHOLDER]` in source
   - `functions/` replaces them at request time, so the real address never enters the repository

3. **Test Deployment**
   - Visit generated `.pages.dev` URL
   - Test all pages and language switching
   - Check mobile responsiveness

4. **Custom Domain** (Optional)
   - Add custom domain in Pages settings
   - Configure DNS records

## Content Updates

### Version Number
The version number is **not hard-coded**. `js/version.js` reads the latest tag from the GitHub
Releases API and fills every element carrying `data-latest-version`, whose attribute value is the
text template (`{version}` is the placeholder). The text written in the HTML is only the fallback
shown when the request fails, so it need not be updated on every release - refresh it occasionally
so the fallback does not drift too far.

### Add New Features
1. Add a feature card in the Features section
2. Follow the existing HTML structure
3. Use emoji icons for consistency
4. Apply the same edit to all seven language files

### Add New Screenshots
1. Copy screenshots from `docs/images/` into `images/screenshots/`
2. Optimize image size (< 500KB recommended)
3. Reference in HTML with `loading="lazy"`
4. All seven languages have their own captures. New screenshots are captured in English only from
   now on, so the other six sets are not re-shot on each release. The canonical Debug slider values
   (66/88/66/66/66 for Claude, 66/88/88 for Codex) are recorded in the
   `capture-usage4claude-screenshots` skill so a later capture matches the existing set.

### Keep in Sync with the App
When the app gains a user-visible feature, these places on the website usually need updating:
- Feature cards on all seven homepages
- The Codex / Claude rows in the menu bar screenshot table
- `privacy.html` + `js/translations-privacy.js`, if the change adds a network request or a new credential type
- `legal.html`, if the product description itself changes

## Performance Optimization

### Image Optimization
- Use tools: TinyPNG, ImageOptim, Squoosh
- Target: Single image < 500KB, total page < 3MB

### Performance Targets
Run Lighthouse test (https://pagespeed.web.dev/):
- Performance: ≥ 90
- Accessibility: ≥ 90
- Best Practices: ≥ 90
- SEO: ≥ 90

## Compliance

### Legal Notice (legal.html)
- ⚠️ Address placeholders: `[NAME_PLACEHOLDER]` and `[ADDRESS_PLACEHOLDER]` in source, replaced by Pages Functions
- ✅ noindex configured: `<meta name="robots" content="noindex, nofollow">`
- ✅ Bilingual: Japanese and English versions provided

### Privacy Policy (privacy.html)
- ✅ Core principle: "We do not collect any user data"
- ✅ Every network request the app makes is listed by endpoint (Claude / Codex / update check / codex-reset.com)
- ✅ Keychain encryption details for both Claude and Codex credentials
- ✅ 7-language support, matching the homepage

## FAQ

### Q: Why not use React/Vue frameworks?
A: For simplicity and performance. Static HTML + Tailwind CSS is sufficient, fastest loading speed, no build step, and easy for AI to maintain.

### Q: How to add more languages?
A: Create a new HTML file (e.g. `index.it.html`), copy from `index.html`, translate all text, then
register it in five places across **every** homepage: the language bar, the `hreflang` links, the
language-detection script, `sitemap.xml`, and - for the legal pages - `js/translations-privacy.js`
plus the language buttons in `privacy.html`.

### Q: How to update Tailwind CSS version?
A: Edit the CDN link in HTML:
```html
<script src="https://cdn.tailwindcss.com"></script>
```

## Technical Support

For issues or questions:
- GitHub Issues: https://github.com/f-is-h/Usage4Claude/issues
- GitHub Discussions: https://github.com/f-is-h/Usage4Claude/discussions

---

**Last Updated**: September 7, 2026
**Maintainer**: f-is-h
