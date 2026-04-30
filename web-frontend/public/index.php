<?php
// =========================================================
// Configuration des URL des services backend (DNS overlay Swarm)
// =========================================================
$USER_SERVICE_URL = getenv('USER_SERVICE_URL') ?: 'http://user-service:3000';
$TASK_SERVICE_URL = getenv('TASK_SERVICE_URL') ?: 'http://task-service:4000';

// =========================================================
// Helpers HTTP (GET / POST JSON)
// =========================================================
function http_get($url) {
    $opts = ['http' => ['timeout' => 5, 'ignore_errors' => true]];
    $ctx  = stream_context_create($opts);
    $res  = @file_get_contents($url, false, $ctx);
    if ($res === false) return null;
    return json_decode($res, true);
}

function http_post_json($url, $data) {
    $opts = ['http' => [
        'method'        => 'POST',
        'header'        => "Content-Type: application/json\r\n",
        'content'       => json_encode($data),
        'timeout'       => 5,
        'ignore_errors' => true,
    ]];
    $ctx = stream_context_create($opts);
    $res = @file_get_contents($url, false, $ctx);
    return $res !== false;
}

// =========================================================
// Traitement des formulaires (POST)
// =========================================================
$flash = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!empty($_POST['new_user'])) {
        $ok = http_post_json("$USER_SERVICE_URL/users", ['name' => $_POST['new_user']]);
        $flash = $ok ? ['ok', "Utilisateur ajouté avec succès."]
                     : ['err', "Échec de l'ajout de l'utilisateur."];
    } elseif (!empty($_POST['new_task'])) {
        $ok = http_post_json("$TASK_SERVICE_URL/tasks", ['title' => $_POST['new_task']]);
        $flash = $ok ? ['ok', "Tâche ajoutée avec succès."]
                     : ['err', "Échec de l'ajout de la tâche."];
    }
    // Redirection POST/GET pour éviter le re-submit au refresh
    header("Location: /?flash=" . urlencode(json_encode($flash)));
    exit;
}

if (!empty($_GET['flash'])) {
    $flash = json_decode($_GET['flash'], true);
}

// =========================================================
// Récupération des données
// =========================================================
$users = http_get("$USER_SERVICE_URL/users") ?? [];
$tasks = http_get("$TASK_SERVICE_URL/tasks") ?? [];

// Hostname du conteneur (utile pour démontrer le load balancing)
$pod = gethostname();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Projet ESGI – Cluster Docker Swarm</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        :root {
            --bg: #0f172a;
            --card: #1e293b;
            --accent: #38bdf8;
            --accent2: #818cf8;
            --text: #e2e8f0;
            --muted: #94a3b8;
            --ok: #22c55e;
            --err: #ef4444;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: var(--bg);
            color: var(--text);
            min-height: 100vh;
            padding: 40px 20px;
        }
        .container { max-width: 1100px; margin: 0 auto; }
        header {
            text-align: center;
            margin-bottom: 40px;
        }
        h1 {
            font-size: 2.5em;
            margin: 0 0 10px;
            color: var(--accent);
        }
        .subtitle { color: var(--muted); font-size: 1.05em; }
        .pod-badge {
            display: inline-block;
            margin-top: 10px;
            padding: 6px 14px;
            background: rgba(56, 189, 248, 0.15);
            border: 1px solid var(--accent);
            border-radius: 20px;
            font-size: 0.9em;
            color: var(--accent);
            font-family: monospace;
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 25px;
        }
        @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
        .card {
            background: var(--card);
            border-radius: 14px;
            padding: 28px;
            border: 1px solid rgba(255, 255, 255, 0.08);
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.25);
        }
        .card h2 {
            margin: 0 0 18px;
            font-size: 1.3em;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        ul { list-style: none; padding: 0; margin: 0 0 18px; }
        li {
            padding: 10px 14px;
            background: rgba(255, 255, 255, 0.04);
            border-radius: 8px;
            margin-bottom: 6px;
            border-left: 3px solid var(--accent);
        }
        li.completed { opacity: 0.55; text-decoration: line-through; border-left-color: var(--ok); }
        form { display: flex; gap: 10px; margin-top: 12px; }
        input[type="text"] {
            flex: 1;
            padding: 10px 14px;
            background: rgba(0, 0, 0, 0.25);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 8px;
            color: var(--text);
            font-size: 1em;
            outline: none;
            transition: border-color 0.2s;
        }
        input[type="text"]:focus { border-color: var(--accent); }
        button {
            padding: 10px 20px;
            background: var(--accent);
            color: #0f172a;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.1s;
        }
        button:hover { transform: translateY(-1px); }
        .flash {
            padding: 12px 16px;
            border-radius: 8px;
            margin-bottom: 25px;
            text-align: center;
            font-weight: 500;
        }
        .flash.ok  { background: rgba(34, 197, 94, 0.15); color: var(--ok); border: 1px solid var(--ok); }
        .flash.err { background: rgba(239, 68, 68, 0.15); color: var(--err); border: 1px solid var(--err); }
        .empty { color: var(--muted); font-style: italic; text-align: center; padding: 12px; }
        footer {
            text-align: center;
            margin-top: 40px;
            color: var(--muted);
            font-size: 0.85em;
        }
        footer code {
            background: rgba(0, 0, 0, 0.3);
            padding: 2px 6px;
            border-radius: 4px;
            font-family: monospace;
        }
    </style>
</head>
<body>
    <div class="container">

        <header>
            <h1>Cluster Docker Swarm</h1>
            <p class="subtitle">ToDo App orchestrée sur 3 nœuds (1 master + 2 workers)</p>
            <div class="pod-badge">Servi par : <?= htmlspecialchars($pod) ?></div>
        </header>

        <?php if ($flash): ?>
            <div class="flash <?= $flash[0] ?>">
                <?= htmlspecialchars($flash[1]) ?>
            </div>
        <?php endif; ?>

        <div class="grid">

            <div class="card">
                <h2>Utilisateurs</h2>
                <ul>
                    <?php if (empty($users)): ?>
                        <li class="empty">Aucun utilisateur</li>
                    <?php else: foreach ($users as $user): ?>
                        <li>
                            #<?= htmlspecialchars($user['id']) ?> &middot; <?= htmlspecialchars($user['name']) ?>
                        </li>
                    <?php endforeach; endif; ?>
                </ul>
                <form method="POST">
                    <input type="text" name="new_user" placeholder="Nom du nouvel utilisateur" required>
                    <button type="submit">Ajouter</button>
                </form>
            </div>

            <div class="card">
                <h2>Tâches</h2>
                <ul>
                    <?php if (empty($tasks)): ?>
                        <li class="empty">Aucune tâche</li>
                    <?php else: foreach ($tasks as $task): ?>
                        <li class="<?= !empty($task['completed']) ? 'completed' : '' ?>">
                            #<?= htmlspecialchars($task['id']) ?> &middot; <?= htmlspecialchars($task['title']) ?>
                        </li>
                    <?php endforeach; endif; ?>
                </ul>
                <form method="POST">
                    <input type="text" name="new_task" placeholder="Titre de la nouvelle tâche" required>
                    <button type="submit">Ajouter</button>
                </form>
            </div>

        </div>

        <footer>
            <p>
                Stack <code>multiweb-stack</code> &middot; Frontend ×3, User-service ×2, Task-service ×2, PostgreSQL ×1<br>
                Rafraîchis la page : tu devrais voir le nom du conteneur changer (load balancing Swarm).
            </p>
        </footer>

    </div>
</body>
</html>
