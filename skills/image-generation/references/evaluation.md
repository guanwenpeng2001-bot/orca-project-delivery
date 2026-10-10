# Image generation evaluation

For package maintainers changing the image connector or header inspection; run commands from the package root.

Run `node --test tests/provider-transport.test.mjs tests/capability-repair.test.mjs`. Injected transport exercises the real executor, including exact auth/body, model override, saved bytes, disabled/missing auth, HTTP errors, malformed results, and body timeouts. No test uses a provider or real secret. `node skills/image-generation/scripts/image-info.mjs --input result.png` reports `{format, width, height, alpha, colorType}` from the header. Truncated PNG data, a JPEG without a start-of-frame marker, a JPEG frame shorter than 8 bytes, a VP8X chunk that is not exactly 10 bytes, a VP8L chunk without its `0x2f` signature, and a WebP whose chunk length runs past the file each exit 1. Signature validation and this header report are not a full image decoder; inspect a real authorized result before acceptance.
