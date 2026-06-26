// src/app.js
require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const routes = require("./routes");

const app = express();

app.use(helmet());
app.use(
  cors({
    origin: [
      "http://localhost:57851", // Flutter web dev
      "http://localhost:3000",
      "http://localhost:4000",
      // Add your production web URL here when deployed:
      // 'https://your-app.com',
    ],
    credentials: true,
    methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  }),
);
app.use(express.json());

app.use("/api/v1", routes);

// Health check
app.get("/health", (_, res) => res.json({ status: "ok" }));

// Global error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Succor Haven API running on port ${PORT}`));

module.exports = app;
