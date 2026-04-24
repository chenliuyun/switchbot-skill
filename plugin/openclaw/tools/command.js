// plugin/openclaw/tools/command.js
import { runCli } from '../cli.js';

export const commandTools = [
  {
    name: 'devices_command',
    description: 'Send a command to a device (e.g. turnOn, setBrightness). Respects safety tiers.',
    inputSchema: {
      type: 'object',
      properties: {
        deviceId: { type: 'string' },
        command:  { type: 'string', description: 'Command name (turnOn, turnOff, setBrightness, …)' },
        params:   { type: 'object', description: 'Command parameters if any', additionalProperties: true },
      },
      required: ['deviceId', 'command'],
    },
    async handler({ deviceId, command, params }) {
      const args = ['--audit-log', 'devices', 'command', deviceId, command, '--json'];
      if (params) args.push('--params', JSON.stringify(params));
      return runCli(args);
    },
  },
];
