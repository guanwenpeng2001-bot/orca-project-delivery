# Local code video render

Run commands from the package root unless a separate rendering project is specified.

In a separate writable project directory, save this original composition as `index.html`. The three states occupy frames 0–89, 90–209, and 210–299 at 30 fps. Static clips avoid wall-clock animation nondeterminism.

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Code Change</title>
<style>
html, body { margin: 0; width: 1280px; height: 720px; background: #101820; color: #f5f5f5; }
#explanation { position: relative; width: 1280px; height: 720px; }
.clip { position: absolute; inset: 0; padding: 80px; box-sizing: border-box; background: #101820; }
h1 { font: 48px sans-serif; }
pre { font: 36px monospace; white-space: pre-wrap; }
</style>
</head>
<body>
<main id="explanation" data-composition-id="code-change" data-start="0" data-duration="10" data-width="1280" data-height="720" data-fps="30">
<section class="clip" data-start="0" data-duration="3" data-track-index="0"><h1>Failing check</h1><pre>assert.equal(total, 90);
Actual: 81</pre></section>
<section class="clip" data-start="3" data-duration="4" data-track-index="0"><h1>Apply once</h1><pre>if (applied.has(code)) return total;</pre></section>
<section class="clip" data-start="7" data-duration="3" data-track-index="0"><h1>Passing check</h1><pre>assert.equal(total, 90);
Passed</pre></section>
</main>
</body>
</html>
```

Check it before installing anything:

```sh
node skills/code-video-production/scripts/composition-check.mjs --input index.html --fps 30
```

The report has `frames` 300 and clips spanning `[0, 90)`, `[90, 210)`, and `[210, 300)`, with no warnings. `tests/fixtures/capability/subtitle-media-sample.html` is the same timing without styling and checks the same way.

After installing an appropriate FFmpeg build and local Chrome, install the pinned CLI in that separate project and run:

```sh
npm install --save-dev hyperframes@0.8.143
npx --no-install hyperframes --version
ffmpeg -version
ffprobe -version
npx --no-install hyperframes render . --output code-change.mp4 --fps 30 --strict --no-best-effort
ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=width,height,avg_frame_rate,nb_read_frames:format=duration -of json code-change.mp4
ffmpeg -v error -i code-change.mp4 -f null -
ffmpeg -n -ss 1 -i code-change.mp4 -frames:v 1 first.png
ffmpeg -n -ss 5 -i code-change.mp4 -frames:v 1 fix.png
ffmpeg -n -ss 8 -i code-change.mp4 -frames:v 1 last.png
```

Installation may download packages and browser components; perform it only when local dependency installation is allowed. Rendering itself uses the selected local composition and assets. Require renderer/decode exit 0, 1280x720, 30/1 fps, 300 decoded video frames, and duration 10 seconds within one frame. Open the three PNGs and verify the expected code state is legible with no clipping. Check boundary frames when using transitions. No audio is expected in this sample. A missing CLI/browser/codec leaves render acceptance unverified even when the HTML looks correct.
