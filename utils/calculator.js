// 横琴驻留天数计算器
// 依赖 holidays.js 中的 HolidayUtils

/**
 * 判断某天是否"实际在横琴"（GPS 或手动标记，不含请假）
 */
function isDayInHengqin(dayData) {
  if (!dayData) return false;
  return dayData.inHengqin;
}

/**
 * 判断某天是否为桥接锚点
 * 只有工作日且在横琴（GPS 或手动）才能作为桥接两端的锚点
 */
function isBridgeAnchor(dateStr, dayData) {
  if (!dayData) return false;
  return HolidayUtils.isWorkday(dateStr) && dayData.inHengqin;
}

/**
 * 计算桥接天数
 *
 * 统一桥接规则：将连续的"可桥接空白段"视为一个整体，若段前一天和段后一天
 * 都是桥接锚点，则整段计入。
 *
 * 锚点：工作日 GPS/手动在横琴，或非工作日手动标记在横琴
 * 可桥接：非工作日（含仅 GPS 检测到的天）或请假工作日
 * 打断：普通工作日（未请假、未在横琴）
 *
 * 非工作日仅 GPS 检测到在横琴的天也进入空白段，桥接成功则计入自然日，
 * 桥接不成立则不计入（与之前行为一致）。
 */
function calculateBridgedDays(allDayData) {
  const bridgedDays = new Set();

  const allDates = [];
  const cur = new Date(2026, 0, 1);
  while (cur.getFullYear() === 2026) {
    allDates.push(HolidayUtils.formatDate(cur));
    cur.setDate(cur.getDate() + 1);
  }

  let gapBlock = []; // 当前连续的可桥接空白段

  const flushGap = () => {
    if (gapBlock.length === 0) return;
    const dayBefore = HolidayUtils.getPrevDay(gapBlock[0]);
    const dayAfter = HolidayUtils.getNextDay(gapBlock[gapBlock.length - 1]);
    if (isBridgeAnchor(dayBefore, allDayData[`day_${dayBefore}`]) &&
        isBridgeAnchor(dayAfter, allDayData[`day_${dayAfter}`])) {
      for (const d of gapBlock) bridgedDays.add(d);
    }
    gapBlock = [];
  };

  for (const dateStr of allDates) {
    const dayData = allDayData[`day_${dateStr}`];
    if (isBridgeAnchor(dateStr, dayData)) {
      // 锚点 → 结算当前空白段
      flushGap();
    } else {
      const isBridgeable = !HolidayUtils.isWorkday(dateStr) || !!(dayData && dayData.isLeave);
      if (isBridgeable) {
        gapBlock.push(dateStr);
      } else {
        // 普通工作日（未请假）→ 打断空白段
        flushGap();
      }
    }
  }
  flushGap();

  return bridgedDays;
}

/**
 * 获取某天的最终状态（考虑桥接）
 * @returns 'hengqin' | 'leave' | 'bridged' | 'none'
 */
function getDayStatus(dateStr, allDayData, bridgedDays) {
  const dayData = allDayData[`day_${dateStr}`];
  const isWorkday = HolidayUtils.isWorkday(dateStr);

  if (isWorkday) {
    // 工作日：GPS/手动 → 绿色；请假桥接 → 蓝色；普通桥接 → 黄色
    if (dayData && dayData.inHengqin) return 'hengqin';
    if (bridgedDays.has(dateStr)) {
      return 'bridged';
    }
  } else {
    // 非工作日（周末/假日）：手动标记在横琴计入，桥接计入，GPS 自动检测不计入
    if (dayData && dayData.manualHengqin) return 'hengqin';
    if (bridgedDays.has(dateStr)) return 'bridged';
  }
  return 'none';
}

/**
 * 计算全年统计
 * @param {Object} allDayData - 所有日期数据 { day_YYYY-MM-DD: { inHengqin, isLeave, locations } }
 * @returns { naturalDays, workdays, bridgedDays, details }
 */
function calculateYearStats(allDayData) {
  const bridgedDays = calculateBridgedDays(allDayData);

  let naturalDays = 0;
  let workdays = 0;
  const details = {};

  // 遍历 2026 年全年
  const startDate = new Date(2026, 0, 1);
  const endDate = new Date(2026, 11, 31);
  const current = new Date(startDate);

  while (current <= endDate) {
    const dateStr = HolidayUtils.formatDate(current);
    const status = getDayStatus(dateStr, allDayData, bridgedDays);

    details[dateStr] = {
      status,
      isWorkday: HolidayUtils.isWorkday(dateStr),
      isHoliday: HolidayUtils.isHoliday(dateStr),
    };

    // 自然日：在横琴 / 请假 / 桥接 都计入
    if (status !== 'none') {
      naturalDays++;
      // 工作日：只统计工作日中在横琴的天数
      if (HolidayUtils.isWorkday(dateStr)) {
        workdays++;
      }
    }

    current.setDate(current.getDate() + 1);
  }

  return { naturalDays, workdays, bridgedDays: [...bridgedDays], details };
}

/**
 * 计算指定月份的统计
 */
function calculateMonthStats(year, month, allDayData, bridgedDays) {
  let naturalDays = 0;
  let workdays = 0;

  const daysInMonth = new Date(year, month, 0).getDate();

  for (let d = 1; d <= daysInMonth; d++) {
    const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const status = getDayStatus(dateStr, allDayData, bridgedDays);

    if (status !== 'none') {
      naturalDays++;
      if (HolidayUtils.isWorkday(dateStr)) {
        workdays++;
      }
    }
  }

  return { naturalDays, workdays };
}

self.Calculator = {
  isDayInHengqin, isBridgeAnchor, calculateBridgedDays, getDayStatus,
  calculateYearStats, calculateMonthStats,
};
