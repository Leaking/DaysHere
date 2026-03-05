// 横琴驻留统计 - Popup 主逻辑
//
// 存储策略：
//   chrome.storage.sync  → 日状态标记 (inHengqin, isLeave, manualHengqin)，跨设备同步
//   chrome.storage.local → GPS 定位日志 (locations 数组)，仅本地

let currentYear = 2026;
let currentMonth = new Date().getMonth() + 1; // 1-12
let allDayData = {};   // 合并后的数据，key = "day_YYYY-MM-DD"
let bridgedDays = new Set();

// 如果当前不是2026年，默认显示1月
if (new Date().getFullYear() !== 2026) {
  currentMonth = 1;
}

document.addEventListener('DOMContentLoaded', () => {
  // 先渲染空日历，让 popup 秒开
  renderCalendar();

  // 异步加载 sync 数据（轻量）后刷新
  loadAllData().then(() => {
    renderCalendar();
    updateStats();
    checkLocationNow();
    // GPS 日志延迟加载，不阻塞 UI
    setTimeout(loadGpsLogs, 0);
  });

  document.getElementById('prevMonth').addEventListener('click', () => {
    if (currentMonth > 1) {
      currentMonth--;
      renderCalendar();
      updateMonthStats();
    }
  });

  document.getElementById('nextMonth').addEventListener('click', () => {
    if (currentMonth < 12) {
      currentMonth++;
      renderCalendar();
      updateMonthStats();
    }
  });

  document.getElementById('exportBtn').addEventListener('click', exportData);
  document.getElementById('importBtn').addEventListener('click', () => {
    document.getElementById('importFile').click();
  });
  document.getElementById('exportLogsBtn').addEventListener('click', exportDebugLogs);
  document.getElementById('importFile').addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
      importData(e.target.files[0]);
      e.target.value = '';
    }
  });

});

// ─── 数据加载 ───────────────────────────────────────

/**
 * 快速加载：只读 sync 日状态（~29KB），跳过 GPS 日志
 */
async function loadAllData() {
  const syncResult = await chrome.storage.sync.get(null);

  allDayData = {};
  for (const [key, value] of Object.entries(syncResult)) {
    if (key.startsWith('day_')) {
      allDayData[key] = { ...value, locations: null };
    }
  }

  bridgedDays = Calculator.calculateBridgedDays(allDayData);
}

/**
 * 延迟加载 GPS 日志到内存，补全孤立的 local 记录
 */
let gpsLogsLoaded = false;
async function loadGpsLogs() {
  if (gpsLogsLoaded) return;
  const localResult = await chrome.storage.local.get(null);
  let changed = false;

  for (const [key, value] of Object.entries(localResult)) {
    if (key.startsWith('loc_')) {
      const dayKey = 'day_' + key.slice(4);
      if (allDayData[dayKey]) {
        allDayData[dayKey].locations = value || [];
      } else {
        const hasGpsHengqin = (value || []).some(l => l.inHengqin);
        if (hasGpsHengqin) {
          allDayData[dayKey] = {
            inHengqin: true, isLeave: false, manualHengqin: false,
            locations: value || [],
          };
          changed = true;
        }
      }
    }
  }

  gpsLogsLoaded = true;
  if (changed) {
    bridgedDays = Calculator.calculateBridgedDays(allDayData);
    renderCalendar();
    updateStats();
  }
}

/**
 * 按需加载单天 GPS 日志（用于取消手动标记时的回退判断）
 */
async function ensureDayLocations(dateStr) {
  const dayKey = `day_${dateStr}`;
  if (allDayData[dayKey] && allDayData[dayKey].locations) {
    return allDayData[dayKey].locations;
  }
  const locKey = `loc_${dateStr}`;
  const result = await chrome.storage.local.get(locKey);
  const locations = result[locKey] || [];
  if (allDayData[dayKey]) {
    allDayData[dayKey].locations = locations;
  }
  return locations;
}

