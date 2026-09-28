// 语言菜单：记住用户手动选的语言。首页 / 的语言跳转在 functions/_middleware.js 里，
// 有这个 cookie 就按它走，没有才看浏览器的 Accept-Language
(function () {
  const COOKIE = 'u4c_lang';
  const ONE_YEAR = 60 * 60 * 24 * 365;

  document.querySelectorAll('[data-lang]').forEach(function (link) {
    link.addEventListener('click', function () {
      document.cookie = COOKIE + '=' + link.dataset.lang + '; path=/; max-age=' + ONE_YEAR + '; samesite=lax';
    });
  });

  // 点菜单外面或按 Esc 时收起
  const menu = document.querySelector('.lang-menu');
  if (!menu) return;
  document.addEventListener('click', function (event) {
    if (menu.open && !menu.contains(event.target)) menu.open = false;
  });
  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && menu.open) {
      menu.open = false;
      menu.querySelector('summary').focus();
    }
  });
})();
