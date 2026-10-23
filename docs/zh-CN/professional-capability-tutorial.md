# 专业能力教程

[English](../professional-capability-tutorial.md) | **简体中文**

版本 2 项目注册、混合绑定、解析后的依赖选择及原位置同级资源，见[已安装外部 Skill 演练](external-skills.md)。包内 Skill 不需要单独安装。

本教程面向完整的 **4.0.0 包：69 个 Skill、18 个角色、5 个工作流**。它在临时项目中使用合成值演练本地工具、离线提供方夹具及限定范围的依赖注入。没有发起实际提供方或付费调用；离线模拟不验证生成质量。

从包根目录在 PowerShell 7 会话中依次运行代码块，使用 Node.js 22.15+（随包 Skill 文档规定的基线）和 Python 3.10+ 的示例需要相应运行时。先安装完整且匹配的 4.0.0 版本。版本不匹配就缺少这些命令所用的脚本。

## 1. 确认你安装的是什么

在包目录中：

```powershell
Get-Content -Raw .\VERSION
Get-Content -Raw .\PACKAGE-MANIFEST.json
```

读四个字段：

| 字段 | 它告诉你什么 |
| --- | --- |
| `VERSION` | 包的修订。4.0.0 是当前版本。 |
| `deliverables.professionalSkills` | 包声称的 Skill 数。4.0.0 版本声称 69。 |
| `deliverables.roles` | 包声称的角色数。4.0.0 版本声称 18。 |
| `workflows/` | 工作流定义数，4.0.0 版本为 5。 |

然后对照目录确认，而不是对照本教程：

```powershell
$skills = (Get-Content -Raw .\routing\skill-catalog.json | ConvertFrom-Json).skills.Count
$roles = (Get-Content -Raw .\roles\catalog.json | ConvertFrom-Json).roles.Count
"catalog skills: $skills"
"catalog roles: $roles"
```

既要求达到版本目标，也要求内部一致；旧的 16/12 目录即使与自己的清单一致，也不能运行这些示例。

```powershell
$manifest = Get-Content -Raw ./PACKAGE-MANIFEST.json | ConvertFrom-Json
$version = (Get-Content -Raw ./VERSION).Trim()
$workflows = (Get-ChildItem ./workflows -Filter *.md).Count
"catalog workflows: $workflows"
if ($version -ne '4.0.0' -or $manifest.version -ne $version -or
    $skills -ne 69 -or $roles -ne 18 -or $workflows -ne 5 -or
    $manifest.deliverables.professionalSkills -ne $skills -or
    $manifest.deliverables.roles -ne $roles -or
    $manifest.deliverables.workflows -ne $workflows) {
  throw 'Install the complete matching 4.0.0 package before continuing.'
}
"GUARD_PASSED skills=$skills roles=$roles version=$version"
```

## 2. 离线校验包

```powershell
pwsh -NoProfile -File .\scripts\verify-package.ps1
```

验收标准是退出码 0，且最后一行含 `FAIL=0`。`PASS` 计数不是常数：它描述你正在运行的修订，所以引用你观察到的那一行，而不是一个记得的数字。

这是对包结构及行为的**离线验证**：解析、编码、路由、计数和行为测试。本地 Python Playwright 与 Chromium 存在时，可选测试会启动本地浏览器；否则按名记录跳过。文档重开需要 `-DocumentPython` 指向带固定库的解释器。套件不调用提供方，也不证明生成质量。

## 3. 查看能力

阅读[专业能力](professional-capabilities.md)。对每个新 Skill，记下它带的是四个标签中的哪一个：

- **方法** — 软件、除图标查询外的本地资产、图像规划、代码视频、转码、文档。
- **已实现的本地工具** — 下一节演练的依赖辅助脚本，以及包声明之后某个 Skill 点名的 CLI。
- **离线验证** — 你刚刚运行的套件。
- **真实在线，未验证** — 图像生成、生成视频、语音、转录，以及 `icon-assets` 内部的 Iconify 查询。

