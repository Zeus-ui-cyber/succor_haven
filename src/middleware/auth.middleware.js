// src/middleware/auth.middleware.js
const { verifyAccess } = require("../services/jwt.service");

function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return res
      .status(401)
      .json({ error: "Missing or invalid Authorization header" });
  }
  try {
    req.user = verifyAccess(header.slice(7));
    next();
  } catch {
    res.status(401).json({ error: "Token expired or invalid" });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user?.role)) {
      return res.status(403).json({ error: "Forbidden" });
    }
    next();
  };
}

module.exports = { authenticate, requireRole };
