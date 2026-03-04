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

function geoPromise(highAccuracy, timeout) {
  return new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(resolve, reject, {
      enableHighAccuracy: highAccuracy,
      timeout,
      maximumAge: 300000,
    });
  });
}

function positionResult(position) {
  return {
    lat: position.coords.latitude,
    lng: position.coords.longitude,
    accuracy: position.coords.accuracy,
    timestamp: position.timestamp,
  };
}

function delay(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function getLocation() {
  if (!navigator.geolocation) {
    return { error: 'Geolocation API 不可用', timestamp: Date.now() };
  }

  // 高精度(10s) → 低精度(30s) → 等3s → 再试低精度(30s) → 放弃
  try {
    return positionResult(await geoPromise(true, 10000));
  } catch (_highErr) {
    // 高精度失败，尝试低精度
  }

  try {
    return positionResult(await geoPromise(false, 30000));
  } catch (_lowErr) {
    // 低精度也失败，等 3s 重试一次
  }

  await delay(3000);

  try {
    return positionResult(await geoPromise(false, 30000));
  } catch (retryErr) {
    return {
      error: `定位失败: ${retryErr.message} (code: ${retryErr.code})`,
      timestamp: Date.now(),
    };
  }
}
