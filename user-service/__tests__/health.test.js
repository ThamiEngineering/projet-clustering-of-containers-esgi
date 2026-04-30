const request = require('supertest');
const app = require('../index');

describe('user-service', () => {
  it('GET /health → 200', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok', service: 'user-service' });
  });

  it('POST /users with empty name → 400', async () => {
    const res = await request(app).post('/users').send({ name: '' });
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  it('POST /users without name → 400', async () => {
    const res = await request(app).post('/users').send({});
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });
});
