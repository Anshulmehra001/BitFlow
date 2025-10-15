const request = require('supertest');
const app = require('../src/index');

describe('BitFlow API', () => {
  let authToken;
  let testUser = {
    email: 'test@example.com',
    password: 'testpassword123',
    walletAddress: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12'
  };

  beforeAll(async () => {
    // Register and login test user
    await request(app)
      .post('/api/auth/register')
      .send(testUser);

    const loginResponse = await request(app)
      .post('/api/auth/login')
      .send({
        email: testUser.email,
        password: testUser.password
      });

    authToken = loginResponse.body.token;
  });

  describe('Authentication', () => {
    test('should register a new user', async () => {
      const newUser = {
        email: 'newuser@example.com',
        password: 'password123',
        walletAddress: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef13'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(newUser);

      expect(response.status).toBe(201);
      expect(response.body.token).toBeDefined();
      expect(response.body.user.email).toBe(newUser.email);
    });

    test('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: testUser.email,
          password: testUser.password
        });

      expect(response.status).toBe(200);
      expect(response.body.token).toBeDefined();
    });

    test('should reject invalid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: testUser.email,
          password: 'wrongpassword'
        });

      expect(response.status).toBe(401);
    });
  });

  describe('Streams', () => {
    test('should create a new stream', async () => {
      const streamData = {
        recipient: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef14',
        amount: '1000000',
        rate: '100',
        duration: 10000
      };

      const response = await request(app)
        .post('/api/streams')
        .set('Authorization', `Bearer ${authToken}`)
        .send(streamData);

      expect(response.status).toBe(201);
      expect(response.body.streamId).toBeDefined();
      expect(response.body.stream.recipient).toBe(streamData.recipient);
    });

    test('should get user streams', async () => {
      const response = await request(app)
        .get('/api/streams')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body.streams)).toBe(true);
    });

    test('should reject stream creation without auth', async () => {
      const streamData = {
        recipient: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef14',
        amount: '1000000',
        rate: '100',
        duration: 10000
      };

      const response = await request(app)
        .post('/api/streams')
        .send(streamData);

      expect(response.status).toBe(401);
    });

    test('should validate stream parameters', async () => {
      const invalidStreamData = {
        recipient: 'invalid-address',
        amount: '0',
        rate: '100',
        duration: 10000
      };

      const response = await request(app)
        .post('/api/streams')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidStreamData);

      expect(response.status).toBe(400);
    });
  });

  describe('Webhooks', () => {
    test('should register a webhook endpoint', async () => {
      const webhookData = {
        url: 'https://example.com/webhook',
        events: ['stream.created', 'payment.received'],
        description: 'Test webhook'
      };

      const response = await request(app)
        .post('/api/webhooks/endpoints')
        .set('Authorization', `Bearer ${authToken}`)
        .send(webhookData);

      expect(response.status).toBe(201);
      expect(response.body.endpoint.id).toBeDefined();
      expect(response.body.endpoint.secret).toBeDefined();
    });

    test('should get user webhook endpoints', async () => {
      const response = await request(app)
        .get('/api/webhooks/endpoints')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body.endpoints)).toBe(true);
    });

    test('should validate webhook URL', async () => {
      const invalidWebhookData = {
        url: 'not-a-valid-url',
        events: ['stream.created']
      };

      const response = await request(app)
        .post('/api/webhooks/endpoints')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidWebhookData);

      expect(response.status).toBe(400);
    });
  });

  describe('Health Check', () => {
    test('should return health status', async () => {
      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('OK');
      expect(response.body.timestamp).toBeDefined();
    });
  });

  describe('Rate Limiting', () => {
    test('should apply rate limiting', async () => {
      // This test would need to be adjusted based on actual rate limits
      // For now, just verify the middleware is in place
      const response = await request(app)
        .get('/api/streams')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.headers['x-ratelimit-limit']).toBeDefined();
    });
  });
});