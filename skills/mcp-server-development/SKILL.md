---
name: mcp-server-development
description: Design an MCP server tool surface, classify protocol errors separately from tool errors, and verify the messages against the pinned specification. Use when adding or changing tools on a Model Context Protocol server. Not for HTTP API design.
---

# MCP Server Development

## Core principle

A tool is a contract a model calls with arguments it invented. The server must reject what it cannot name, and it must report that rejection in the channel the specification assigns, because a client treats the two channels differently.

## Decision criteria

Pin the specification revision before writing a message. This method uses MCP revision `2025-11-25` over JSON-RPC `2.0`. A later revision replaces these shapes only after its page is re-read; do not carry them forward from memory.

Name tools in the server's vocabulary, 1 to 128 characters, case-sensitive, using ASCII letters, digits, `_`, `-`, and `.`. The specification marks those constraints as SHOULD. State them as server requirements anyway so two tools cannot differ only by a space. One verb, one object: `record_reading`, not `readings`.

Give every tool an `inputSchema` that is a JSON Schema object. For a tool with no arguments use `{ "type": "object", "additionalProperties": false }`. When the result has a stable shape, add `outputSchema` and return conforming `structuredContent`, and also return the same JSON as a text content block so older clients still see it.

Split failures:

| Situation | Channel | Shape |
| --- | --- | --- |
| Unknown tool, malformed request, server failure | JSON-RPC error | `error.code`, `error.message`; no `result` |
| Bad argument value, downstream failure, business rule | Tool result | `result.isError: true` with text the model can correct |

The published examples use `-32602` for an unknown tool. That code is JSON-RPC's invalid-params code; method-not-found is `-32601` and is for an unknown method such as `tools/missing`, not an unknown tool name. Codes `-32700` to `-32603` are the defined protocol errors, and `-32000` to `-32099` is reserved for implementation-defined server errors. A response carries `result` or `error`, never both.

Annotations such as `readOnlyHint`, `destructiveHint`, and `idempotentHint` are claims. The specification tells clients to treat annotations as untrusted unless the server is trusted, so an annotation never replaces server-side validation, access control, or rate limiting.

### Transport

Prefer stdio when the server runs beside the client for one user: framing is newline-delimited JSON-RPC and stdout carries only protocol messages. Use streamable HTTP when the server is remote or shared, and require the origin check and authentication the transport section states. Do not expose a local development server on a public interface.

This method designs and checks the message surface. It does not ship a server scaffold: one hypothetical server is not a reason to generate a framework.

## Workflow

1. Pin `2025-11-25` and list the tools, each with its schema and effect.
2. Write one valid `tools/list`, one valid `tools/call`, one protocol error, and one tool error, using the shapes below.
3. Confirm no example uses `isError` for an unknown tool, and none uses a JSON-RPC error for a bad argument value.
4. State the transport and what must never be written to stdout under stdio.
5. Run the local checks in this Skill's `examples/` directory. They validate fixtures; they do not start a server.
6. Record any check that could not be run as skipped, with the reason.

## Worked example

A local server exposes `record_reading`, which stores one temperature reading. Arguments are `sensor` (string) and `celsius` (number, from -89.2 to 56.7). The result schema requires `id` and `stored: true`.

Valid call:

```json
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"record_reading","arguments":{"sensor":"dock-1","celsius":22.5}}}
```

```json
{"jsonrpc":"2.0","id":2,"result":{"content":[{"type":"text","text":"{\"id\":\"rd_101\",\"stored\":true}"}],"structuredContent":{"id":"rd_101","stored":true},"isError":false}}
```

Unknown tool, a protocol error, with no `result`:

```json
{"jsonrpc":"2.0","id":3,"error":{"code":-32602,"message":"Unknown tool: invalid_tool_name"}}
```

`celsius: 400` is a value the tool understood and refuses, so it stays a tool result:

```json
{"jsonrpc":"2.0","id":4,"result":{"content":[{"type":"text","text":"celsius must be between -89.2 and 56.7."}],"isError":true}}
```

A call with no `name` fails the request schema and is a protocol error, not `isError`. The `tools/list` entry sets `inputSchema.additionalProperties` to `false` and repeats the bounds, so an extra field or an out-of-range number fails the same way in every client.

Local verification, from the package root:

```sh
node --test skills/mcp-server-development/examples/protocol-shapes.test.mjs
```

The test loads the fixtures in that directory and checks the field rules above. It does not bind a port. The stdout traces beside the fixtures show the same messages one per line, which is the stdio framing check.

## Failure signals

- An unknown tool comes back as `result.isError: true`.
- A bad argument value comes back as a JSON-RPC error, so the model cannot correct it.
- A response contains both `result` and `error`.
- Two tools share a name ignoring case, or a name contains a space.
- A tool with no arguments omits `inputSchema` or uses `null`.
- The server prints logs to stdout while serving stdio.
- A scaffold generator is added for a single server.

## Evaluation scenario

Given `record_reading` and the three calls above, the result should keep the unknown tool on `error.code` `-32602` with no `result`, keep `celsius: 400` on `result.isError`, and reject a response that carries both members. It fails the method if those two failures share one channel, or if the only evidence offered is a prose summary with no fixture.

## Output

- Pinned specification revision
- Tool list with input and output schemas
- One valid call, one protocol error, one tool error
- Transport choice and stdout constraint
- Local test command and its observed result

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. It does not design a general HTTP API (`api-design` owns that), does not add a server framework, and does not call a remote server. Product direction, scope, and irreversible choices stay with the user.
