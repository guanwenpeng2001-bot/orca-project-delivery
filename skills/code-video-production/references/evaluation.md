# Code video evaluation

For package maintainers changing this method or its composition checker.

Execute the [sample](../examples/local-render.md) only in a configured local environment; retain renderer and FFprobe results and inspect first/fix/last frames. If HyperFrames or FFmpeg is absent, record the missing command and mark rendering unverified. Run `node --test tests/subtitle-media.test.mjs` from the package root: the sample composition maps to 300 frames, a cross-track overlap passes with a warning, and a frame-aligned decimal such as `4.1` at 30 fps is accepted, a same-track overlap, a non-frame duration, and a relative time expression each exit non-zero, and a clip that overruns the composition exits zero with a warning. This package supplies an executable method, not pre-rendered video evidence.
