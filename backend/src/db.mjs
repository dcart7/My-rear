import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config();

export const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 10, ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false });
export async function query(text, params) { return pool.query(text, params); }
