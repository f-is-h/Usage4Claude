# Usage4Claude Website

Product website for Usage4Claude macOS application.

## Project Information

- **Tech Stack**: HTML5 + Tailwind CSS (CDN) + Vanilla JS
- **Deployment**: Cloudflare Pages
- **Languages**: English (main), Simplified Chinese, Japanese, Traditional Chinese
- **Website URL**: https://usage4claude.pages.dev (to be deployed)

## Directory Structure

```
website/
├── index.html              # English homepage (main version)
├── index.zh-cn.html        # Simplified Chinese (to be created)
├── index.ja.html           # Japanese (to be created)
├── index.zh-tw.html        # Traditional Chinese (to be created)
├── legal.html              # Legal notice (JP/EN bilingual)
├── privacy.html            # Privacy policy (4 languages)
├── css/
│   └── custom.css          # Custom styles
├── js/
│   ├── main.js             # Basic interactions
│   ├── i18n.js             # Multi-language switching
│   ├── translations.js     # Legal pages translations (legacy)
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
- Other versions: to be created after all adjustments are finalized

### Legal Pages: Single-Page + JS Switching
- `legal.html`: Japanese/English bilingual switching
- `privacy.html`: 4-language switching (EN/ZH-CN/JA/ZH-TW)
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

2. **Replace Address Placeholder**
   - In Cloudflare Pages editor, find `legal.html`
   - Replace `[ADDRESS_PLACEHOLDER]` with actual address
   - Example: `〒100-8111 Tokyo, Chiyoda-ku, Chiyoda 1-1, Japan`

3. **Test Deployment**
   - Visit generated `.pages.dev` URL
   - Test all pages and language switching
   - Check mobile responsiveness

4. **Custom Domain** (Optional)
   - Add custom domain in Pages settings
   - Configure DNS records

## Content Updates

### Update Version Number
Search and replace in `index.html`:
- Current: `v1.6.0`
- Update to: `vX.X.X`

### Add New Features
1. Add feature card in Features section
2. Follow existing HTML structure
3. Use emoji icons for consistency

### Add New Screenshots
1. Copy screenshots to `images/screenshots/`
2. Optimize image size (< 500KB recommended)
3. Reference in HTML with `loading="lazy"`

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
- ⚠️ Address placeholder: Use `[ADDRESS_PLACEHOLDER]` in source
- ✅ noindex configured: `<meta name="robots" content="noindex, nofollow">`
- ✅ Bilingual: Japanese and English versions provided

### Privacy Policy (privacy.html)
- ✅ Core principle: "We do not collect any user data"
- ✅ Local storage explanation
- ✅ Keychain encryption details
- ✅ 4-language support

## FAQ

### Q: Why not use React/Vue frameworks?
A: For simplicity and performance. Static HTML + Tailwind CSS is sufficient, fastest loading speed, no build step, and easy for AI to maintain.

### Q: How to add more languages?
A: Create new HTML file (e.g., `index.ko.html` for Korean) and copy from `index.html`, then translate all text content.

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

**Last Updated**: December 18, 2025
**Maintainer**: f-is-h
