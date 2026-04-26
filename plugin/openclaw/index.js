// plugin/openclaw/index.js
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { buildCliArgs, runCli } from './cli.js';

async function callTool(tool, params) {
  const args = buildCliArgs({ tool, params });
  const result = await runCli(args);
  const response = { content: [{ type: 'text', text: JSON.stringify(result) }] };
  if (result && result.error) response.isError = true;
  return response;
}

export function createServer() {
  const server = new McpServer({ name: 'switchbot', version: '0.7.0' });

  server.tool('devices_list',
    'List all SwitchBot devices in the account.',
    async () => callTool('devices_list', {})
  );

  server.tool('devices_status',
    'Get current status of a specific device.',
    { deviceId: z.string().describe('Device ID') },
    async ({ deviceId }) => callTool('devices_status', { deviceId })
  );

  server.tool('devices_describe',
    'Describe supported commands for a device type.',
    { deviceId: z.string() },
    async ({ deviceId }) => callTool('devices_describe', { deviceId })
  );

  server.tool('devices_command',
    'Send a command to a device (e.g. turnOn, setBrightness). Respects safety tiers.',
    {
      deviceId: z.string(),
      command:  z.string().describe('Command name (turnOn, turnOff, setBrightness, …)'),
      params:   z.record(z.unknown()).optional().describe('Command parameters'),
    },
    async ({ deviceId, command, params }) =>
      callTool('devices_command', { deviceId, command, params })
  );

  server.tool('scenes_list',
    'List all saved SwitchBot scenes.',
    async () => callTool('scenes_list', {})
  );

  server.tool('scenes_run',
    'Execute a scene by ID.',
    { sceneId: z.string() },
    async ({ sceneId }) => callTool('scenes_run', { sceneId })
  );

  return server;
}

export async function startStdioServer() {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  return server;
}
