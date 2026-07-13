# Self-hosted STUN/TURN (coturn)

Required so WebRTC works without depending on any Google infrastructure
(the whole point of this feature for China-compatible deployment) and so
peers behind restrictive NATs/firewalls can still connect.

## Setup

1. Provision a small VPS with a public IP, ideally hosted somewhere already
   reachable from mainland China. Open ports 3478/udp+tcp, 443/tcp+udp, and
   the relay range 49152-49452/udp in its firewall/security group.
2. Get a TLS cert for the domain you'll point clients at (e.g. Let's Encrypt).
3. Copy `turnserver.conf`, fill in `external-ip`, `static-auth-secret`
   (generate with `openssl rand -hex 32`), and the `cert`/`pkey` paths.
4. Put the same `static-auth-secret` value into the API's `.env` as
   `TURN_SECRET`. Set `TURN_URL=turn:your-domain:443?transport=tcp` and
   `STUN_URL=stun:your-domain:3478`.
5. `docker compose up -d`.

The API issues short-lived (1 hour) per-user TURN credentials via
`GET /api/v1/sessions/:id/turn-credentials` (see
`src/services/turn.service.js`) — nothing here needs a shared static
username/password baked into the client.
