// 横琴粤澳深度合作区中心坐标
const HENGQIN_CENTER = {
  lat: 22.125,
  lng: 113.535,
};

// 判定半径（公里），覆盖整个横琴岛
const HENGQIN_RADIUS_KM = 8;

/**
 * 使用 Haversine 公式计算两点间的距离（公里）
 */
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // 地球平均半径（公里）
  const toRad = (deg) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * 判断给定坐标是否在横琴区域内
 */
function isInHengqin(lat, lng) {
  const distance = haversineDistance(lat, lng, HENGQIN_CENTER.lat, HENGQIN_CENTER.lng);
  return distance <= HENGQIN_RADIUS_KM;
}

/**
 * 计算给定坐标到横琴中心的距离（公里）
 */
function distanceToHengqin(lat, lng) {
  return haversineDistance(lat, lng, HENGQIN_CENTER.lat, HENGQIN_CENTER.lng);
}

self.LocationUtils = { haversineDistance, isInHengqin, distanceToHengqin, HENGQIN_CENTER, HENGQIN_RADIUS_KM };
