const MAX_REQUEST = 2_000_000;
const MAX_RESPONSE = 4_000_000;
export const commandName = 'abstractions.translate.v1';

async function invokeLocal(local, request) {
  if (process.env.ABSTRACTIONS_NODE !== 'node1' || !local.isAvailable()) throw new Error('local worker unavailable');
  let receive, response;
  const controller = new AbortController();
  const io = { signal: controller.signal, frames: {
    onMessage: callback => { receive = callback; return () => {}; },
    send: async message => { response = Buffer.from(message); },
  }};
  const completed = local.handle('{}', io);
  await receive(Buffer.from(JSON.stringify(request)));
  await completed;
  return response;
}

async function readBody(req) {
  const chunks = []; let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_REQUEST) throw new Error('request too large');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

export function createGatewayHandler(api, local) {
  return async (req, res) => {
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Cache-Control', 'no-store');
        if (req.method !== 'POST') { res.statusCode = 405; res.end('{"error":"method"}'); return true; }
        let channel, unsubscribe;
        try {
          const body = await readBody(req);
          const request = JSON.parse(body.toString('utf8'));
          if (request?.request?.operation === 'availability') {
            const connected = (await api.runtime.nodes.list({ connected: true })).nodes;
            const configured = api.pluginConfig?.nodes ?? {};
            const available = { node1: process.env.ABSTRACTIONS_NODE === 'node1' && local.isAvailable() };
            available.node_ids = {node1:'gateway-local'};
            for (const name of ['node2','node3','node4','node5','node6']) {
              const target = connected.find(item => item.nodeId === configured[name]);
              available[name] = Boolean(target?.connected && target.platform === 'linux' &&
                target.commands?.includes(commandName) && target.invocableCommands?.includes(commandName));
              if (available[name]) available.node_ids[name] = target.nodeId;
            }
            res.statusCode = 200; res.end(JSON.stringify({result: available})); return true;
          }
          const name = request?.node;
          const nodeId = name === 'node1' ? 'gateway-local' : api.pluginConfig?.nodes?.[name];
          if (!['node1','node2','node3','node4','node5','node6'].includes(name) ||
              typeof nodeId !== 'string' || !nodeId || request.device_id !== nodeId || !request.request ||
              (request.request.operation === 'execute' && (request.request.job?.selected_node !== name ||
                request.request.job?.selected_device_id !== nodeId)) ||
              !['execute','status','release'].includes(request.request.operation)) throw new Error('invalid request');
          if (name !== 'node1' && request.request.operation === 'execute') {
            const nodes = (await api.runtime.nodes.list({ connected: true })).nodes;
            const target = nodes.find(item => item.nodeId === nodeId);
            if (!target?.connected || target.platform !== 'linux' ||
                !target.commands?.includes(commandName) || !target.invocableCommands?.includes(commandName))
              throw new Error('node unavailable or incompatible');
          }
          let messages;
          if (name === 'node1') {
            messages = [await invokeLocal(local, request.request)];
          } else {
            channel = await api.runtime.nodes.openDuplex({nodeId, command: commandName,
              params: {}, timeoutMs: name === 'node4' ? 120000 : 30000, maxMessageBytes: MAX_RESPONSE});
            void channel.closed.catch(() => {});
            messages = [];
            unsubscribe = channel.onMessage(message => { messages.push(Buffer.from(message)); });
            await channel.send(Buffer.from(JSON.stringify(request.request)));
            await channel.closed;
          }
          if (messages.length !== 1 || messages[0].length > MAX_RESPONSE) throw new Error('invalid response');
          const response = JSON.parse(messages[0].toString('utf8'));
          if (response.result && response.result.selected_node !== name) throw new Error('node mismatch');
          res.statusCode = 200; res.end(JSON.stringify({...response, device_id:nodeId}));
        } catch {
          res.statusCode = 502; res.end('{"error":"node transport failed"}');
        } finally { unsubscribe?.(); channel?.close(); }
        return true;
  };
}