安装本包并不暗示任何标签升级。

## 4. 离线运行依赖辅助脚本

辅助脚本回答一个问题：给定一个项目根、一个角色，以及任务选中的 Skill ID，哪些声明的 CLI 和环境变量名存在，哪些文件值会到达子进程。它们不替你选择 Skill，不读取协调者的 `.env`，也不接触网络。

它们在本修订中的参数：

| 脚本 | 必需 | 可选 |
| --- | --- | --- |
| `scripts/check-requirements.ps1` | `-ProjectRoot <string>`、`-Role <id>` | `-Skills <string[]>`、`-ConfigPath <string>` |
| `scripts/invoke-with-requirements.ps1` | `-ProjectRoot <string>`、`-Role <id>`、`-Executable <string>` | `-Skills <string[]>`、`-ConfigPath <string>`、`-Arguments <string[]>` |

`-ProjectRoot` 是执行主机上的项目目录，显式传入。没有默认值。范围由调用者选择：精确传入必需的 Skill ID 加上本任务激活的条件 ID，没有传入的 Skill 不会注入任何东西。

在 PowerShell 7 会话内运行下面的内容，这样 `@(...)` 才会绑定为数组。值是假的。这里没有凭据，也没有东西被发送到任何地方。

```powershell
$package = (Resolve-Path '.').Path
$project = Join-Path ([IO.Path]::GetTempPath()) ('orca-capability-demo-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $project | Out-Null
@'
EXAMPLE_EXPORT_MODE=fixture
'@ | Set-Content -LiteralPath "$project/.env" -Encoding utf8
```

用每个修订都带有的角色、它的一个真实 Skill、且不带配置文件来检查：

```powershell
& "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role software-implementer -Skills @('integration-verification')
$checkExit = $LASTEXITCODE
```

预期：退出码 0，JSON 中 `ok: true`。原有的十六个不声明 CLI、env 或 API 依赖，所以检查在一个空项目上通过。这个结果说明辅助脚本能运行；它不说明某个新 Skill 的依赖已满足，因为没有选中任何新 Skill。

结束后删除临时项目：

```powershell
Remove-Item -Recurse -Force $project
```

## 5. 运行本地能力示例

这些命令在包根目录运行，只写新建临时目录，保留自 2.3.0 提供的稳定脚本和旗标，不联系提供方。

```powershell
$work = Join-Path ([IO.Path]::GetTempPath()) ('orca-local-capability-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
node ./skills/image-compression/scripts/png-compressor.mjs --sample "$work/sample.png"
node ./skills/image-compression/scripts/png-compressor.mjs --input "$work/sample.png" --output "$work/compressed.png"
$pngExit = $LASTEXITCODE
node ./skills/web-assets/scripts/web-asset-manifest.mjs --name Harbor --color '#123456' --output "$work/manifest.json"
$manifestExit = $LASTEXITCODE
node ./skills/document-production/scripts/markdown-document.mjs --input ./tests/fixtures/capability/document-input.json --output "$work/notes.md"
$markdownExit = $LASTEXITCODE
```

预期退出码全部为 `0`。压缩结果打印 `status: "compressed"` 及字节数。无损候选结果没有变小则打印 `status: "no-gain"`，且不创建输出文件。manifest 记录 Harbor、`#123456` 和五种图标尺寸。Markdown 包含夹具中的标题和项目符号。保留 `$work` 到后续全部示例结束再删除。

Office/PDF 生成命令是：

```powershell
python -I ./skills/document-production/scripts/office-document.py --input ./tests/fixtures/capability/document-input.json --format docx --output "$work/notes.docx"
```

