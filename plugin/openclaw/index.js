// plugin/openclaw/index.js
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { runCli } from './cli.js';

export function createServer() {
  const server = new McpServer({ name: 'switchbot', version: '0.5.0' });

  server.tool('devices_list',
    'List all SwitchBot devices in the account.',
    async () => ({
      content: [{ type: 'text', text: JSON.stringify(await runCli(['devices', 'list', '--json'])) }]
    })
  );

  server.tool('devices_status',
    'Get current status of a specific device.',
    { deviceId: z.string().describe('Device ID') },
    async ({ deviceId }) => ({
      content: [{ type: 'text', text: JSON.stringify(await runCli(['devices', 'status', deviceId, '--json'])) }]
    })
  );

  server.tool('devices_describe',
    'Describe supported commands for a device type.',
    { deviceId: z.string() },
    async ({ deviceId }) => ({
      content: [{ type: 'text', text: JSON.stringify(await runCli(['devices', 'describe', deviceId, '--json'])) }]
    })
  );

  server.tool('devices_command',
    'Send a command to a device (e.g. turnOn, setBrightness). Respects safety tiers.',
    {
      deviceId: z.string(),
      command:  z.string().describe('Command name (turnOn, turnOff, setBrightness, …)'),
      params:   z.record(z.unknown()).optional().describe('Command parameters'),
    },
    async ({ deviceId, command, params }) => {
      const args = ['--audit-log', 'devices', 'command', deviceId, command, '--json'];
      if (params) args.push('--params', JSON.stringify(params));
      return { content: [{ type: 'text', text: JSON.stringify(await runCli(args)) }] };
    }
  );

  server.tool('scenes_list',
    'List all saved SwitchBot scenes.',
    async () => ({
      content: [{ type: 'text', text: JSON.stringify(await runCli(['scenes', 'list', '--json'])) }]
    })
  );

  server.tool('scenes_run',
    'Execute a scene by ID.',
    { sceneId: z.string() },
    async ({ sceneId }) => ({
      content: [{ type: 'text', text: JSON.stringify(await runCli(['--audit-log', 'scenes', 'run', sceneId, '--json'])) }]
    })
  );

  return server;
}

export async function startStdioServer() {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  return server;
}
