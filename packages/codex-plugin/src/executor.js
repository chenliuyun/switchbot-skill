import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

export const defaultExec = promisify(execFile);

const READ_TOOLS = new Set([
  'devices_list',
  'devices_status',
  'devices_describe',
  'scenes_list',
]);

export function buildCliArgs(tool, params = {}, { auditLog = false } = {}) {
  const flags = READ_TOOLS.has(tool) ? ['--no-cache', '--json'] : ['--json'];
  const prefix = auditLog ? ['--audit-log'] : [];
  switch (tool) {
    case 'devices_list':
      return ['devices', 'list', ...flags];
    case 'devices_status':
      return ['devices', 'status', params.deviceId, ...flags];
    case 'devices_describe':
      return ['devices', 'describe', params.deviceId, ...flags];
    case 'devices_command': {
      const args = [...prefix, 'devices', 'command', params.deviceId, params.command, ...flags];
      if (params.parameter != null) args.push('--params', String(params.parameter));
      return args;
    }
    case 'scenes_list':
      return ['scenes', 'list', ...flags];
    case 'scenes_run':
      return [...prefix, 'scenes', 'run', params.sceneId, ...flags];
    default:
      throw new Error(`unknown tool: ${tool}`);
  }
}

const AUTH_ERROR_PATTERNS = [
  /token\s+not\s+(set|configured|found)/i,
  /credentials?\s+not\s+(set|configured|found)/i,
  /no\s+credentials/i,
  /\b401\b/,
  /unauthorized/i,
  /missing\s+(token|credentials)/i,
  /switchbot\s+config\s+set-token/i,
];

export function looksLikeAuthError(text) {
  if (!text) return false;
  return AUTH_ERROR_PATTERNS.some((re) => re.test(text));
}

function setupRequired(reason, message) {
  return {
    error: {
      kind: 'setup-required',
      reason,
      message,
      nextStep: 'Run `switchbot auth login` in a terminal to configure credentials.',
    },
  };
}

export async function runCli(args, exec = defaultExec) {
  try {
    const { stdout } = await exec('switchbot', args, { timeout: 15000 });
    return JSON.parse(stdout);
  } catch (err) {
    if (err?.code === 'ENOENT') {
      return setupRequired(
        'cli-missing',
        'SwitchBot CLI (`switchbot`) is not installed on PATH. ' +
        'Install with: npm install -g @switchbot/openapi-cli@latest',
      );
    }
    const raw = (err?.stdout ?? err?.stderr ?? err?.message) ?? String(err);
    let parsed = null;
    try { parsed = JSON.parse(raw); } catch { /* non-JSON */ }

    const kind = parsed?.error?.kind;
    if (kind === 'auth' || kind === 'credentials' || kind === 'unauthorized') {
      return setupRequired('auth-missing', 'CLI has no credentials. Run: switchbot auth login');
    }
    if (!parsed && looksLikeAuthError(raw)) {
      return setupRequired('auth-missing', 'CLI rejected with auth error. Run: switchbot auth login');
    }
    if (parsed) return parsed;
    return { error: { kind: 'internal', message: raw } };
  }
}
