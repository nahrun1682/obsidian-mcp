import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { registerMcpRoute } from '@/server/shared/mcp-routes';

describe('registerMcpRoute', () => {
  it('returns a guidance response for GET /mcp', async () => {
    const app = express();
    registerMcpRoute(app, { connect: async () => {} } as any);

    const response = await request(app).get('/mcp');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      status: 'ok',
      message: 'MCP endpoint is POST /mcp',
      auth: 'Bearer token required',
    });
  });
});