按需要把 `docx` 和 `.docx` 换成 `pptx`、`xlsx` 或 `pdf`。成功时 JSON 含 `reopened: true`。缺少库时打印 `missing-dependency` 并以 `2` 退出；文档或输入失败以 `1` 退出。仅在你选择的环境中安装 `skills/document-production/scripts/requirements.txt` 固定的精确版本。非 ASCII 的 PDF 文本还需要 `--font`，指向覆盖这些字形且许可允许的 TrueType 字体。docx、pptx、xlsx 和 pdf 的程序化生成与重新打开已在隔离环境中验证。目标应用程序中的布局、字体、视觉外观，以及任何真实提供方调用，均未验证。

### 资产验收

这些是任务实际产出的验收条件，不表示每项检查都已通过。每个适用行都记录命令、退出码、产物路径和观察结果；没有运行的检查要明确标出。

| Skill | 检查 | 验收条件 |
| --- | --- | --- |
| `icon-assets` | 打开选定 SVG；检查来源和图标集许可记录。 | 图标与 viewBox 正确，目标尺寸下无裁切，记录来源和许可。联网查询需要单独的执行批准。 |
| `svg-logo-design` | 解析 SVG，并以目标小尺寸和大尺寸打开。 | SVG 合法、图形可辨、无裁切或意外外部引用；视觉审查与解析分开。 |
| `web-assets` | 重新打开导出文件、读取尺寸，并解析 manifest 中的图标路径。 | 尺寸和格式符合要求，必要时保留透明度，manifest 引用的文件全部存在。 |
| `image-compression` | 校验输入/输出 PNG 结构，对比解码后的像素、alpha 和字节数。 | chunk/CRC 合法且无损像素相同；记录实际节省或明确无收益。无效输入必须失败且不产生新输出。 |

相同脚本还支持 `heading`、`paragraph`、有序 `list` 和 `table`。Markdown、DOCX、XLSX 产出真实表格，PPTX/PDF 按名拒绝表格而非丢弃。单元格均为字面文本，`=SUM(A1:A2)` 不会被执行。将下面的源数据写到 `$work/blocks.json`：

```powershell
@'
{"title":"Berth notes","blocks":[
  {"type":"heading","text":"Berth plan"},
  {"type":"paragraph","text":"One fact per paragraph."},
  {"type":"list","ordered":true,"items":["Sound the depth","Record the draft"]},
  {"type":"table","columns":["Berth","Draft m"],"rows":[["North","12.4"]]}
]}
'@ | Set-Content -LiteralPath "$work/blocks.json" -Encoding utf8
node ./skills/document-production/scripts/markdown-document.mjs --input "$work/blocks.json" --output "$work/blocks.md"
```

输出 Markdown 包含二级标题、段落、编号列表和含 `North`、`12.4` 的表格。相同输入配合 `--format docx` 或 `xlsx` 会报告 `reopened: true`；`pptx` 或 `pdf` 以 `1` 退出并指出 table。单元格换行由 DOCX/XLSX 保留，Markdown 压成空格，PPTX 拒绝。重开不验证表格溢出、字体替换或视觉布局。

固定版本库可用时，预期退出码依次为 `0, 0, 1, 1`：

```powershell
python -I ./skills/document-production/scripts/office-document.py --input "$work/blocks.json" --format docx --output "$work/blocks.docx"
python -I ./skills/document-production/scripts/office-document.py --input "$work/blocks.json" --format xlsx --output "$work/blocks.xlsx"
python -I ./skills/document-production/scripts/office-document.py --input "$work/blocks.json" --format pptx --output "$work/blocks.pptx"
python -I ./skills/document-production/scripts/office-document.py --input "$work/blocks.json" --format pdf --output "$work/blocks.pdf"
```

## 6. 运行 2.4.0 本地工具

这些命令于 2.4.0 引入，在 4.0.0 中仍然可用。文件处理命令离线运行，只写 `$work`，需要 Node.js 22.15+。可选浏览器测试还需要 Python Playwright 和现有 Chromium，没有命令联系提供方。

