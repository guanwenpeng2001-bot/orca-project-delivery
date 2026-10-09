# 专业能力教程

[English](../professional-capability-tutorial.md) | **简体中文**

本教程不安装任何新东西，也不调用任何提供方。它做三件事：读能力合同，证明包可以离线校验，以及用假值在一个临时项目上运行现有的依赖辅助脚本。这是 2.3.0 里今天就能执行的部分。

本教程有意不做的事：

- 不渲染视频、不生成图像、不合成语音、不转录音频。这些是真实在线或本地执行步骤，本版本都没有跑过。
- 不把 22 个新 Skill 或 4 个新角色加进目录。注册属于能力包；本教程只消费一个已经包含它的包。
- 不编造命令旗标。下面的命令是本修订里实际存在的辅助脚本。新 Skill 的走读只在它们的接口进入包内之后才写，并且发布前对照该包核验。

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

两个计数必须等于清单字段。如果不相等，包内部不一致，本教程的其余部分不适用；停下来报告这个差异，不要继续。

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

### 当新 Skill 声明了依赖时会怎样

一旦能力包为一个 Skill 声明了 `requires`，同样的两条命令不加新旗标即可使用。显式选中该 Skill，辅助脚本就只检查它声明的内容：

```powershell
& "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role media-producer -Skills @('image-compression')
```

把结果读成四件分开的事实，而不是一个结论：

| 字段 | 含义 |
| --- | --- |
| `configured` | 文件中存在非空值。 |
| `availableInProcess` | 当前进程中存在非空值。 |
| `availableForChild` | 会到达子进程的值。空的进程值覆盖非空的文件值。 |
| `networkVerified` | API 检查始终为 `false`。存在性不是认证、余额或可达性。 |

在 `media-producer` 和 `image-compression` 进入你正在运行的包的目录之前，不要运行这个示例。对本修订，辅助脚本以 `Unknown role selector.` 拒绝并以 1 退出，这是正确的结果；未知的 Skill ID 同样以 `Unknown skill selector.` 失败。

## 5. 知道什么没有运行

| 步骤 | 标签 | 本教程是否运行 |
| --- | --- | --- |
| 读取 `VERSION`、清单和目录 | 方法 | 是 |
| `verify-package.ps1` | 离线验证 | 是 |
| 对 `software-implementer` 运行 `check-requirements.ps1` | 已实现的本地工具 | 是 |
| 浏览器、PostgreSQL、FFmpeg、HyperFrames、文档库 | 已实现的本地工具（在包声明它们的地方） | 否。不声称。 |
| OpenAI 图像、Pexo 视频、ElevenLabs 语音或转录 | 真实在线，未验证 | 否。这些是示例连接器，不是选定的提供方。 |

示例连接器展示的是未来配置的形状：一个秘密环境变量名，例如 `OPENAI_API_KEY`、`PEXO_API_KEY` 或 `ELEVENLABS_API_KEY`，一个指向它的 `authEnv`，以及一次返回 `networkVerified: false` 的 API 检查。这些名字是取自各示例所指向上游的占位符。没有提供密钥，没有调用端点，提供方的选择仍是用户按任务做出的决定，并带有预算和上传范围。

## 6. 失败时

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
