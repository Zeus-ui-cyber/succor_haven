// src/services/turn.service.js
//
// Issues short-lived TURN credentials for the coturn server (see
// infra/coturn/ — self-hosted, no Google STUN/TURN, required for China
// deployments). Uses coturn's standard REST-API long-term-credential
// mechanism: username is "<expiryUnixTs>:<userId>", credential is
// base64(HMAC-SHA1(sharedSecret, username)). coturn is configured with
// the matching `static-auth-secret` in turnserver.conf.
// https://github.com/coturn/coturn/blob/master/docs/turn-rest-api.md

const crypto = require("crypto");

const TTL_SECONDS = 3600; // credential lifetime; caller re-requests per session join

function issueCredentials(userId) {
  const secret = process.env.TURN_SECRET;
  const turnUrl = process.env.TURN_URL; // e.g. turn:turn.yourdomain.com:443?transport=tcp
  const stunUrl = process.env.STUN_URL; // e.g. stun:turn.yourdomain.com:3478

  if (!secret || !turnUrl) {
    throw new Error(
      "TURN_SECRET / TURN_URL not configured — see infra/coturn/README.md",
    );
  }

  const expiry = Math.floor(Date.now() / 1000) + TTL_SECONDS;
  const username = `${expiry}:${userId}`;
  const credential = crypto
    .createHmac("sha1", secret)
    .update(username)
    .digest("base64");

  const iceServers = [{ urls: turnUrl, username, credential }];
  if (stunUrl) iceServers.unshift({ urls: stunUrl });

  return { iceServers, ttl: TTL_SECONDS };
}

module.exports = { issueCredentials, TTL_SECONDS };
