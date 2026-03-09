module.exports = {
  apps: [
    {
      name: "tariqi-backend",
      script: "./server.js",
      instances: "max",
      exec_mode: "cluster",
      autorestart: true,
      watch: false,
      max_memory_restart: "1G",
      env: {
        NODE_ENV: "production",
        PORT: 3000,
        PROTOCOL: "http",
      },
    },
  ],
};
