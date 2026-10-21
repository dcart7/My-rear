import fs from 'node:fs/promises';
import { query, pool } from './db.mjs';
const sql = await fs.readFile(new URL('../sql/001_init.sql', import.meta.url), 'utf8');
await query(sql); await pool.end(); console.log('Міграція завершена');
