// Offscreen document 用于后台获取 Geolocation（Service Worker 无法直接访问）

// 告知 service worker 已就绪
chrome.runtime.sendMessage({ type: 'OFFSCREEN_READY' });

// 监听来自 service worker 的定位请求
chrome.runtime.onMessage.addListener((message) => {
  if (message.type === 'GET_LOCATION') {
    getLocation().then((result) => {
      // 通过 sendMessage 把结果发回 service worker
      chrome.runtime.sendMessage({ type: 'LOCATION_RESULT', ...result });
    });
  }
});

async function getLocation() {
  return new Promise((resolve) => {
    if (!navigator.geolocation) {
      resolve({ error: 'Geolocation API 不可用' });
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        resolve({
          lat: position.coords.latitude,
          lng: position.coords.longitude,
          accuracy: position.coords.accuracy,
          timestamp: position.timestamp,
        });
      },
      (error) => {
        resolve({ error: `定位失败: ${error.message} (code: ${error.code})` });
      },
      {
        enableHighAccuracy: true,
        timeout: 15000,
        maximumAge: 300000, // 5分钟缓存
      }
    );
  });
}
