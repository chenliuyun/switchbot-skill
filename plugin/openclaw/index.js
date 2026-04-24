// plugin/openclaw/index.js
import { devicesTools } from './tools/devices.js';
import { commandTools } from './tools/command.js';
import { scenesTools } from './tools/scenes.js';

const allTools = [...devicesTools, ...commandTools, ...scenesTools];

export function createServer(opts = {}) {
  const tools = allTools;

  const server = {
    listTools() { return tools; },
    close() { return Promise.resolve(); },
    port: null,
  };

  return Promise.resolve(server);
}