/**
 * 保存某天的状态标记到 sync
 */
async function saveDayStatus(dateStr, dayData) {
  const key = `day_${dateStr}`;
  // sync 只存状态，不存 locations
  const { locations, ...status } = dayData;
  await chrome.storage.sync.set({ [key]: status });
}

// ─── 日历渲染 ───────────────────────────────────────

function renderCalendar() {
  const body = document.getElementById('calendarBody');
  body.innerHTML = '';

  const monthNames = ['1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月'];
  document.getElementById('monthTitle').textContent =
    `${currentYear}年${monthNames[currentMonth - 1]}`;

  const firstDay = new Date(currentYear, currentMonth - 1, 1).getDay();
  const startOffset = firstDay === 0 ? 6 : firstDay - 1;
  const daysInMonth = new Date(currentYear, currentMonth, 0).getDate();

  for (let i = 0; i < startOffset; i++) {
    const empty = document.createElement('div');
    empty.className = 'calendar-day empty';
    body.appendChild(empty);
  }

  const today = HolidayUtils.formatDate(new Date());

  for (let d = 1; d <= daysInMonth; d++) {
    const dateStr = `${currentYear}-${String(currentMonth).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const dayEl = document.createElement('div');
    dayEl.className = 'calendar-day';
    dayEl.textContent = d;
    dayEl.dataset.date = dateStr;

    if (dateStr === today) dayEl.classList.add('today');
    if (!HolidayUtils.isWorkday(dateStr)) dayEl.classList.add('non-workday');

    const status = Calculator.getDayStatus(dateStr, allDayData, bridgedDays);
    if (status !== 'none') {
      dayEl.classList.add(`status-${status}`);
    } else if (dateStr < today) {
      dayEl.classList.add('status-absent');
    }

    if (HolidayUtils.isHoliday(dateStr)) {
      const badge = document.createElement('span');
      badge.className = 'holiday-badge';
      badge.textContent = '休';
      dayEl.appendChild(badge);
    }

    if (HolidayUtils.WORKDAY_OVERRIDES_2026.has(dateStr)) {
      const badge = document.createElement('span');
      badge.className = 'work-override-badge';
      badge.textContent = '班';
      dayEl.appendChild(badge);
    }

    const dayData = allDayData[`day_${dateStr}`];
    if (dayData && dayData.manualHengqin) {
      const badge = document.createElement('span');
      badge.className = 'manual-badge';
      badge.textContent = '标';
      dayEl.appendChild(badge);
    }
    if (dayData && dayData.isLeave) {
      const badge = document.createElement('span');
      badge.className = 'leave-badge';
      badge.textContent = '假';
      dayEl.appendChild(badge);
    }

    dayEl.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      showContextMenu(e, dateStr);
    });
    dayEl.addEventListener('mouseenter', (e) => showTooltip(e, dateStr));
    dayEl.addEventListener('mouseleave', hideTooltip);

    body.appendChild(dayEl);
  }

  updateMonthStats();
}

// ─── 右键菜单 ───────────────────────────────────────

let contextMenuEl = null;

function showContextMenu(event, dateStr) {
  hideContextMenu();

  const dayData = allDayData[`day_${dateStr}`];
  const isLeave = dayData && dayData.isLeave;
  const isManualHengqin = dayData && dayData.manualHengqin;

  contextMenuEl = document.createElement('div');
  contextMenuEl.className = 'context-menu';

  const header = document.createElement('div');
  header.className = 'context-menu-header';
  header.textContent = dateStr;
  contextMenuEl.appendChild(header);

  const hengqinItem = document.createElement('div');
  hengqinItem.className = 'context-menu-item';
  hengqinItem.textContent = isManualHengqin ? '取消在横琴标记' : '标记在横琴';
  hengqinItem.addEventListener('click', () => {
    hideContextMenu();
    applyManualHengqin(dateStr, !isManualHengqin);
  });
  contextMenuEl.appendChild(hengqinItem);

  const divider = document.createElement('div');
  divider.className = 'context-menu-divider';
  contextMenuEl.appendChild(divider);

  const leaveItem = document.createElement('div');
  leaveItem.className = 'context-menu-item';
  leaveItem.textContent = isLeave ? '取消请假' : '标记请假';
  leaveItem.addEventListener('click', () => {
    hideContextMenu();
    applyLeave(dateStr, !isLeave);
  });
  contextMenuEl.appendChild(leaveItem);

  document.body.appendChild(contextMenuEl);

  const x = event.clientX;
  const y = event.clientY;
  contextMenuEl.style.left = `${x}px`;
  contextMenuEl.style.top = `${y}px`;

  requestAnimationFrame(() => {
    const rect = contextMenuEl.getBoundingClientRect();
    if (rect.right > document.body.clientWidth) {
      contextMenuEl.style.left = `${document.body.clientWidth - rect.width - 4}px`;
    }
    if (rect.bottom > document.body.clientHeight) {
      contextMenuEl.style.top = `${y - rect.height}px`;
    }
  });

  setTimeout(() => {
    document.addEventListener('click', onClickOutsideMenu);
    document.addEventListener('contextmenu', onClickOutsideMenu);
  }, 0);
}

function onClickOutsideMenu(e) {
  if (contextMenuEl && !contextMenuEl.contains(e.target)) {
    hideContextMenu();
  }
}

function hideContextMenu() {
  if (contextMenuEl) {
    contextMenuEl.remove();
    contextMenuEl = null;
    document.removeEventListener('click', onClickOutsideMenu);
    document.removeEventListener('contextmenu', onClickOutsideMenu);
  }
}

// ─── 标记操作 ───────────────────────────────────────

async function applyManualHengqin(dateStr, mark) {
  const key = `day_${dateStr}`;
  const dayData = allDayData[key] || { inHengqin: false, isLeave: false, manualHengqin: false, locations: null };

  dayData.manualHengqin = mark;
  if (mark) {
    dayData.inHengqin = true;
  } else {
    // 取消手动标记时，按需加载 GPS 日志判断是否保留
    const locations = await ensureDayLocations(dateStr);
    dayData.inHengqin = locations.some(l => l.inHengqin);
  }

  allDayData[key] = dayData;
  await saveDayStatus(dateStr, dayData);

  bridgedDays = Calculator.calculateBridgedDays(allDayData);
  renderCalendar();
  updateStats();
}

async function applyLeave(dateStr, isLeave) {
  const key = `day_${dateStr}`;
  const dayData = allDayData[key] || { inHengqin: false, isLeave: false, manualHengqin: false, locations: null };

  dayData.isLeave = isLeave;
  allDayData[key] = dayData;

  await saveDayStatus(dateStr, dayData);

  bridgedDays = Calculator.calculateBridgedDays(allDayData);
  renderCalendar();
  updateStats();
}

// ─── 统计 ───────────────────────────────────────────

function updateStats() {
  const stats = Calculator.calculateYearStats(allDayData);
  document.getElementById('naturalDays').textContent = stats.naturalDays;
  document.getElementById('workDays').textContent = stats.workdays;
}

function updateMonthStats() {
  const monthStats = Calculator.calculateMonthStats(currentYear, currentMonth, allDayData, bridgedDays);
  document.getElementById('monthNatural').textContent = monthStats.naturalDays;
  document.getElementById('monthWork').textContent = monthStats.workdays;
}

// ─── 定位 ───────────────────────────────────────────

function popupGeoPromise(highAccuracy, timeout) {
  return new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(resolve, reject, {
      enableHighAccuracy: highAccuracy,
      timeout,
      maximumAge: 300000,
    });
  });
}

/**
 * 尝试一轮定位：高精度(10s) → 低精度(30s)
 */
async function tryGetPosition() {
  try {
    return await popupGeoPromise(true, 10000);
  } catch (_highErr) {
    // 高精度失败，降级到低精度
  }
  return await popupGeoPromise(false, 30000);
}

async function checkLocationNow() {
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');

  statusDot.className = 'status-dot';
  statusText.textContent = '定位中...';

  if (!navigator.geolocation) {
    statusDot.className = 'status-dot error';
    statusText.textContent = '浏览器不支持定位';
    return;
  }

  let position;
  try {
    position = await tryGetPosition();
  } catch (firstErr) {
    // 首次失败，等 3s 重试一次
    statusText.textContent = '重试定位中...';
    await new Promise((r) => setTimeout(r, 3000));
    try {
      position = await tryGetPosition();
    } catch (retryErr) {
      statusDot.className = 'status-dot error';
      if (retryErr.code === 1) statusText.textContent = '请允许定位权限';
      else if (retryErr.code === 2) statusText.textContent = '无法获取位置';
      else if (retryErr.code === 3) statusText.textContent = '定位超时';
      else statusText.textContent = '定位异常';
      console.error('定位失败（重试后）:', retryErr);

      // 写错误日志到 storage
      chrome.runtime.sendMessage({
        type: 'SAVE_ERROR_LOG',
        source: 'popup',
        error: retryErr.message || String(retryErr),
        code: retryErr.code || null,
      });
      return;
    }
  }

  const lat = position.coords.latitude;
  const lng = position.coords.longitude;
  const inHengqin = LocationUtils.isInHengqin(lat, lng);
  const today = HolidayUtils.formatDate(new Date());
  const locationRecord = { lat, lng, time: position.timestamp || Date.now(), inHengqin };

  // 直接更新本地数据，立即标记
  const dayKey = `day_${today}`;
  if (!allDayData[dayKey]) {
    allDayData[dayKey] = { inHengqin: false, isLeave: false, manualHengqin: false, locations: [] };
  }
  if (inHengqin) {
    allDayData[dayKey].inHengqin = true;
  }
  if (!allDayData[dayKey].locations) allDayData[dayKey].locations = [];
  allDayData[dayKey].locations.push(locationRecord);

  if (inHengqin) {
    statusDot.className = 'status-dot active';
    statusText.textContent = '当前在横琴';
  } else {
    statusDot.className = 'status-dot inactive';
    statusText.textContent = '当前不在横琴';
  }

  // 立即重算桥接 + 渲染
  bridgedDays = Calculator.calculateBridgedDays(allDayData);
  renderCalendar();
  updateStats();

  // 后台持久化到 service worker（不阻塞 UI）
  chrome.runtime.sendMessage({
    type: 'SAVE_LOCATION',
    dateStr: today,
    location: locationRecord,
  });
}

// ─── Tooltip ────────────────────────────────────────

let tooltipEl = null;

function showTooltip(event, dateStr) {
  hideTooltip();

  const dayData = allDayData[`day_${dateStr}`];
  const status = Calculator.getDayStatus(dateStr, allDayData, bridgedDays);
  const isWorkday = HolidayUtils.isWorkday(dateStr);
  const isHoliday = HolidayUtils.isHoliday(dateStr);

  let lines = [dateStr];

  if (isHoliday) lines.push('法定假日');
  else if (!isWorkday) lines.push('周末');
  if (HolidayUtils.WORKDAY_OVERRIDES_2026.has(dateStr)) lines.push('调休上班');
  if (isWorkday && !HolidayUtils.WORKDAY_OVERRIDES_2026.has(dateStr) && !isHoliday) lines.push('工作日');

  if (status === 'hengqin') {
    if (dayData && dayData.manualHengqin) lines.push('✓ 手动标记在横琴');
    else lines.push('✓ 定位确认在横琴');
  } else if (status === 'leave') {
    lines.push('✓ 请假（算横琴）');
  } else if (status === 'bridged') {
    lines.push('✓ 假期桥接（算横琴）');
  }

  if (dayData && dayData.locations && dayData.locations.length > 0) {
    lines.push(`定位: ${dayData.locations.length}次`);
  }

  lines.push('右键 → 标记/请假');

  tooltipEl = document.createElement('div');
  tooltipEl.className = 'day-tooltip';
  tooltipEl.innerHTML = lines.join('<br>');
  document.body.appendChild(tooltipEl);

  const rect = event.target.getBoundingClientRect();
  tooltipEl.style.left = `${rect.left}px`;
  tooltipEl.style.top = `${rect.bottom + 4}px`;

  const tipRect = tooltipEl.getBoundingClientRect();
  if (tipRect.right > document.body.clientWidth) {
    tooltipEl.style.left = `${document.body.clientWidth - tipRect.width - 4}px`;
  }
}

function hideTooltip() {
  if (tooltipEl) {
    tooltipEl.remove();
    tooltipEl = null;
  }
}

// ─── 导出/导入 ──────────────────────────────────────

function showDataMsg(text, isError) {
  const el = document.getElementById('dataMsg');
  el.textContent = text;
  el.className = isError ? 'data-msg error' : 'data-msg';
  setTimeout(() => { el.textContent = ''; }, 3000);
}

async function exportData() {
  const syncResult = await chrome.storage.sync.get(null);
  const data = {};
  for (const [key, value] of Object.entries(syncResult)) {
    if (key.startsWith('day_')) {
      data[key] = value;
    }
  }

  if (Object.keys(data).length === 0) {
    showDataMsg('暂无数据可导出', true);
    return;
  }

  const exportObj = {
    version: 1,
    exportDate: new Date().toISOString(),
    data,
  };

  const blob = new Blob([JSON.stringify(exportObj, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `hq-backup-${HolidayUtils.formatDate(new Date())}.json`;
  a.click();
  URL.revokeObjectURL(url);
  showDataMsg('导出成功');
}

async function importData(file) {
  let text;
  try {
    text = await file.text();
  } catch {
    showDataMsg('文件读取失败', true);
    return;
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    showDataMsg('JSON 格式错误', true);
    return;
  }

  if (!parsed || parsed.version !== 1 || typeof parsed.data !== 'object') {
    showDataMsg('无效的备份文件', true);
    return;
  }

  const entries = {};
  for (const [key, value] of Object.entries(parsed.data)) {
    if (key.startsWith('day_') && typeof value === 'object') {
      entries[key] = value;
    }
  }

  if (Object.keys(entries).length === 0) {
    showDataMsg('备份文件中无有效数据', true);
    return;
  }

  await chrome.storage.sync.set(entries);
  await loadAllData();
  renderCalendar();
  updateStats();
  showDataMsg(`导入成功，恢复 ${Object.keys(entries).length} 天数据`);
}

async function exportDebugLogs() {
  const localResult = await chrome.storage.local.get(null);
  const logs = { gps: {}, errors: {} };

  for (const [key, value] of Object.entries(localResult)) {
    if (key.startsWith('loc_')) {
      logs.gps[key] = value;
    } else if (key.startsWith('errlog_')) {
      logs.errors[key] = value;
    }
  }

  const gpsCount = Object.keys(logs.gps).length;
  const errCount = Object.keys(logs.errors).length;

  if (gpsCount === 0 && errCount === 0) {
    showDataMsg('暂无调试日志', true);
    return;
  }

  const exportObj = {
    exportDate: new Date().toISOString(),
    summary: { gpsDays: gpsCount, errorDays: errCount },
    ...logs,
  };

  const blob = new Blob([JSON.stringify(exportObj, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `hq-debug-${HolidayUtils.formatDate(new Date())}.json`;
  a.click();
  URL.revokeObjectURL(url);
  showDataMsg(`导出 ${gpsCount} 天定位 + ${errCount} 天错误日志`);
}