黑对白对比度为 21:1，满足 4.5:1 文本与 3:1 边界阈值。灰色 `#777777` 对白不足 4.5:1，第二条命令以 `2` 退出：

```powershell
node ./skills/frontend-visual-design/scripts/contrast-ratio.mjs --foreground "#000000" --background "#FFFFFF"
node ./skills/frontend-visual-design/scripts/contrast-ratio.mjs --foreground "#777777" --background "#FFFFFF" --threshold 4.5
```

第一条打印 `ratioRounded: 21`、`meets.text: true`；非 `#RGB`/`#RRGGBB` 颜色以 `1` 退出并在 stderr 说明原因。

字幕夹具从 SRT 转 WebVTT 再转回，cue 数保持相同。时间戳末尾带无效文本会以 `1` 退出且不改已有输出：

```powershell
node ./skills/subtitle-production/scripts/subtitle-convert.mjs --input ./tests/fixtures/capability/subtitle-media-sample.srt --output "$work/sample.vtt" --to vtt
node ./skills/subtitle-production/scripts/subtitle-convert.mjs --input "$work/sample.vtt" --output "$work/sample-back.srt" --to srt
```

两次均输出含 `cues`、`warnings` 的 JSON。只处理文本，不支持样式、定位或烧录；小时超过 99 的 WebVTT 不能转成 SRT，转换会以 `1` 退出。

合成检查只读 HTML，输出帧映射，不渲染，无需 HyperFrames 或浏览器：

```powershell
node ./skills/code-video-production/scripts/composition-check.mjs --input ./tests/fixtures/capability/subtitle-media-sample.html --fps 30
```

输出 `frames: 300`；同轨 clip 重叠以 `1` 退出。帧映射不是渲染视频，本教程不声称 HyperFrames 渲染通过。

探测比较只读两份已保存的 ffprobe JSON，不运行 ffprobe。夹具以 640x360 匹配，时长差超容差以 `1` 退出：

```powershell
node ./skills/media-transcoding/scripts/probe-compare.mjs --source ./tests/fixtures/capability/subtitle-media-source-probe.json --output ./tests/fixtures/capability/subtitle-media-output-probe.json --width 640 --height 360
```

匹配时报告 `matched: true`；比较不是转码，所装 FFmpeg 与编码器的许可仍须另查。

`png-resize.mjs` 只缩小 8-bit 非隔行 RGB/RGBA PNG，拒绝非缩小请求。`image-info.mjs` 只读 PNG/JPEG/WebP 头中的格式、宽高、alpha 和色彩类型，不解码像素。包不附二进制夹具，可用已有 sample 命令生成母版：

```powershell
node ./skills/image-compression/scripts/png-compressor.mjs --sample "$work/master.png"
node ./skills/image-compression/scripts/png-resize.mjs --input "$work/master.png" --output "$work/icon-32.png" --width 32 --height 32
node ./skills/image-generation/scripts/image-info.mjs --input "$work/icon-32.png"
```

缩图报告 `status: "resized"` 和尺寸，头检查报告 `format: "png"`。缩到母版本身大小以 `1` 退出并提示 `not smaller`，截断头也失败；头有效的文件仍可能损坏。

浏览器示例包含保存潮汐记录与拒绝空白时间两条旅程，测试还检测刻意植入的缺陷。它使用 Python Playwright 及 Windows `LOCALAPPDATA/ms-playwright` 中已有的 Chromium。缺少依赖只跳过对应测试并注明原因，调用 runner 则报告错误而非通过：

```powershell
node --test ./tests/design-browser.test.mjs
```

内容审查在 Windows、Python 3.14.6、Chromium revision 1234 上真实运行过可选浏览器部分，不代表跨平台或其他应用的可访问性。手动查看页面时，在另一终端运行 `node ./skills/browser-e2e/scripts/serve-fixture.mjs`，打开打印的本地回环 URL，完成后关闭服务。提供页面并不等于运行旅程。

