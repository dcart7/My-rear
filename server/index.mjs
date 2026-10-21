import http from 'node:http';

const port = Number(process.env.API_PORT || 8787);
const allowedOrigin = process.env.ALLOWED_ORIGIN || 'http://localhost:5173';
const alertsBase = (process.env.ALERTS_IN_UA_BASE_URL || 'https://api.alerts.in.ua').replace(/\/$/, '');
const alertsToken = process.env.ALERTS_IN_UA_TOKEN;
const requests = new Map();
const reports = [];

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'", 'Access-Control-Allow-Origin': allowedOrigin, 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' });
  res.end(JSON.stringify(body));
}

function limited(ip) {
  const now = Date.now(); const recent = (requests.get(ip) || []).filter(time => now - time < 60_000); recent.push(now); requests.set(ip, recent); return recent.length > 60;
}

function validReport(value) {
  return value && typeof value === 'object' && ['category', 'area', 'message'].every(key => typeof value[key] === 'string') && value.area.length <= 80 && value.message.length <= 500 && !/[\n\r]/.test(value.area);
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return send(res, 204, {});
  const ip = req.socket.remoteAddress || 'unknown';
  if (limited(ip)) return send(res, 429, { error: 'Забагато запитів. Спробуйте пізніше.' });
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

  if (url.pathname === '/api/health' && req.method === 'GET') return send(res, 200, { ok: true, service: 'miy-til-api' });

  if (url.pathname === '/api/alerts' && req.method === 'GET') {
    const regionID = Number(url.searchParams.get('region_id'));
    if (!alertsToken) return send(res, 503, { error: 'Сервер ще не налаштований: відсутній ALERTS_IN_UA_TOKEN.' });
    if (!Number.isInteger(regionID) || regionID < 1 || regionID > 999) return send(res, 400, { error: 'Некоректний region_id.' });
    try {
      const response = await fetch(`${alertsBase}/v1/iot/active_air_raid_alerts/${regionID}.json`, { headers: { Authorization: `Bearer ${alertsToken}` }, signal: AbortSignal.timeout(10_000) });
      if (!response.ok) return send(res, 502, { error: 'Джерело тривог тимчасово недоступне.' });
      const raw = await response.json();
      const active = raw === 'A' || raw?.status === 'A';
      return send(res, 200, { regionID, status: active ? 'active' : 'safe', source: 'alerts.in.ua', updatedAt: new Date().toISOString() });
    } catch { return send(res, 502, { error: 'Не вдалося отримати дані від джерела тривог.' }); }
  }

  if (url.pathname === '/api/reports' && req.method === 'GET') return send(res, 200, { reports: reports.slice(0, 100) });
  if (url.pathname === '/api/reports' && req.method === 'POST') {
    let body = ''; for await (const chunk of req) { body += chunk; if (body.length > 16_000) return send(res, 413, { error: 'Повідомлення завелике.' }); }
    try { const payload = JSON.parse(body); if (!validReport(payload)) return send(res, 400, { error: 'Некоректний формат повідомлення.' }); const report = { id: crypto.randomUUID(), category: payload.category.slice(0, 60), area: payload.area.trim(), message: payload.message.trim(), status: 'pending_review', createdAt: new Date().toISOString() }; reports.unshift(report); return send(res, 202, { report }); } catch { return send(res, 400, { error: 'Некоректний JSON.' }); }
  }
  return send(res, 404, { error: 'Маршрут не знайдено.' });
});

server.listen(port, '0.0.0.0', () => console.log(`Мій тил API слухає порт ${port}`));
