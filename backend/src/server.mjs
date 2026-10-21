import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import dotenv from 'dotenv';
import { query } from './db.mjs';
import { requireAuth, signUser } from './auth.mjs';
dotenv.config();

const app = express();
const allowed = (process.env.ALLOWED_ORIGINS || '').split(',').map(value => value.trim()).filter(Boolean);
app.disable('x-powered-by'); app.use(helmet()); app.use(cors({ origin: allowed.includes('*') ? true : allowed })); app.use(express.json({ limit: '12kb' }));
app.use(rateLimit({ windowMs: 60_000, limit: 100, standardHeaders: true, legacyHeaders: false }));
const authRateLimit = rateLimit({ windowMs: 15 * 60_000, limit: 20, message: { error: 'Забагато спроб. Спробуйте пізніше.' } });
const registerSchema = z.object({ email: z.string().email().max(160), password: z.string().min(12).max(200), displayName: z.string().trim().min(2).max(80) });
const postSchema = z.object({ category: z.enum(['немає світла', 'немає води', 'проблема зі зв’язком', 'небезпека', 'інше']), area: z.string().trim().min(2).max(80), message: z.string().trim().min(3).max(500) });

app.get('/health', (_req, res) => res.json({ ok: true, service: 'miy-til-api' }));
app.post('/v1/auth/register', authRateLimit, async (req, res, next) => { try { const input = registerSchema.parse(req.body); const email = input.email.toLowerCase(); const exists = await query('SELECT 1 FROM users WHERE email = $1', [email]); if (exists.rowCount) return res.status(409).json({ error: 'Ця електронна адреса вже використовується' }); const hash = await bcrypt.hash(input.password, 12); const result = await query('INSERT INTO users(email, password_hash, display_name) VALUES($1,$2,$3) RETURNING id,email,display_name,role', [email, hash, input.displayName]); const user = result.rows[0]; res.status(201).json({ user, token: signUser(user) }); } catch (error) { next(error); } });
app.post('/v1/auth/login', authRateLimit, async (req, res, next) => { try { const input = z.object({ email: z.string().email(), password: z.string().min(1) }).parse(req.body); const result = await query('SELECT id,email,password_hash,display_name,role FROM users WHERE email = $1', [input.email.toLowerCase()]); const user = result.rows[0]; if (!user || !(await bcrypt.compare(input.password, user.password_hash))) return res.status(401).json({ error: 'Невірна електронна адреса або пароль' }); delete user.password_hash; res.json({ user, token: signUser(user) }); } catch (error) { next(error); } });
app.get('/v1/feed', async (req, res, next) => { try { const limit = Math.min(Number(req.query.limit) || 20, 50); const result = await query('SELECT p.id,p.category,p.area,p.message,p.created_at,u.display_name, count(pr.*)::int AS reactions FROM posts p JOIN users u ON u.id=p.author_id LEFT JOIN post_reactions pr ON pr.post_id=p.id WHERE p.status=\'published\' GROUP BY p.id,u.display_name ORDER BY p.created_at DESC LIMIT $1', [limit]); res.json({ posts: result.rows }); } catch (error) { next(error); } });
app.post('/v1/posts', requireAuth, async (req, res, next) => { try { const input = postSchema.parse(req.body); const result = await query('INSERT INTO posts(author_id,category,area,message) VALUES($1,$2,$3,$4) RETURNING id,category,area,message,status,created_at', [req.user.id, input.category, input.area, input.message]); res.status(201).json({ post: { ...result.rows[0], author: req.user.display_name } }); } catch (error) { next(error); } });
app.post('/v1/posts/:id/reactions', requireAuth, async (req, res, next) => { try { const reaction = z.object({ reaction: z.enum(['helpful', 'not_helpful']) }).parse(req.body); await query('INSERT INTO post_reactions(post_id,user_id,reaction) VALUES($1,$2,$3) ON CONFLICT(post_id,user_id) DO UPDATE SET reaction=excluded.reaction', [req.params.id, req.user.id, reaction.reaction]); res.status(204).end(); } catch (error) { next(error); } });
app.post('/v1/posts/:id/reports', requireAuth, async (req, res, next) => { try { const input = z.object({ reason: z.string().trim().min(3).max(120) }).parse(req.body); await query('INSERT INTO reports(post_id,reporter_id,reason) VALUES($1,$2,$3) ON CONFLICT(post_id,reporter_id) DO NOTHING', [req.params.id, req.user.id, input.reason]); res.status(202).json({ status: 'pending_review' }); } catch (error) { next(error); } });
app.delete('/v1/posts/:id', requireAuth, async (req, res, next) => { try { const result = await query('UPDATE posts SET status=\'removed\' WHERE id=$1 AND author_id=$2 RETURNING id', [req.params.id, req.user.id]); if (!result.rowCount) return res.status(404).json({ error: 'Публікацію не знайдено' }); res.status(204).end(); } catch (error) { next(error); } });
app.use((error, _req, res, _next) => { if (error?.name === 'ZodError') return res.status(400).json({ error: 'Некоректні дані', details: error.issues.map(issue => issue.path.join('.')) }); console.error(error); res.status(500).json({ error: 'Внутрішня помилка сервера' }); });
app.listen(Number(process.env.PORT || 8787), '0.0.0.0', () => console.log(`Miy Tyl API listening on ${process.env.PORT || 8787}`));
