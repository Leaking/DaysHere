// 横琴驻留统计 - 后台服务
// 存储策略：sync = 日状态标记, local = GPS 定位日志

importScripts('../utils/location.js', '../utils/holidays.js');

const ALARM_NAME = 'hengqin-location-check';
const CHECK_INTERVAL_MINUTES = 30;

// 扩展安装/更新时初始化
chrome.runtime.onInstalled.addListener((details) => {
  chrome.alarms.create(ALARM_NAME, { periodInMinutes: CHECK_INTERVAL_MINUTES });
  checkLocation();
  // 首次安装或更新时，将旧 local 数据迁移到 sync
  if (details.reason === 'install' || details.reason === 'update') {
    migrateOldData();
  }
});

chrome.runtime.onStartup.addListener(() => {
  chrome.alarms.create(ALARM_NAME, { periodInMinutes: CHECK_INTERVAL_MINUTES });
  checkLocation();
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_NAME) {
    checkLocation();
  }
});

// offscreen document 就绪标志
let offscreenReady = false;
let offscreenReadyResolve = null;

// 后台定位重试标志
let bgRetryPending = false;

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.type === 'SAVE_LOCATION') {
    saveLocationRecord(message.dateStr, message.location)
      .then(() => {
        updateBadge(message.location.inHengqin);
        sendResponse({ success: true });
      });
    return true;
  }
  if (message.type === 'OFFSCREEN_READY') {
    offscreenReady = true;
    if (offscreenReadyResolve) {
      offscreenReadyResolve();
      offscreenReadyResolve = null;
    }
    return;
  }
  if (message.type === 'LOCATION_RESULT') {
    handleLocationResult(message);
    return;
  }
  if (message.type === 'SAVE_ERROR_LOG') {
    saveErrorLog(message.source || 'unknown', message.error, message.code);
    return;
  }
});

async function checkLocation() {
  try {
    await ensureOffscreenDocument();
    await waitForOffscreenReady();
    chrome.runtime.sendMessage({ type: 'GET_LOCATION' });
  } catch (err) {
    console.error('[横琴统计] 定位检查出错:', err);
  }
}

async function handleLocationResult(message) {
  if (message.error) {
    console.warn('[横琴统计] 后台定位失败:', message.error);
    saveErrorLog('background', message.error);

    // 首次失败：等 10s 后重试一次
    if (!bgRetryPending) {
      bgRetryPending = true;
      setTimeout(async () => {
        try {
          console.log('[横琴统计] 后台定位重试...');
          await ensureOffscreenDocument();
          await waitForOffscreenReady();
          chrome.runtime.sendMessage({ type: 'GET_LOCATION' });
        } catch (err) {
          console.error('[横琴统计] 重试出错:', err);
        } finally {
          bgRetryPending = false;
        }
      }, 10000);
    }
    return;
  }

  // 成功时清除重试标志
  bgRetryPending = false;

  const inHengqin = LocationUtils.isInHengqin(message.lat, message.lng);
  const today = HolidayUtils.formatDate(new Date());

  await saveLocationRecord(today, {
    lat: message.lat,
    lng: message.lng,
    time: message.timestamp || Date.now(),
    inHengqin,
  });

  updateBadge(inHengqin);
}

async function ensureOffscreenDocument() {
  const existingContexts = await chrome.runtime.getContexts({
    contextTypes: ['OFFSCREEN_DOCUMENT'],
  });
  if (existingContexts.length > 0) {
    offscreenReady = true;
    return;
  }
  offscreenReady = false;
  await chrome.offscreen.createDocument({
    url: 'offscreen/offscreen.html',
    reasons: ['GEOLOCATION'],
    justification: '获取用户真实物理位置以判断是否在横琴',
  });
}

function waitForOffscreenReady() {
  if (offscreenReady) return Promise.resolve();
  return new Promise((resolve) => {
    offscreenReadyResolve = resolve;
    setTimeout(() => {
      if (offscreenReadyResolve === resolve) {
        offscreenReadyResolve = null;
        resolve();
      }
    }, 5000);
  });
}

/**
 * 保存定位记录
 * - sync: 日状态标记 (day_YYYY-MM-DD)
 * - local: GPS 日志 (loc_YYYY-MM-DD)
 */
async function saveLocationRecord(dateStr, locationRecord) {
  const dayKey = `day_${dateStr}`;
  const locKey = `loc_${dateStr}`;

  // 读取当前数据
  const [syncResult, localResult] = await Promise.all([
    chrome.storage.sync.get(dayKey),
    chrome.storage.local.get(locKey),
  ]);

  const dayStatus = syncResult[dayKey] || { inHengqin: false, isLeave: false, manualHengqin: false };
  const locations = localResult[locKey] || [];

  // 追加 GPS 日志到 local
  locations.push(locationRecord);
  await chrome.storage.local.set({ [locKey]: locations });

  // 更新日状态到 sync（只要有一次在横琴就标记）
  if (locationRecord.inHengqin) {
    dayStatus.inHengqin = true;
  }
  await chrome.storage.sync.set({ [dayKey]: dayStatus });
}

/**
 * 迁移旧版 local 数据到新的 sync + local 分离格式
 */
async function migrateOldData() {
  const localResult = await chrome.storage.local.get(null);
  const syncBatch = {};
  const localBatch = {};
  let hasMigration = false;

  for (const [key, value] of Object.entries(localResult)) {
    if (key.startsWith('day_') && value && typeof value === 'object' && Array.isArray(value.locations)) {
      hasMigration = true;
      const dateStr = key.slice(4);
      const { locations, ...status } = value;
      // 确保 manualHengqin 字段存在
      if (status.manualHengqin === undefined) status.manualHengqin = false;
      syncBatch[key] = status;
      if (locations.length > 0) {
        localBatch[`loc_${dateStr}`] = locations;
      }
    }
  }

  if (hasMigration) {
    await chrome.storage.sync.set(syncBatch);
    await chrome.storage.local.set(localBatch);
    // 清理旧格式的 day_ 数据（从 local 中）
    const oldKeys = Object.keys(localResult).filter(k => k.startsWith('day_'));
    if (oldKeys.length > 0) {
      await chrome.storage.local.remove(oldKeys);
    }
    console.log('[横琴统计] 数据迁移完成，已将', Object.keys(syncBatch).length, '天的数据迁移到 sync');
  }
}

/**
 * 保存定位错误日志到 local storage
 * key: errlog_YYYY-MM-DD，每天最多 20 条
 */
async function saveErrorLog(source, errorMsg, code) {
  const today = HolidayUtils.formatDate(new Date());
  const logKey = `errlog_${today}`;

  const result = await chrome.storage.local.get(logKey);
  const logs = result[logKey] || [];

  logs.push({
    time: new Date().toISOString(),
    source,
    error: String(errorMsg),
    code: code || null,
  });

  // 每天最多 20 条，超出截断旧的
  if (logs.length > 20) {
    logs.splice(0, logs.length - 20);
  }

  await chrome.storage.local.set({ [logKey]: logs });
}

function updateBadge(inHengqin) {
  if (inHengqin) {
    chrome.action.setBadgeText({ text: '琴' });
    chrome.action.setBadgeBackgroundColor({ color: '#4CAF50' });
  } else {
    chrome.action.setBadgeText({ text: '' });
  }
}