工程方法也附带离线夹具检查：

```powershell
node --test ./skills/mcp-server-development/examples/protocol-shapes.test.mjs ./skills/technical-diagrams/examples/diagram-semantics.test.mjs ./skills/localization/examples/message-consistency.test.mjs
```

它们检查 MCP 请求/错误形状、SVG 源码语义、语言键与占位符，不启动 MCP 服务器、不渲染图形、不调用翻译服务。Skill 编写评分、领域模型、迁移顺序、设计 token 的完整实例在对应 Skill 文件中，仍需审查任务的实际产物。

PNG 缩图校验 CRC，并按声明尺寸限制解压，源像素总数上限为 4096 × 4096。两个轴都必须缩小，拒绝调色板、灰度、16-bit 和隔行输入。RGB `tRNS` 先展开 alpha 再盒式平均；`gAMA`、`sRGB`、`iCCP`、`pHYs`、`bKGD`、`zTXt`、`iTXt` 等不支持的块在替换输出前按名拒绝。这是重采样，不是无损压缩。

字幕拒绝重叠、倒序时长、cue 设置、voice span、STYLE/REGION 和非 UTF-8；丢弃的标识符与 NOTE 块写入 warnings，空源报告零 cue 及警告。100000 小时上限是工具策略，不是 WebVTT 规范上限。

合成检查接受有界 HTML 属性语法而非任意 HyperFrames：单根、数值时间、整数轨道、整帧时长、整数或有理数 fps。轨内空隙、跨轨重叠和 clip 超出结尾发警告，合成结尾未覆盖则失败。探测比较只核对首个视频流及音轨存在性，不核对每条流或解码质量；默认时长容差为输出一帧，帧率容差为 0.001。

## 7. 运行离线提供方夹具

夹具模式使用 `--request`、`--fixture` 和内置合成密钥。它从不读取真实提供方密钥，并报告 `networkCalled: false`。不要添加 `--online`；它与 `--fixture` 同时使用会被拒绝。这些示例不测量生成质量。

```powershell
node ./skills/image-generation/scripts/openai-image-request.mjs --request ./tests/fixtures/capability/openai-image-request.json --fixture ./tests/fixtures/capability/openai-image-success.json --output "$work/image.png"
$imageSuccess = $LASTEXITCODE
node ./skills/image-generation/scripts/openai-image-request.mjs --request ./tests/fixtures/capability/openai-image-request.json --fixture ./tests/fixtures/capability/openai-image-failure.json --output "$work/failed-image.png"
$imageFailure = $LASTEXITCODE
node ./skills/generated-video/scripts/pexo-video-request.mjs --request ./tests/fixtures/capability/pexo-video-request.json --fixture ./tests/fixtures/capability/pexo-video-submitted.json
$videoAck = $LASTEXITCODE
node ./skills/generated-video/scripts/pexo-video-request.mjs --request ./tests/fixtures/capability/pexo-video-request.json --fixture ./tests/fixtures/capability/pexo-video-timeout.json
$videoTimeout = $LASTEXITCODE
node ./skills/speech-production/scripts/elevenlabs-speech-request.mjs --request ./tests/fixtures/capability/elevenlabs-speech-request.json --fixture ./tests/fixtures/capability/elevenlabs-speech-success.json --output "$work/speech.mp3"
$speechSuccess = $LASTEXITCODE
node ./skills/audio-transcription/scripts/elevenlabs-transcription-request.mjs --request ./tests/fixtures/capability/elevenlabs-transcription-request.json --fixture ./tests/fixtures/capability/elevenlabs-transcription-failure.json --audio "$work/speech.mp3" --output "$work/transcript.json"
$transcriptionFailure = $LASTEXITCODE
$previousOnlineGate = $env:CAPABILITY_ONLINE_PROVIDERS_ENABLED
try {
  $env:CAPABILITY_ONLINE_PROVIDERS_ENABLED = 'false'
  node ./skills/image-generation/scripts/openai-image-request.mjs --online --request ./tests/fixtures/capability/openai-image-request.json --output "$work/online.png"
  $disabledOnline = $LASTEXITCODE
} finally {
  $env:CAPABILITY_ONLINE_PROVIDERS_ENABLED = $previousOnlineGate
}
```

