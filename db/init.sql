-- =============================================================
-- Initialisation de la base multiweb_db
-- Exécutée automatiquement par l'image postgres au premier démarrage
-- =============================================================

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Quelques données initiales pour tester
INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie')
ON CONFLICT DO NOTHING;

INSERT INTO tasks (title, completed) VALUES
    ('Configurer le cluster Swarm', TRUE),
    ('Déployer la stack multiweb', TRUE),
    ('Configurer Nginx Proxy Manager', FALSE),
    ('Démontrer la haute disponibilité', FALSE)
ON CONFLICT DO NOTHING;
