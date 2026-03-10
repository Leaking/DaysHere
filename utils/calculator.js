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
 * 计算桥接天数
 *
 * 统一桥接规则：将连续的"可桥接空白段"（法定假日、周末休息日、请假日，
 * 且当天未实际在横琴）视为一个整体，若段前一天和段后一天都"实际在横琴"
 * （GPS 或手动标记），则整段计入。
 *
 * 可桥接判定：!isWorkday（假日/周末）或 isLeave（主动请假的工作日）
 * 打断条件：普通工作日（未请假）或实际在横琴的天
 *
 * 这样可以正确处理：纯假日、纯周末、纯请假、以及请假+假日等混合序列。
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
    if (isDayInHengqin(allDayData[`day_${dayBefore}`]) &&
        isDayInHengqin(allDayData[`day_${dayAfter}`])) {
      for (const d of gapBlock) bridgedDays.add(d);
    }
    gapBlock = [];
  };

  for (const dateStr of allDates) {
    const dayData = allDayData[`day_${dateStr}`];
    if (isDayInHengqin(dayData)) {
      // 实际在横琴 → 结算当前空白段（此天本身已在横琴，不进 gap）
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
  isDayInHengqin, calculateBridgedDays, getDayStatus,
  calculateYearStats, calculateMonthStats,
};
