// 2026年中国法定节假日安排（国务院办公厅发布）
// 数据来源：国务院办公厅关于2026年部分节假日安排的通知

// 法定假日集合（放假的日期）
const HOLIDAYS_2026 = new Set([
  // 元旦 1/1~1/3
  '2026-01-01', '2026-01-02', '2026-01-03',
  // 春节 2/15~2/23
  '2026-02-15', '2026-02-16', '2026-02-17', '2026-02-18',
  '2026-02-19', '2026-02-20', '2026-02-21', '2026-02-22', '2026-02-23',
  // 清明节 4/4~4/6
  '2026-04-04', '2026-04-05', '2026-04-06',
  // 劳动节 5/1~5/5
  '2026-05-01', '2026-05-02', '2026-05-03', '2026-05-04', '2026-05-05',
  // 端午节 6/19~6/21
  '2026-06-19', '2026-06-20', '2026-06-21',
  // 中秋节 9/25~9/27
  '2026-09-25', '2026-09-26', '2026-09-27',
  // 国庆节 10/1~10/7
  '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04',
  '2026-10-05', '2026-10-06', '2026-10-07',
]);

// 调休上班日（周末但需要上班）
const WORKDAY_OVERRIDES_2026 = new Set([
  '2026-01-04', // 元旦调休，周日上班
  '2026-02-14', // 春节调休，周六上班
  '2026-02-28', // 春节调休，周六上班
  '2026-05-09', // 劳动节调休，周六上班
  '2026-09-20', // 国庆调休，周日上班
  '2026-10-10', // 国庆调休，周六上班
]);

// 假期段定义（用于桥接规则计算）
// 每段包含连续的非工作日（假期+相邻周末）
const HOLIDAY_PERIODS_2026 = [
  // 元旦：1/1(四)~1/3(六)，1/4(日)上班，所以假期段就是1/1~1/3
  { name: '元旦', start: '2026-01-01', end: '2026-01-03' },
  // 春节：2/15(日)~2/23(一)，2/14(六)上班，2/24(二)正常上班
  { name: '春节', start: '2026-02-15', end: '2026-02-23' },
  // 清明：4/4(六)~4/6(一)
  { name: '清明节', start: '2026-04-04', end: '2026-04-06' },
  // 劳动节：5/1(五)~5/5(二)，但5/3是周日本身放假
  { name: '劳动节', start: '2026-05-01', end: '2026-05-05' },
  // 端午：6/19(五)~6/21(日)
  { name: '端午节', start: '2026-06-19', end: '2026-06-21' },
  // 中秋：9/25(五)~9/27(日)
  { name: '中秋节', start: '2026-09-25', end: '2026-09-27' },
  // 国庆：10/1(四)~10/7(三)，但9/27(日)是周末也放假，
  // 9/28(一)~9/30(三)是工作日，所以国庆假期段就是10/1~10/8（10/8是周四需上班）
  // 实际上10/8(四)~10/9(五)是工作日，10/10(六)上班
  // 所以国庆假期段就是10/1~10/7
  { name: '国庆节', start: '2026-10-01', end: '2026-10-07' },
];

/**
 * 格式化日期为 YYYY-MM-DD 字符串
 */
function formatDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * 解析 YYYY-MM-DD 字符串为 Date 对象（本地时间）
 */
function parseDate(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(y, m - 1, d);
}

/**
 * 判断某天是否为法定假日
 */
function isHoliday(dateStr) {
  return HOLIDAYS_2026.has(dateStr);
}

/**
 * 判断某天是否为工作日
 * 工作日 = (周一~周五 且 非法定假日) 或 调休上班日
 */
function isWorkday(dateStr) {
  // 调休上班日一定是工作日
  if (WORKDAY_OVERRIDES_2026.has(dateStr)) {
    return true;
  }
  // 法定假日一定不是工作日
  if (HOLIDAYS_2026.has(dateStr)) {
    return false;
  }
  // 周六日默认不是工作日
  const date = parseDate(dateStr);
  const day = date.getDay();
  return day >= 1 && day <= 5;
}

/**
 * 判断某天是否为非工作日（周末或假日，排除调休上班日）
 */
function isNonWorkday(dateStr) {
  return !isWorkday(dateStr);
}

/**
 * 获取所有假期段
 */
function getHolidayPeriods() {
  return HOLIDAY_PERIODS_2026;
}

/**
 * 获取某天的前一天日期字符串
 */
function getPrevDay(dateStr) {
  const date = parseDate(dateStr);
  date.setDate(date.getDate() - 1);
  return formatDate(date);
}

/**
 * 获取某天的后一天日期字符串
 */
function getNextDay(dateStr) {
  const date = parseDate(dateStr);
  date.setDate(date.getDate() + 1);
  return formatDate(date);
}

/**
 * 获取两个日期之间的所有日期（含首尾）
 */
function getDateRange(startStr, endStr) {
  const dates = [];
  const start = parseDate(startStr);
  const end = parseDate(endStr);
  const current = new Date(start);
  while (current <= end) {
    dates.push(formatDate(current));
    current.setDate(current.getDate() + 1);
  }
  return dates;
}

// 导出（在 Chrome extension 中通过 importScripts 或 ES module 使用）
// self 在浏览器页面中等于 window，在 Service Worker 中等于 globalThis
self.HolidayUtils = {
  formatDate, parseDate, isHoliday, isWorkday, isNonWorkday,
  getHolidayPeriods, getPrevDay, getNextDay, getDateRange,
  HOLIDAYS_2026, WORKDAY_OVERRIDES_2026,
};
