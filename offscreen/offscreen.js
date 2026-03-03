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

    // 先尝试高精度，失败后降级到低精度
    navigator.geolocation.getCurrentPosition(
      (position) => {
        resolve({
          lat: position.coords.latitude,
          lng: position.coords.longitude,
          accuracy: position.coords.accuracy,
          timestamp: position.timestamp,
        });
      },
      (highAccError) => {
        // 高精度失败，尝试低精度（Mac 无 GPS，WiFi/IP 定位即可）
        navigator.geolocation.getCurrentPosition(
          (position) => {
            resolve({
              lat: position.coords.latitude,
              lng: position.coords.longitude,
              accuracy: position.coords.accuracy,
              timestamp: position.timestamp,
            });
          },
          (lowAccError) => {
            resolve({ error: `定位失败: ${lowAccError.message} (code: ${lowAccError.code})` });
          },
          {
            enableHighAccuracy: false,
            timeout: 15000,
            maximumAge: 300000,
          }
        );
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 300000, // 5分钟缓存
      }
    );
  });
}
