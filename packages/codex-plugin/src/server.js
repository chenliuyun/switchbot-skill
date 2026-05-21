import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { fileURLToPath } from 'node:url';
import { TOOL_DEFINITIONS, callTool } from './tools.js';
import { loadPolicy, checkPolicy } from './policy.js';

export function createMcpServer() {
  const server = new Server(
    { name: 'switchbot', version: '0.8.0' },
    { capabilities: { tools: {} } },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: TOOL_DEFINITIONS,
  }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args = {} } = request.params;

    const policy = await loadPolicy().catch(() => null);

    const policyResult = checkPolicy(policy, {
      tool: name,
      deviceId: args.deviceId,
      command: args.command,
    });

    if (policyResult.blocked) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              blocked: true,
              reason: policyResult.reason,
              message: policyResult.message,
            }),
          },
        ],
      };
    }

    const result = await callTool(name, args, { policy });
    return {
      content: [{ type: 'text', text: JSON.stringify(result) }],
    };
  });

  return server;
}

const __filename = fileURLToPath(import.meta.url);
if (process.argv[1] === __filename) {
  const server = createMcpServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}
