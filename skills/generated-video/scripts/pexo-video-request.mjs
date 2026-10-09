import { CapabilityError, binaryResponse, cli, execute, jsonResponse, readJson, requireValue } from '../../../scripts/capability-runtime.mjs';

async function streamAcknowledgement(response) {
  if (!/^text\/event-stream(?:;|$)/i.test(response.headers.get('content-type') || '')) throw new CapabilityError(3, 'invalid-sse');
  const reader = response.body?.getReader();
  if (!reader) throw new CapabilityError(3, 'invalid-sse');
  const decoder = new TextDecoder();
  let pending = '';
  try {
    while (true) {
      const { value, done } = await reader.read();
      pending += decoder.decode(value, { stream: !done });
      const lines = pending.split('\n'); pending = lines.pop();
      if (lines.some((line) => line.replace(/\r$/, '') === ': stream opened') || (done && pending === ': stream opened')) return;
      if (done || pending.length > 65536) throw new CapabilityError(3, 'missing-sse-ack');
    }
  } catch (error) {
    if (error instanceof CapabilityError) throw error;
    throw new CapabilityError(3, 'response-read-failure');
  } finally { await reader.cancel().catch(() => {}); }
}
function unwrap(data) { return data && Object.hasOwn(data, 'code') && Object.hasOwn(data, 'data') ? data.data : data; }
function projectAction(project) {
  if (!['IDLE', 'RUNNING', 'FAILED', 'INTERRUPTED', 'CONFIRM_REQUIRED', 'COMPLETED'].includes(project?.executionStatus) || !['IDLE', 'PROCESSING'].includes(project?.serviceStatus)) throw new CapabilityError(3, 'invalid-project-state');
  if (project.executionStatus === 'FAILED') return 'FAILED';
  if (project.executionStatus === 'CONFIRM_REQUIRED') return 'CONFIRM';
  if (project.executionStatus === 'INTERRUPTED') return 'RESPOND';
  if (project.executionStatus === 'COMPLETED' && project.serviceStatus !== 'PROCESSING') return 'DELIVER';
  if (project.executionStatus === 'RUNNING' && project.serviceStatus === 'IDLE') return 'RECONNECT';
  return 'WAIT';
}
function simplify(message) {
  if (message.role?.toLowerCase() === 'user') return { role: 'USER', text: message.content?.native_inputs?.text };
  const event = message.content?.event;
  const data = message.content?.data ?? {};
  if (event === 'final_video') return { event, assetId: data.final_video_id };
  if (event === 'message') return { event, text: data.message };
  if (event === 'preview_video') return { event, assetIds: data.preview_video_ids };
  if (event === 'billing_confirmation') return { event, confirmation: data };
  if (event === 'error') return { event, errorCode: data.error_code, errorMessage: data.error_message ?? data.error, terminal: data.terminal ?? true };
  return { event };
}
export function run(args, options = {}) {
  return execute(args, options, 'PEXO_API_KEY', async ({ key, env, call, signal }) => {
    if (env.PEXO_BASE_URL && env.PEXO_BASE_URL.replace(/\/$/, '') !== 'https://pexo.ai') throw new CapabilityError(2, 'invalid-base-url');
    const submitted = readJson(args.request);
    const projectId = requireValue(submitted.project_id, 'project-id');
    const projectPath = `/api/biz/projects/${encodeURIComponent(projectId)}`;
    const headers = { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
    const get = async (endpoint) => unwrap(await jsonResponse(await call(`https://pexo.ai${endpoint}`, { headers })));
    const action = args.action ?? 'submit';
    if (!['submit', 'status', 'download'].includes(action)) throw new CapabilityError(1, 'invalid-action');
    if (action === 'download') {
      requireValue(args.output, 'output');
      const assetId = requireValue(submitted.asset_id, 'asset-id');
      const assetPath = `${projectPath}/assets/${encodeURIComponent(assetId)}`;
      const asset = await get(assetPath);
      if (!asset || typeof asset !== 'object') throw new CapabilityError(3, 'malformed-result');
      if (asset.assetStatus === 'UPLOADING') return { exitCode: 5, nextAction: 'WAIT', projectId, assetId };
      const download = await get(`${assetPath}/download-url?remove_watermark=${submitted.with_watermark === true ? 'false' : 'true'}`);
      if (typeof download?.url !== 'string' || !download.url) throw new CapabilityError(3, 'missing-download-url');
      let url;
      try { url = new URL(download.url); } catch { throw new CapabilityError(3, 'invalid-download-url'); }
      if (url.protocol !== 'https:' || url.username || url.password) throw new CapabilityError(3, 'invalid-download-url');
      const response = await call(url.href);
      const bytes = await binaryResponse(response, /^(video\/|application\/octet-stream(?:;|$))/i);
      if (bytes.toString('ascii', 4, 8) !== 'ftyp' && bytes.subarray(0, 4).toString('hex') !== '1a45dfa3') throw new CapabilityError(3, 'invalid-video');
      return { bytes, projectId, assetId, withWatermark: download.withWatermark ?? null };
    }
    const project = await get(projectPath);
    let nextAction = projectAction(project);
    if (action === 'submit') {
      if (project.serviceStatus === 'PROCESSING' || ['RUNNING', 'CONFIRM_REQUIRED'].includes(project.executionStatus)) return { exitCode: 5, nextAction, projectId };
      const body = {
        project_id: projectId,
        timestamp: String((options.now ?? Date.now)()),
        user_visible: true,
        native_inputs: { text: requireValue(submitted.native_inputs?.text, 'text') },
        billing_confirmation_policy: { mode: 'always' },
      };
      if (submitted.choices?.preview_id) body.choices = { preview_id: requireValue(submitted.choices.preview_id, 'preview-id') };
      const response = await call('https://pexo.ai/api/chat', { method: 'POST', headers: { ...headers, Accept: 'text/event-stream' }, body: JSON.stringify(body) }, body);
      await streamAcknowledgement(response);
      return { acknowledgement: { projectId, status: 'submitted', submissionMode: 'async', submittedAt: body.timestamp, pollAfterSeconds: 60 } };
    }
    if (nextAction === 'WAIT') return { exitCode: 5, projectId, nextAction, pollAfterSeconds: 60 };
    const recent = [];
    for (let page = 1; ; page++) {
      if (signal.aborted) throw new CapabilityError(4, 'timeout');
      const history = await get(`${projectPath}/history?page=${page}&page_size=50&sort_order=DESC`);
      const messages = Array.isArray(history) ? history : history?.messages;
      if (!Array.isArray(messages)) throw new CapabilityError(3, 'invalid-history');
      const userIndex = messages.findIndex((message) => message.role?.toLowerCase() === 'user');
      recent.push(...(userIndex < 0 ? messages : messages.slice(0, userIndex + 1)));
      if (userIndex >= 0 || history.hasMore !== true) break;
      if (messages.length === 0) throw new CapabilityError(3, 'invalid-history');
    }
    const recentMessages = recent.reverse().map(simplify);
    const finalVideo = recentMessages.findLast((message) => message.event === 'final_video' && typeof message.assetId === 'string' && message.assetId);
    if (nextAction === 'RESPOND' && finalVideo) nextAction = 'DELIVER';
    if (nextAction === 'DELIVER' && !finalVideo) throw new CapabilityError(3, 'missing-final-video');
    return { exitCode: nextAction === 'FAILED' ? 3 : nextAction === 'DELIVER' ? 0 : 5, projectId, nextAction, recentMessages, ...(finalVideo && nextAction === 'DELIVER' ? { assetId: finalVideo.assetId } : {}) };
  });
}
cli(import.meta.url, run);
