// plugin/openclaw/cli.js
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const exec = promisify(execFile);

// Read-only tools that should always bypass the CLI cache. The upstream
// @switchbot/openapi-cli 3.3.0 cache can serve stale values for batch /
// long-lived read paths — forcing --no-cache here absorbs the bug so
// agents and users don't have to remember it per-call. Mutation tools
// must NOT use --no-cache: they're write paths that don't hit the cache
// and passing the flag would just be noise.
const READ_TOOLS = new Set([
  'devices_list',
  'devices_status',
  'devices_describe',
  'scenes_list',
]);

export function buildCliArgs({ tool, params = {} }) {
  const flags = READ_TOOLS.has(tool) ? ['--no-cache', '--json'] : ['--json'];
  switch (tool) {
    case 'devices_list':
      return ['devices', 'list', ...flags];
    case 'devices_status':
      return ['devices', 'status', params.deviceId, ...flags];
    case 'devices_describe':
      return ['devices', 'describe', params.deviceId, ...flags];
    case 'devices_command': {
      const args = ['--audit-log', 'devices', 'command', params.deviceId, params.command, ...flags];
      if (params.params) {
        args.push('--params', JSON.stringify(params.params));
      }
      return args;
    }
    case 'scenes_list':
      return ['scenes', 'list', ...flags];
    case 'scenes_run':
      return ['--audit-log', 'scenes', 'run', params.sceneId, ...flags];
    default:
      throw new Error(`unknown tool: ${tool}`);
  }
}

export async function runCli(args) {
  try {
    const { stdout } = await exec('switchbot', args, { timeout: 15000 });
    return JSON.parse(stdout);
  } catch (err) {
    const msg = err.stdout ?? err.message ?? String(err);
    try { return JSON.parse(msg); } catch { return { error: { kind: 'internal', message: msg } }; }
  }
}
