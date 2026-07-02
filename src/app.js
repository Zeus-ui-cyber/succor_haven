// src/app.js
require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const routes  = require('./routes');

const app = express();

app.use(helmet());
app.use(cors({
  origin: (origin, callback) => {
    // Allow any localhost port — all collaborators work without config changes
    // Allow no-origin requests (mobile apps, curl, Postman)
    if (!origin || /^http:\/\/localhost(:\d+)?$/.test(origin)) {
      return callback(null, true);
    }
    // Add your production domain here when deployed:
    // if (origin === 'https://your-app.com') return callback(null, true);
    callback(new Error(`CORS blocked: ${origin}`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());

app.use('/api/v1', routes);

// Health check
app.get('/health', (_, res) => res.json({ status: 'ok' }));

// Global error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Succor Haven API running on port ${PORT}`));

module.exports = app;