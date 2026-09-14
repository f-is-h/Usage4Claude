// 从 GitHub Releases 拉取最新版本号，填充页面上带 data-latest-version 的元素。
// 元素的属性值是文案模板，{version} 会被替换成实际版本号（如 v3.4.1）。
// 请求失败时保留 HTML 里写死的兜底文案，页面不会出现空白。
(function () {
  const API_URL = 'https://api.github.com/repos/f-is-h/Usage4Claude/releases/latest';
  const CACHE_KEY = 'latestVersion';
  const CACHE_TTL = 6 * 60 * 60 * 1000; // 6 小时，避免频繁打 GitHub API

  function render(version) {
    if (!version) return;
    document.querySelectorAll('[data-latest-version]').forEach(function (el) {
      el.textContent = el.getAttribute('data-latest-version').replace('{version}', version);
    });
  }

  function readCache() {
    try {
      const raw = localStorage.getItem(CACHE_KEY);
      if (!raw) return null;
      const cached = JSON.parse(raw);
      if (Date.now() - cached.time > CACHE_TTL) return null;
      return cached.version;
    } catch (e) {
      return null;
    }
  }

  function writeCache(version) {
    try {
      localStorage.setItem(CACHE_KEY, JSON.stringify({ version: version, time: Date.now() }));
    } catch (e) {
      // 隐私模式下 localStorage 不可写，忽略即可
    }
  }

  document.addEventListener('DOMContentLoaded', function () {
    const cached = readCache();
    if (cached) {
      render(cached);
      return;
    }

    fetch(API_URL, { headers: { Accept: 'application/vnd.github+json' } })
      .then(function (res) { return res.ok ? res.json() : Promise.reject(res.status); })
      .then(function (data) {
        const version = data && data.tag_name;
        if (!version) return;
        render(version);
        writeCache(version);
      })
      .catch(function () {
        // 保留 HTML 中的兜底版本号
      });
  });
})();
