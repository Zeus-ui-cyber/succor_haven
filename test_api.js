require('dotenv').config();
const jwt = require('jsonwebtoken');

const token = jwt.sign(
  { sub: 'a7e35692-9136-4934-ab28-ad74e5981ca7', role: 'admin' }, 
  process.env.JWT_ACCESS_SECRET,
  { expiresIn: '15m' }
);

async function run() {
  try {
    const res = await fetch('http://localhost:3000/api/v1/announcements', { 
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}` 
      },
      body: JSON.stringify({
        "title": "test",
        "description": "test comming",
        "category": "event", 
        "priority": "normal",
        "visibility": "everyone",
        "publishAt": "2026-07-21T01:19:00.000Z",
        "expiresAt": "2026-07-21T02:00:00.000Z",
        "isPinned": true,
        "commentsEnabled": true,
        "galleryUrls": []
      })
    });

    if (!res.ok) {
      console.error("API Error:", res.status, await res.text());
    } else {
      console.log("Created!", await res.json());
    }
  } catch (err) {
    console.error("Error:", err.message);
  }
}
run();
