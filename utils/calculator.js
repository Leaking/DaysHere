// 横琴驻留天数计算器
// 依赖 holidays.js 中的 HolidayUtils

/**
 * 判断某天是否"在横琴"（直接检测到 或 请假）
 */
function isDayInHengqin(dayData) {
  if (!dayData) return false;
  return dayData.inHengqin || dayData.isLeave;
}

/**
 * 计算假期桥接天数
 * 规则：如果假期前一天和假期后一天都在横琴，则假期内所有天数都算在横琴
 * 返回需要桥接的日期集合
 */
function calculateBridgedDays(allDayData) {
  const bridgedDays = new Set();
  const periods = HolidayUtils.getHolidayPeriods();

  for (const period of periods) {
    const dayBefore = HolidayUtils.getPrevDay(period.start);
    const dayAfter = HolidayUtils.getNextDay(period.end);

    const beforeData = allDayData[`day_${dayBefore}`];
    const afterData = allDayData[`day_${dayAfter}`];

    // 假期前一天和后一天都在横琴 → 桥接整个假期段
    if (isDayInHengqin(beforeData) && isDayInHengqin(afterData)) {
      const datesInPeriod = HolidayUtils.getDateRange(period.start, period.end);
      for (const dateStr of datesInPeriod) {
        // 只桥接那些本身不在横琴的天
        const dayData = allDayData[`day_${dateStr}`];
        if (!isDayInHengqin(dayData)) {
          bridgedDays.add(dateStr);
        }
      }
    }
  }

  return bridgedDays;
}

/**
 * 获取某天的最终状态（考虑桥接）
 * @returns 'hengqin' | 'leave' | 'bridged' | 'none'
 */
function getDayStatus(dateStr, allDayData, bridgedDays) {
  const dayData = allDayData[`day_${dateStr}`];

  if (dayData && dayData.isLeave) return 'leave';
  if (dayData && dayData.inHengqin) return 'hengqin';
  if (bridgedDays.has(dateStr)) return 'bridged';
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
  isDayInHengqin, calculateBridgedDays, getDayStatus,
  calculateYearStats, calculateMonthStats,
};
