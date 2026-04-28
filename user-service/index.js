const fs = require('fs');
const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const port = process.env.PORT || 3000;

// Lecture des secrets Docker
const postgresUser = fs.readFileSync('/run/secrets/postgres_user', 'utf8').trim();
const postgresPassword = fs.readFileSync('/run/secrets/postgres_password', 'utf8').trim();

const pool = new Pool({
  user: postgresUser,
  host: process.env.POSTGRES_HOST || 'postgres',
  database: process.env.POSTGRES_DB || 'multiweb_db',
  password: postgresPassword,
  port: 5432,
});

// Healthcheck endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'user-service' });
});

// GET /users - liste tous les utilisateurs
app.get('/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    console.error('Erreur GET /users:', err.message);
    res.status(500).json({ error: 'Database query failed' });
  }
});

// POST /users - ajoute un nouvel utilisateur
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

app.listen(port, () => {
  console.log(`User service écoute sur le port ${port}`);
});
