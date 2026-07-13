// src/app.js
require('dotenv').config();
const path = require('path');
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const routes  = require('./routes');
const { initSocketServer } = require('./realtime/socket.server');

const app = express();

// ⚠️ FIXED: helmet's default Content-Security-Policy blocks cross-origin
// loading of static resources (images, PDFs, etc.) by default. Since your
// Flutter web client and this API run on different ports/origins, static
// files served below would otherwise get silently blocked by the browser
// even once express.static() is wired up. crossOriginResourcePolicy set
// to "cross-origin" allows other origins to load files from /uploads.
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

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

// ⚠️ ADDED: this was completely missing. routes/index.js's multer configs
// (profile pictures, and now modules) save uploaded files to
// project-root/uploads/<subfolder>/ and store a relative URL like
// "/uploads/profile-pictures/xyz.jpg" in the database — but nothing was
// ever serving that directory as static files. Every uploaded file
// (profile pictures included, not just the new modules feature) has been
// unreachable via HTTP until now — the file exists on disk, the DB row
// points at the right path, but a GET request to it 404s because no route
// or middleware handles it. This single line covers every subfolder
// under uploads/ (profile-pictures, modules, and any future ones) without
// needing a separate express.static() call per feature.
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.use('/api/v1', routes);

// Health check
app.get('/health', (_, res) => res.json({ status: 'ok' }));

// Global error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => console.log(`Succor Haven API running on port ${PORT}`));

// Socket.IO attaches to the same HTTP server/port rather than opening a
// second listener — one process, one port, same as everything else here.
initSocketServer(server);

module.exports = app;