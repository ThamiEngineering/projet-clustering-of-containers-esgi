const fs = require('fs');
const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const port = process.env.PORT || 3000;

function readSecret(name) {
  try {
    return fs.readFileSync(`/run/secrets/${name}`, 'utf8').trim();
  } catch {
    return process.env[name.toUpperCase()] || '';
  }
}

const pool = new Pool({
  user: readSecret('postgres_user'),
  host: process.env.POSTGRES_HOST || 'postgres',
  database: process.env.POSTGRES_DB || 'multiweb_db',
  password: readSecret('postgres_password'),
  port: 5432,
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'user-service' });
});

app.get('/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    console.error('Erreur GET /users:', err.message);
    res.status(500).json({ error: 'Database query failed' });
  }
});

app.post('/users', async (req, res) => {
  const { name } = req.body;
  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Le nom est requis' });
  }
  try {
    const result = await pool.query(
      'INSERT INTO users (name) VALUES ($1) RETURNING *',
      [name.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Erreur POST /users:', err.message);
    res.status(500).json({ error: 'Database insert failed' });
  }
});

if (require.main === module) {
  app.listen(port, () => {
    console.log(`User service écoute sur le port ${port}`);
  });
}

module.exports = app;
