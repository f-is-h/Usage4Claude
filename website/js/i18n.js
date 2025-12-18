let currentLang = localStorage.getItem('preferredLanguage') || 'en';

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
      'zh-TW': 'zh-tw'
    };
    const langSuffix = langSuffixes[lang] || 'zh';

    // 更新图片 src
    const baseSrc = img.src.replace(/-(zh|en|ja|zh-tw)\.(png|jpg|jpeg|webp)/, `.$2`);
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
