// plugin/openclaw/tools/devices.js
import { runCli } from '../cli.js';

export const devicesTools = [
  {
    name: 'devices_list',
    description: 'List all SwitchBot devices in the account.',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async handler() {
      return runCli(['devices', 'list', '--json']);
    },
  },
  {
    name: 'devices_status',
    description: 'Get current status of a specific device.',
    inputSchema: {
      type: 'object',
      properties: { deviceId: { type: 'string', description: 'Device ID' } },
      required: ['deviceId'],
    },
    async handler({ deviceId }) {
      return runCli(['devices', 'status', deviceId, '--json']);
    },
  },
  {
    name: 'devices_describe',
    description: 'Describe supported commands for a device type.',
    inputSchema: {
      type: 'object',
      properties: { deviceId: { type: 'string' } },
      required: ['deviceId'],
    },
    async handler({ deviceId }) {
      return runCli(['devices', 'describe', deviceId, '--json']);
    },
  },
];
