const {
  toRad,
  isValidCoord,
  haversineDistance,
  calculatePrice,
  PRICING,
} = require("../../utils/geo");

describe("Geo Utilities", () => {
  describe("toRad", () => {
    it("should convert 0 degrees to 0 radians", () => {
      expect(toRad(0)).toBe(0);
    });

    it("should convert 180 degrees to π radians", () => {
      expect(toRad(180)).toBeCloseTo(Math.PI, 10);
    });

    it("should convert 90 degrees to π/2 radians", () => {
      expect(toRad(90)).toBeCloseTo(Math.PI / 2, 10);
    });

    it("should convert 360 degrees to 2π radians", () => {
      expect(toRad(360)).toBeCloseTo(2 * Math.PI, 10);
    });

    it("should handle negative degrees", () => {
      expect(toRad(-90)).toBeCloseTo(-Math.PI / 2, 10);
    });
  });

  describe("isValidCoord", () => {
    it("should return true for valid coordinates", () => {
      expect(isValidCoord({ lat: 30.0444, lng: 31.2357 })).toBe(true);
    });

    it("should return false for null", () => {
      expect(isValidCoord(null)).toBe(false);
    });

    it("should return false for undefined", () => {
      expect(isValidCoord(undefined)).toBe(false);
    });

    it("should return false for missing lat", () => {
      expect(isValidCoord({ lng: 31.2357 })).toBe(false);
    });

    it("should return false for missing lng", () => {
      expect(isValidCoord({ lat: 30.0444 })).toBe(false);
    });

    it("should return false for string lat", () => {
      expect(isValidCoord({ lat: "30.0444", lng: 31.2357 })).toBe(false);
    });

    it("should return false for string lng", () => {
      expect(isValidCoord({ lat: 30.0444, lng: "31.2357" })).toBe(false);
    });

    it("should return false for lat out of range (> 90)", () => {
      expect(isValidCoord({ lat: 91, lng: 31.2357 })).toBe(false);
    });

    it("should return false for lat out of range (< -90)", () => {
      expect(isValidCoord({ lat: -91, lng: 31.2357 })).toBe(false);
    });

    it("should return false for lng out of range (> 180)", () => {
      expect(isValidCoord({ lat: 30, lng: 181 })).toBe(false);
    });

    it("should return false for lng out of range (< -180)", () => {
      expect(isValidCoord({ lat: 30, lng: -181 })).toBe(false);
    });

    it("should accept boundary values", () => {
      expect(isValidCoord({ lat: 90, lng: 180 })).toBe(true);
      expect(isValidCoord({ lat: -90, lng: -180 })).toBe(true);
      expect(isValidCoord({ lat: 0, lng: 0 })).toBe(true);
    });

    it("should return false for empty object", () => {
      expect(isValidCoord({})).toBe(false);
    });

    it("should return false for NaN values", () => {
      expect(isValidCoord({ lat: NaN, lng: 31 })).toBe(false);
    });
  });

  describe("haversineDistance", () => {
    const CAIRO = { lat: 30.0444, lng: 31.2357 };
    const GIZA = { lat: 30.0131, lng: 31.2089 };
    const ALEXANDRIA = { lat: 31.2001, lng: 29.9187 };
    const NEW_YORK = { lat: 40.7128, lng: -74.006 };
    const LONDON = { lat: 51.5074, lng: -0.1278 };

    it("should return 0 for same point", () => {
      expect(haversineDistance(CAIRO, CAIRO)).toBe(0);
    });

    it("should calculate short distance correctly (Cairo to Giza ~4.5km)", () => {
      const distance = haversineDistance(CAIRO, GIZA);
      expect(distance).toBeGreaterThan(3);
      expect(distance).toBeLessThan(6);
    });

    it("should calculate medium distance correctly (Cairo to Alexandria ~180km)", () => {
      const distance = haversineDistance(CAIRO, ALEXANDRIA);
      expect(distance).toBeGreaterThan(170);
      expect(distance).toBeLessThan(200);
    });

    it("should calculate long distance correctly (New York to London ~5570km)", () => {
      const distance = haversineDistance(NEW_YORK, LONDON);
      expect(distance).toBeGreaterThan(5500);
      expect(distance).toBeLessThan(5700);
    });

    it("should be symmetric (A→B = B→A)", () => {
      const d1 = haversineDistance(CAIRO, GIZA);
      const d2 = haversineDistance(GIZA, CAIRO);
      expect(d1).toBeCloseTo(d2, 10);
    });

    it("should satisfy triangle inequality", () => {
      const ab = haversineDistance(CAIRO, GIZA);
      const bc = haversineDistance(GIZA, ALEXANDRIA);
      const ac = haversineDistance(CAIRO, ALEXANDRIA);
      expect(ac).toBeLessThanOrEqual(ab + bc + 0.001);
    });

    it("should handle antipodal points (~20015km max)", () => {
      const north = { lat: 0, lng: 0 };
      const south = { lat: 0, lng: 180 };
      const distance = haversineDistance(north, south);
      expect(distance).toBeGreaterThan(20000);
      expect(distance).toBeLessThan(20100);
    });

    it("should handle equator points", () => {
      const a = { lat: 0, lng: 0 };
      const b = { lat: 0, lng: 1 };
      const distance = haversineDistance(a, b);
      expect(distance).toBeGreaterThan(110);
      expect(distance).toBeLessThan(112);
    });

    it("should handle pole to equator (~10008km)", () => {
      const pole = { lat: 90, lng: 0 };
      const equator = { lat: 0, lng: 0 };
      const distance = haversineDistance(pole, equator);
      expect(distance).toBeGreaterThan(10000);
      expect(distance).toBeLessThan(10020);
    });

    it("should match known Cairo-to-Giza road-comparable distance", () => {
      const distance = haversineDistance(CAIRO, GIZA);
      // Haversine gives straight-line; road distance is always greater
      // Straight line should be about 4.2km
      expect(distance).toBeCloseTo(4.2, 0);
    });
  });

  describe("calculatePrice", () => {
    it("should return 0 for 0 distance", () => {
      expect(calculatePrice(0)).toBe(0);
    });

    it("should calculate correct price for 10km", () => {
      // (10/100) * 13 * 15 = 19.5 EGP gas cost
      // 19.5 * 1.2 = 23.4 → rounds to 23
      const price = calculatePrice(10);
      expect(price).toBe(23);
    });

    it("should calculate correct price for 100km", () => {
      // (100/100) * 13 * 15 = 195 EGP gas cost
      // 195 * 1.2 = 234
      expect(calculatePrice(100)).toBe(234);
    });

    it("should calculate correct price for 50km", () => {
      // (50/100) * 13 * 15 = 97.5 EGP gas cost
      // 97.5 * 1.2 = 117
      expect(calculatePrice(50)).toBe(117);
    });

    it("should round to nearest integer", () => {
      const price = calculatePrice(1);
      expect(Number.isInteger(price)).toBe(true);
    });

    it("should increase linearly with distance", () => {
      const p10 = calculatePrice(10);
      const p20 = calculatePrice(20);
      const p30 = calculatePrice(30);
      // Rounding can cause ±1 variance
      expect(Math.abs(p20 - p10 * 2)).toBeLessThanOrEqual(1);
      expect(Math.abs(p30 - p10 * 3)).toBeLessThanOrEqual(1);
    });

    it("should include the 20% profit margin", () => {
      const distanceKm = 100;
      const gasCost =
        (distanceKm / 100) *
        PRICING.averageGasUsagePer100Km *
        PRICING.gasPricePerLiter;
      const expected = Math.round(gasCost * (1 + PRICING.profitMargin));
      expect(calculatePrice(distanceKm)).toBe(expected);
    });

    it("should handle fractional distances", () => {
      const price = calculatePrice(7.5);
      expect(price).toBeGreaterThan(0);
      expect(Number.isInteger(price)).toBe(true);
    });

    it("should handle very small distances", () => {
      const price = calculatePrice(0.1);
      expect(price).toBeGreaterThanOrEqual(0);
    });

    it("should handle very large distances", () => {
      const price = calculatePrice(1000);
      expect(price).toBeGreaterThan(2000);
    });
  });

  describe("Integration: distance-to-price pipeline", () => {
    it("should produce reasonable price for Cairo to Giza ride", () => {
      const distance = haversineDistance(
        { lat: 30.0444, lng: 31.2357 },
        { lat: 30.0131, lng: 31.2089 }
      );
      const price = calculatePrice(distance);
      expect(distance).toBeGreaterThan(3);
      expect(distance).toBeLessThan(6);
      expect(price).toBeGreaterThan(5);
      expect(price).toBeLessThan(20);
    });

    it("should produce reasonable price for Cairo to Alexandria ride", () => {
      const distance = haversineDistance(
        { lat: 30.0444, lng: 31.2357 },
        { lat: 31.2001, lng: 29.9187 }
      );
      const price = calculatePrice(distance);
      expect(distance).toBeGreaterThan(170);
      expect(distance).toBeLessThan(200);
      expect(price).toBeGreaterThan(350);
      expect(price).toBeLessThan(500);
    });

    it("should produce monotonically increasing prices for increasing distances", () => {
      const coords = [
        { lat: 30.0444, lng: 31.2357 }, // Cairo
        { lat: 30.0131, lng: 31.2089 }, // Giza
        { lat: 30.0866, lng: 31.3225 }, // Heliopolis
        { lat: 31.2001, lng: 29.9187 }, // Alexandria
      ];
      const base = coords[0];
      const prices = coords
        .slice(1)
        .map((c) => calculatePrice(haversineDistance(base, c)));

      for (let i = 0; i < prices.length - 1; i++) {
        if (
          haversineDistance(base, coords[i + 1]) <
          haversineDistance(base, coords[i + 2])
        ) {
          expect(prices[i]).toBeLessThanOrEqual(prices[i + 1]);
        }
      }
    });
  });
});
