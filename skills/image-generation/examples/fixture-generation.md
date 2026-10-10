# Image fixture example

From the package root, the following saves synthetic PNG fixture bytes with `networkCalled: false` and needs no provider credential:

```sh
node skills/image-generation/scripts/openai-image-request.mjs --request tests/fixtures/capability/openai-image-request.json --output otter.png --fixture tests/fixtures/capability/openai-image-success.json
```

The failure fixture `openai-image-failure.json` exits 3 with HTTP 429 and writes no file. For a separately authorized generation, replace `--fixture PATH` with `--online` after configuring the gate and key; no transport replacement is needed. A custom `OPENAI_IMAGE_MODEL` is sent as the actual request model.
