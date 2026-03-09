const toRad = (degrees) => (degrees * Math.PI) / 180;

const isValidCoord = (coord) =>
  !!(
    coord &&
    typeof coord.lat === "number" &&
    typeof coord.lng === "number" &&
    !isNaN(coord.lat) &&
    !isNaN(coord.lng) &&
    coord.lat >= -90 &&
    coord.lat <= 90 &&
    coord.lng >= -180 &&
    coord.lng <= 180
  );

const haversineDistance = (coord1, coord2) => {
  const R = 6371;
  const dLat = toRad(coord2.lat - coord1.lat);
  const dLng = toRad(coord2.lng - coord1.lng);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(coord1.lat)) *
      Math.cos(toRad(coord2.lat)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

const PRICING = {
  gasPricePerLiter: 15,
  averageGasUsagePer100Km: 13,
  profitMargin: 0.2,
};

const calculatePrice = (distanceKm) => {
  const { gasPricePerLiter, averageGasUsagePer100Km, profitMargin } = PRICING;
  const gasCost =
    (distanceKm / 100) * averageGasUsagePer100Km * gasPricePerLiter;
  return Math.round(gasCost * (1 + profitMargin));
};

module.exports = {
  toRad,
  isValidCoord,
  haversineDistance,
  calculatePrice,
  PRICING,
};
