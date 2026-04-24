// plugin/openclaw/tools/scenes.js
import { runCli } from '../cli.js';

export const scenesTools = [
  {
    name: 'scenes_list',
    description: 'List all saved SwitchBot scenes.',
    inputSchema: { type: 'object', properties: {}, required: [] },
    async handler() { return runCli(['scenes', 'list', '--json']); },
  },
  {
    name: 'scenes_run',
    description: 'Execute a scene by ID.',
    inputSchema: {
      type: 'object',
      properties: { sceneId: { type: 'string' } },
      required: ['sceneId'],
    },
    async handler({ sceneId }) {
      return runCli(['--audit-log', 'scenes', 'run', sceneId, '--json']);
    },
  },
];
