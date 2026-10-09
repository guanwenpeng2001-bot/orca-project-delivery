# 专业能力教程

[English](../professional-capability-tutorial.md) | **简体中文**

本教程面向完整的 **2.3.0 包：38 个 Skill、16 个角色**。它在临时项目中使用合成值演练本地工具、离线提供方夹具及限定范围的依赖注入。没有发起实际提供方或付费调用；离线模拟不验证生成质量。

从包根目录在 PowerShell 7 会话中依次运行代码块，使用 Node.js 或 Python 的示例需要相应运行时可用。旧版 2.2.0 运行时上的纯文档检出缺少新脚本；这里的相对链接和命令指向组合后的 2.3.0 树。

## 1. 确认你安装的是什么

在包目录中：

```powershell
Get-Content -Raw .\VERSION
Get-Content -Raw .\PACKAGE-MANIFEST.json
```

读三个字段：

| 字段 | 它告诉你什么 |
| --- | --- |
| `VERSION` | 包的修订。2.3.0 是能力版本。 |
| `deliverables.professionalSkills` | 包声称的 Skill 数。能力版本声称 38。 |
| `deliverables.roles` | 包声称的角色数。能力版本声称 16。 |

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
if ($version -ne '2.3.0' -or $manifest.version -ne $version -or
    $skills -ne 38 -or $roles -ne 16 -or
    $manifest.deliverables.professionalSkills -ne $skills -or
    $manifest.deliverables.roles -ne $roles) {
  throw 'Install the complete matching 2.3.0 package before continuing.'
}
```

## 2. 离线校验包

```powershell
pwsh -NoProfile -File .\scripts\verify-package.ps1
```

验收标准是退出码 0，且最后一行含 `FAIL=0`。`PASS` 计数不是常数：它描述你正在运行的修订，所以引用你观察到的那一行，而不是一个记得的数字。

这是对包结构的**离线验证**：解析、编码、路由、目录计数和当前 Skill 哈希。它不启动浏览器、数据库、编码器或模型。一次通过不是关于生成产出的证据。

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

这些命令在完整的 2.3.0 包根目录运行，只写入一个新的临时目录。它们使用已对照能力运行时检出核验的稳定脚本和旗标。没有联系提供方。

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

预期退出码全部为 `0`。压缩结果打印 `status: "compressed"` 及字节数。无损候选结果没有变小则打印 `status: "no-gain"`，且不创建输出文件。manifest 记录 Harbor、`#123456` 和五种图标尺寸。Markdown 包含夹具中的标题和项目符号。结束后删除 `$work`。

Office/PDF 生成命令是：

```powershell
python -I ./skills/document-production/scripts/office-document.py --input ./tests/fixtures/capability/document-input.json --format docx --output "$work/notes.docx"
```

按需要把 `docx` 和 `.docx` 换成 `pptx`、`xlsx` 或 `pdf`。成功时 JSON 含 `reopened: true`。缺少库时打印 `missing-dependency` 并以 `2` 退出；文档或输入失败以 `1` 退出。仅在你选择的环境中安装 `skills/document-production/scripts/requirements.txt` 固定的精确版本。非 ASCII 的 PDF 文本还需要 `--font`，指向覆盖这些字形且许可允许的 TrueType 字体。本教程环境缺少这些库，因此这里没有执行 Office/PDF 生成。

### 资产验收

这些是任务实际产出的验收条件，不表示每项检查都已通过。每个适用行都记录命令、退出码、产物路径和观察结果；没有运行的检查要明确标出。

| Skill | 检查 | 验收条件 |
| --- | --- | --- |
| `icon-assets` | 打开选定 SVG；检查来源和图标集许可记录。 | 图标与 viewBox 正确，目标尺寸下无裁切，记录来源和许可。联网查询需要单独的执行批准。 |
| `svg-logo-design` | 解析 SVG，并以目标小尺寸和大尺寸打开。 | SVG 合法、图形可辨、无裁切或意外外部引用；视觉审查与解析分开。 |
| `web-assets` | 重新打开导出文件、读取尺寸，并解析 manifest 中的图标路径。 | 尺寸和格式符合要求，必要时保留透明度，manifest 引用的文件全部存在。 |
| `image-compression` | 校验输入/输出 PNG 结构，对比解码后的像素、alpha 和字节数。 | chunk/CRC 合法且无损像素相同；记录实际节省或明确无收益。无效输入必须失败且不产生新输出。 |

## 6. 运行离线提供方夹具

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
node ./skills/image-generation/scripts/openai-image-request.mjs --online --request ./tests/fixtures/capability/openai-image-request.json --output "$work/online.png"
$disabledOnline = $LASTEXITCODE
```

预期退出码依次为 `0`、`3`、`0`、`4`、`0`、`3`、`2`。图像和语音成功会保存文件。图像与转录夹具模拟 HTTP 失败。Pexo 成功夹具只是 SSE 提交确认；超时以 `4` 退出。最后一条命令在没有单独启用真实执行时以 `2` 退出，错误为 `online-disabled`。

## 7. 真实执行必须显式启用

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

## 8. 失败时

| 你看到的 | 含义 |
| --- | --- |
| 清单计数与目录计数不同 | 包的修订内部不一致。停下来；不要把两个数字平均。 |
| `verify-package.ps1` 打印任何 `FAIL` 行 | 安装不被接受，无论 `PASS` 计数是多少。见[安装](installation.md)。 |
| `check-requirements.ps1` 以 1 退出，提示未知角色或 Skill | 该 ID 不在本修订的目录里。要么能力包尚未合并，要么 ID 拼写错误。 |
| `configured: true` 但 `availableForChild: false` | 一个空的进程值掩盖了文件值。不要打印该值。 |
| 提供方调用失败 | 超出这里的范围。存在性从不是提供方可用的证据。 |

## 相关

- [专业能力](professional-capabilities.md)：逐个 Skill 的合同。
- [安装](installation.md)：前置条件和完整套件。
- [扩展](extending.md)：这些辅助脚本所实现的注册与配置规则。
