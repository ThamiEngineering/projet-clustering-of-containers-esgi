import os
from flask import Flask, jsonify, request
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

# Lecture des secrets Docker
def read_secret(name):
    with open(f'/run/secrets/{name}', 'r') as f:
        return f.read().strip()

POSTGRES_USER = read_secret('postgres_user')
POSTGRES_PASSWORD = read_secret('postgres_password')
POSTGRES_HOST = os.environ.get('POSTGRES_HOST', 'postgres')
POSTGRES_DB = os.environ.get('POSTGRES_DB', 'multiweb_db')


def get_db_connection():
    return psycopg2.connect(
        host=POSTGRES_HOST,
        database=POSTGRES_DB,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        port=5432,
    )


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'service': 'task-service'})


@app.route('/tasks', methods=['GET'])
def get_tasks():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute('SELECT * FROM tasks ORDER BY id')
        tasks = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify([dict(t) for t in tasks])
    except Exception as e:
        print(f'Erreur GET /tasks: {e}', flush=True)
        return jsonify({'error': 'Database query failed'}), 500


@app.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json(silent=True) or {}
    title = (data.get('title') or '').strip()
    if not title:
        return jsonify({'error': 'Le titre est requis'}), 400
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            'INSERT INTO tasks (title, completed) VALUES (%s, %s) RETURNING *',
            (title, False),
        )
        new_task = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        return jsonify(dict(new_task)), 201
    except Exception as e:
        print(f'Erreur POST /tasks: {e}', flush=True)
        return jsonify({'error': 'Database insert failed'}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=4000)
