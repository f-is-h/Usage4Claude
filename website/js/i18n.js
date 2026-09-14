// 首次访问时按浏览器语言选择，之后沿用用户在本页选过的语言
function detectLanguage() {
  const saved = localStorage.getItem('preferredLanguage');
  if (saved) return saved;

  const browserLang = (navigator.language || navigator.userLanguage || 'en').toLowerCase();
  const langMap = {
    'zh-cn': 'zh-CN', 'zh-sg': 'zh-CN', 'zh': 'zh-CN',
    'zh-tw': 'zh-TW', 'zh-hk': 'zh-TW', 'zh-mo': 'zh-TW',
    'ja': 'ja', 'ko': 'ko', 'fr': 'fr', 'de': 'de'
  };
  return langMap[browserLang] || langMap[browserLang.split('-')[0]] || 'en';
}

let currentLang = detectLanguage();

function switchLanguage(lang) {
  currentLang = lang;
  document.documentElement.lang = lang;

  // 更新所有 data-i18n 元素
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (translations[lang] && translations[lang][key]) {
      el.textContent = translations[lang][key];
    }
  });

  // 更新图片（不同语言的截图）
  document.querySelectorAll('[data-i18n-img]').forEach(img => {
    const baseKey = img.getAttribute('data-i18n-img');
    // 语言后缀映射
    const langSuffixes = {
      'zh-CN': 'zh',
      'en': 'en',
      'ja': 'ja',
      'ko': 'ko',
      'zh-TW': 'zh-tw'
    };
    const langSuffix = langSuffixes[lang] || 'zh';

    // 更新图片 src
    const baseSrc = img.src.replace(/-(zh|en|ja|ko|zh-tw)\.(png|jpg|jpeg|webp)/, `.$2`);
    const newSrc = baseSrc.replace(/\.(png|jpg|jpeg|webp)/, `-${langSuffix}.$1`);
    img.src = newSrc;
  });

  // 更新语言切换按钮状态
  document.querySelectorAll('.lang-btn').forEach(btn => {
    if (btn.dataset.lang === lang) {
      btn.classList.add('active', 'text-[#CC785C]', 'font-semibold');
    } else {
      btn.classList.remove('active', 'text-[#CC785C]', 'font-semibold');
      btn.classList.add('text-gray-500');
    }
  });

  // 保存到 localStorage
  localStorage.setItem('preferredLanguage', lang);

  console.log(`Language switched to: ${lang}`);
}

// 页面加载时应用保存的语言偏好
document.addEventListener('DOMContentLoaded', () => {
  switchLanguage(currentLang);
});
