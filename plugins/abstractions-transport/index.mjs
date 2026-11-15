import { definePluginEntry } from 'openclaw/plugin-sdk/plugin-entry';
import { createNodeCommand } from './node-command.mjs';
import { commandName, createGatewayHandler } from './gateway-route.mjs';

const local = createNodeCommand({ node: process.env.ABSTRACTIONS_NODE,
  python: process.env.ABSTRACTIONS_PYTHON, worker: process.env.ABSTRACTIONS_WORKER });

export default definePluginEntry({
  id: 'abstractions-transport', name: 'Abstractions Transport',
  description: 'Send complete translation jobs over paired-node duplex transport',
  nodeHostCommands: [local],
  register(api) {
    api.registerNodeInvokePolicy({ commands: [commandName], dangerous: true,
      handle: async ctx => await ctx.invokeNode() });
    api.registerHttpRoute({ path: '/plugins/abstractions-transport', auth: 'gateway',
      match: 'exact', handler: createGatewayHandler(api, local) });
  },
});
