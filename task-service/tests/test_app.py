import pytest
from app.app import app


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as c:
        yield c


def test_health(client):
    res = client.get('/health')
    assert res.status_code == 200
    assert res.get_json() == {'status': 'ok', 'service': 'task-service'}


def test_create_task_empty_title(client):
    res = client.post('/tasks', json={'title': ''})
    assert res.status_code == 400
    assert 'error' in res.get_json()


def test_create_task_no_body(client):
    res = client.post('/tasks', json={})
    assert res.status_code == 400
    assert 'error' in res.get_json()
