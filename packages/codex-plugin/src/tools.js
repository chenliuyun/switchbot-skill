import { buildCliArgs, runCli } from './executor.js';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const defaultExec = promisify(execFile);

const DESTRUCTIVE_COMMANDS = new Set(['lockOff']);

const AUDIT_LOG_PATH = '~/.switchbot/audit.log';

export function getTier(toolName, command, policy) {
  if (
    toolName === 'devices_list' ||
    toolName === 'devices_status' ||
    toolName === 'devices_describe' ||
    toolName === 'scenes_list'
  ) {
    return 'read';
  }
  if (toolName === 'scenes_run') {
    return policy?.scenesTier === 'destructive' ? 'destructive' : 'mutation';
  }
  if (toolName === 'devices_command') {
    return DESTRUCTIVE_COMMANDS.has(command) ? 'destructive' : 'mutation';
  }
  return 'mutation';
}

export async function callTool(toolName, args = {}, { exec = defaultExec, policy = null } = {}) {
  const tier = getTier(toolName, args.command, policy);
  const auditLog = tier === 'mutation' || tier === 'destructive';

  if (tier === 'destructive' && !args.confirmed) {
    return {
      requiresConfirmation: true,
      safetyTier: 'destructive',
      message:
        `Command '${args.command || toolName}' requires explicit user confirmation. ` +
        'Call again with confirmed: true after the user has approved.',
    };
  }

  const cliArgs = buildCliArgs(toolName, args, { auditLog });
  const result = await runCli(cliArgs, exec);

  const envelope = { result, safetyTier: tier, requiresConfirmation: false };
  if (auditLog) envelope.auditLogPath = AUDIT_LOG_PATH;
  return envelope;
}

export const TOOL_DEFINITIONS = [
  {
    name: 'devices_list',
    description: 'List all SwitchBot devices. Safety tier: read.',
    inputSchema: { type: 'object', properties: {}, required: [] },
  },
  {
    name: 'devices_status',
    description: 'Get the current status of a SwitchBot device. Safety tier: read.',
    inputSchema: {
      type: 'object',
      properties: { deviceId: { type: 'string', description: 'SwitchBot device ID' } },
      required: ['deviceId'],
    },
  },
  {
    name: 'devices_describe',
    description: 'Get metadata about a SwitchBot device (type, capabilities). Safety tier: read.',
    inputSchema: {
      type: 'object',
      properties: { deviceId: { type: 'string', description: 'SwitchBot device ID' } },
      required: ['deviceId'],
    },
  },
  {
    name: 'devices_command',
    description:
      'Send a command to a SwitchBot device. Safety tier: mutation for most commands; ' +
      'destructive for lock commands (lockOff) — requires confirmed: true.',
    inputSchema: {
      type: 'object',
      properties: {
        deviceId: { type: 'string', description: 'SwitchBot device ID' },
        command: { type: 'string', description: 'Command name, e.g. turnOn, turnOff, lockOff' },
        parameter: { type: 'string', description: 'Optional command parameter value' },
        confirmed: {
          type: 'boolean',
          description:
            'Must be true to execute destructive-tier commands (e.g. lockOff). ' +
            'Obtain explicit user consent before setting this.',
        },
      },
      required: ['deviceId', 'command'],
    },
  },
  {
    name: 'scenes_list',
    description: 'List all SwitchBot scenes. Safety tier: read.',
    inputSchema: { type: 'object', properties: {}, required: [] },
  },
  {
    name: 'scenes_run',
    description:
      'Run a SwitchBot scene. Safety tier: mutation by default; ' +
      'destructive when policy.yaml sets scenesTier: destructive (requires confirmed: true).',
    inputSchema: {
      type: 'object',
      properties: {
        sceneId: { type: 'string', description: 'SwitchBot scene ID' },
        confirmed: {
          type: 'boolean',
          description: 'Required when scenesTier is set to destructive in policy.yaml.',
        },
      },
      required: ['sceneId'],
    },
  },
];