预期退出码依次为 `0`、`3`、`0`、`4`、`0`、`3`、`2`。图像和语音成功会保存文件。图像与转录夹具模拟 HTTP 失败。Pexo 成功夹具只是 SSE 提交确认；超时以 `4` 退出。最后一条临时关闭在线门，以 `2` 退出并返回 `online-disabled`，随后恢复此前开关而不打印它。

## 8. 真实执行必须显式启用

提供方脚本默认离线。`--request <JSON 路径>`、`--output <路径>` 和 `--fixture <JSON 路径>` 用于本地请求/响应处理，不联系提供方。夹具和注入的传输不能验证凭据、计费、提供方可用性或生成质量。本轮文档工作没有发起实际付费调用。

真实执行必须**同时**提供 `--online` 和 `CAPABILITY_ONLINE_PROVIDERS_ENABLED=true`，并配置所选提供方要求的值。环境开关是技术门，不是授权：用户必须先批准该任务的提供方、预算和上传范围。本节只描述这条路径，不执行它。

| 连接器 | `skills/` 下的脚本 | 真实执行细节 |
| --- | --- | --- |
| OpenAI 图像示例 | `image-generation/scripts/openai-image-request.mjs` | `OPENAI_IMAGE_MODEL` 覆盖请求中的 `model`。 |
| Pexo 视频示例 | `generated-video/scripts/pexo-video-request.mjs` | `--action submit\|status\|download`；状态查询使用 `project_id`，下载还使用 `asset_id`。提交确认不是完成的视频。遵循返回的 `nextAction`，不自动批准计费或重新提交。 |
| ElevenLabs 语音示例 | `speech-production/scripts/elevenlabs-speech-request.mjs` | 保存返回的音频，并在声称语音可用前单独验证。 |
| ElevenLabs 转录示例 | `audio-transcription/scripts/elevenlabs-transcription-request.mjs` | `--audio <路径>` 提供 multipart `file`/`model_id` 中的文件。上传录音需要批准。 |

脚本接受 `--timeout-ms`（默认 `60000`）。阅读 JSON stdout 的 `networkCalled` 和保存成功后的 `output`；pending 响应则需要遵循 `nextAction`。不要把单纯的提交确认当成已保存的媒体产物。

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功结果或提交确认，须检查响应。 |
| `1` | 输入无效或文件系统失败。 |
| `2` | 未启用在线执行，或缺少必需配置。 |
| `3` | 提供方/响应失败。 |
| `4` | 超时。 |
| `5` | 等待中或需要进一步操作。 |

## 9. 失败时

| 你看到的 | 含义 |
| --- | --- |
| 清单计数与目录计数不同 | 包的修订内部不一致。停下来；不要把两个数字平均。 |
| `verify-package.ps1` 打印任何 `FAIL` 行 | 安装不被接受，无论 `PASS` 计数是多少。见[安装](installation.md)。 |
| `check-requirements.ps1` 以 1 退出，提示未知角色或 Skill | 该 ID 不在本修订的目录里。要么本版本与文档描述的版本不匹配，要么 ID 拼写错误。 |
| `configured: true` 但 `availableForChild: false` | 一个空的进程值掩盖了文件值。不要打印该值。 |
| 提供方调用失败 | 超出这里的范围。存在性从不是提供方可用的证据。 |

## 相关

- [专业能力](professional-capabilities.md)：逐个 Skill 的合同。
- [安装](installation.md)：前置条件和完整套件。
- [扩展](extending.md)：这些辅助脚本所实现的注册与配置规则。
