module.exports = {
  testEnvironment: "node",
  testTimeout: 30000,
  testPathIgnorePatterns: [
    "/node_modules/",
    "__tests__/setup.js",
    "__tests__/helpers.js",
  ],
  coverageDirectory: "coverage",
  collectCoverageFrom: [
    "controllers/**/*.js",
    "routes/**/*.js",
    "middleware/**/*.js",
    "utils/**/*.js",
    "models/**/*.js",
    "!**/node_modules/**",
  ],
  verbose: true,
};
