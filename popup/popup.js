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

document.addEventListener('DOMContentLoaded', async () => {
  await loadAllData();
  renderCalendar();
  updateStats();
  checkLocationNow();

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

});

// ─── 数据加载 ───────────────────────────────────────

/**
 * 从 sync + local 合并加载所有日期数据
 */
async function loadAllData() {
  const [syncResult, localResult] = await Promise.all([
    chrome.storage.sync.get(null),
    chrome.storage.local.get(null),
  ]);

  allDayData = {};

  // 先加载 sync 的状态标记
  for (const [key, value] of Object.entries(syncResult)) {
    if (key.startsWith('day_')) {
      allDayData[key] = { ...value, locations: [] };
    }
  }

  // 再合并 local 的 GPS 日志
  for (const [key, value] of Object.entries(localResult)) {
    if (key.startsWith('loc_')) {
      const dayKey = 'day_' + key.slice(4); // loc_2026-01-15 → day_2026-01-15
      if (allDayData[dayKey]) {
        allDayData[dayKey].locations = value || [];
      } else {
        // local 有 GPS 记录但 sync 没有状态（可能是旧数据迁移）
        const hasGpsHengqin = (value || []).some(l => l.inHengqin);
        allDayData[dayKey] = {
          inHengqin: hasGpsHengqin,
          isLeave: false,
          manualHengqin: false,
          locations: value || [],
        };
      }
    }
  }

  bridgedDays = Calculator.calculateBridgedDays(allDayData);
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
    if (status !== 'none') dayEl.classList.add(`status-${status}`);

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
  const dayData = allDayData[key] || { inHengqin: false, isLeave: false, manualHengqin: false, locations: [] };

  dayData.manualHengqin = mark;
  if (mark) {
    dayData.inHengqin = true;
  } else {
    const hasGpsHengqin = dayData.locations && dayData.locations.some(l => l.inHengqin);
    dayData.inHengqin = hasGpsHengqin;
  }

  allDayData[key] = dayData;
  await saveDayStatus(dateStr, dayData);

  bridgedDays = Calculator.calculateBridgedDays(allDayData);
  renderCalendar();
  updateStats();
}

async function applyLeave(dateStr, isLeave) {
  const key = `day_${dateStr}`;
  const dayData = allDayData[key] || { inHengqin: false, isLeave: false, manualHengqin: false, locations: [] };

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

  try {
    const position = await new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: true,
        timeout: 15000,
        maximumAge: 300000,
      });
    });

    const lat = position.coords.latitude;
    const lng = position.coords.longitude;
    const inHengqin = LocationUtils.isInHengqin(lat, lng);
    const today = HolidayUtils.formatDate(new Date());

    // 通知 service worker 保存记录
    await chrome.runtime.sendMessage({
      type: 'SAVE_LOCATION',
      dateStr: today,
      location: { lat, lng, time: position.timestamp || Date.now(), inHengqin },
    });

    if (inHengqin) {
      statusDot.className = 'status-dot active';
      statusText.textContent = '当前在横琴';
    } else {
      statusDot.className = 'status-dot inactive';
      statusText.textContent = '当前不在横琴';
    }

    await loadAllData();
    renderCalendar();
    updateStats();
  } catch (err) {
    statusDot.className = 'status-dot error';
    if (err.code === 1) statusText.textContent = '请允许定位权限';
    else if (err.code === 2) statusText.textContent = '无法获取位置';
    else if (err.code === 3) statusText.textContent = '定位超时';
    else statusText.textContent = '定位异常';
    console.error('定位失败:', err);
  }
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
    lines.push(`定位记录: ${dayData.locations.length}次`);
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
