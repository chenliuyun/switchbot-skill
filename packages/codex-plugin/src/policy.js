import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { resolve } from 'node:path';
import { load as parseYaml } from 'js-yaml';

export const DEFAULT_POLICY_PATH = '~/.config/openclaw/switchbot/policy.yaml';

function expandHome(p) {
  if (p === '~' || p.startsWith('~/') || p.startsWith('~\\')) {
    return resolve(homedir(), p.slice(2));
  }
  return p;
}

export async function loadPolicy(policyPath = DEFAULT_POLICY_PATH) {
  const fullPath = expandHome(policyPath);
  try {
    const content = await readFile(fullPath, 'utf8');
    return parseYaml(content) ?? null;
  } catch (err) {
    if (err.code === 'ENOENT') return null;
    throw err;
  }
}

function isInQuietHours({ start, end }, now) {
  const [sh, sm] = start.split(':').map(Number);
  const [eh, em] = end.split(':').map(Number);
  const current = now.getHours() * 60 + now.getMinutes();
  const startMin = sh * 60 + sm;
  const endMin = eh * 60 + em;
  if (startMin <= endMin) {
    return current >= startMin && current < endMin;
  }
  return current >= startMin || current < endMin;
}

export function checkPolicy(policy, { tool, deviceId, command }, now = new Date()) {
  if (!policy) return { blocked: false };

  if (policy.quietHours?.start && policy.quietHours?.end) {
    if (isInQuietHours(policy.quietHours, now)) {
      return {
        blocked: true,
        reason: 'quietHours',
        message: `Blocked during quiet hours (${policy.quietHours.start}–${policy.quietHours.end})`,
      };
    }
  }

  if (deviceId && policy.allowedDevices?.length > 0) {
    if (!policy.allowedDevices.includes(deviceId)) {
      return {
        blocked: true,
        reason: 'allowedDevices',
        message: `Device '${deviceId}' is not in the allowed devices list`,
      };
    }
  }

  if (command && policy.blockedCommands?.length > 0) {
    if (policy.blockedCommands.includes(command)) {
      return {
        blocked: true,
        reason: 'blockedCommands',
        message: `Command '${command}' is blocked by policy`,
      };
    }
  }

  return { blocked: false };
}
