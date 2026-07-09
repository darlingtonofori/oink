// Minimal reference backend for the Flutter SMS Gateway app.
// Matches your existing stack: Node.js + Express, no DB required to start
// (swap the in-memory arrays for MySQL/SQLite whenever you're ready).
//
// Run:  npm init -y && npm install express && node server.js

const express = require('express');
const crypto = require('crypto');
const app = express();
app.use(express.json());

const API_KEY = process.env.SMS_GATEWAY_KEY || 'change-me';
const PORT = process.env.PORT || 3000;

// Outbound queue: messages waiting to be sent by a phone.
// { id, device, to, body, status: 'pending'|'sent'|'failed', createdAt }
let outbox = [];

// Inbound log: messages received by a phone and forwarded here.
let inbox = [];

function checkAuth(req, res, next) {
  const key = req.header('X-API-Key');
  if (key !== API_KEY) return res.status(401).json({ error: 'bad api key' });
  next();
}

// Health check the app's "Test connection" button hits.
app.get('/api/ping', checkAuth, (req, res) => res.json({ ok: true }));

// Phone polls this to ask "anything to send?"
app.get('/api/pending', checkAuth, (req, res) => {
  const device = req.query.device;
  const jobs = outbox.filter(m => m.status === 'pending' &&
    (!device || m.device === device));
  res.json({ messages: jobs.map(({ id, to, body }) => ({ id, to, body })) });
});

// Phone reports back whether a send succeeded.
app.post('/api/status', checkAuth, (req, res) => {
  const { id, success, error } = req.body;
  const job = outbox.find(m => m.id === id);
  if (job) {
    job.status = success ? 'sent' : 'failed';
    job.error = error || null;
    job.updatedAt = new Date().toISOString();
  }
  res.json({ ok: true });
});

// Phone forwards an incoming SMS here.
app.post('/api/inbound', checkAuth, (req, res) => {
  const { device, from, body, receivedAt } = req.body;
  inbox.push({ device, from, body, receivedAt });
  console.log(`[inbound] ${device || 'unknown'} <- ${from}: ${body}`);
  res.json({ ok: true });
});

// --- Your own apps call this to queue an outbound SMS ---
app.post('/api/send', checkAuth, (req, res) => {
  const { device, to, body } = req.body;
  if (!to || !body) return res.status(400).json({ error: 'to and body required' });
  const job = {
    id: crypto.randomUUID(),
    device: device || null,
    to,
    body,
    status: 'pending',
    createdAt: new Date().toISOString(),
  };
  outbox.push(job);
  res.json({ ok: true, id: job.id });
});

// Handy for checking what's arrived / gone out.
app.get('/api/inbox', checkAuth, (req, res) => res.json({ inbox }));
app.get('/api/outbox', checkAuth, (req, res) => res.json({ outbox }));

app.listen(PORT, () => console.log(`SMS gateway backend on :${PORT}`));
