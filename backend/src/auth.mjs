import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import { query } from './db.mjs';
dotenv.config();

const secret = process.env.JWT_SECRET;
if (!secret || secret.length < 32) throw new Error('JWT_SECRET must be at least 32 characters');
export function signUser(user) { return jwt.sign({ sub: user.id, role: user.role }, secret, { expiresIn: '7d', issuer: 'miy-til-api', audience: 'miy-til-app' }); }
export async function requireAuth(req, res, next) { try { const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, ''); const payload = jwt.verify(token, secret, { issuer: 'miy-til-api', audience: 'miy-til-app' }); const result = await query('SELECT id, email, display_name, role FROM users WHERE id = $1', [payload.sub]); if (!result.rows[0]) return res.status(401).json({ error: 'Користувача не знайдено' }); req.user = result.rows[0]; next(); } catch { res.status(401).json({ error: 'Потрібна авторизація' }); } }
