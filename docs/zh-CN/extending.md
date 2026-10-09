# 扩展 Role、Skill 与配置

[English](../extending.md) | **简体中文**

缺少可复用方法或独立交付职责时，扩展包的原生目录。**Role** 定义身份、责任、权限边界和输出；**Skill** 提供方法。两者都不能授予超出 Task 和适用 `AGENTS.md` 的权限。派发和生命周期仍由 Orca 管理。工作者不加载协调者入口 Skill，也不创建自己的 `.dev-work/`。

- [原生注册](#原生注册)
- [编写 Skill](#编写-skill)
- [编写 Role](#编写-role)
- [声明依赖](#声明依赖)
- [校验扩展](#校验扩展)
- [选择与交付方法](#选择与交付方法)
- [配置执行主机](#配置执行主机)
- [运行离线示例](#运行离线示例)
- [排查失败](#排查失败)

## 原生注册

在独立开发检出或可丢弃副本中操作，保留现有条目，文本保存为无 BOM 的 UTF-8，使用 LF 换行。下文的 `export-contract-check` Skill 和 `export-reviewer` Role 是**示例新增项**，不是包内生产条目。2.3.0 的包随附 38 个 Skill 和 16 个 Role；校验器比较目录与清单，并未把这些数量永久写死。

| 文件 | 新增或更新内容 |
| --- | --- |
| `skills/<id>/SKILL.md` | 自包含的方法、判断标准、示例、失败信号、评估与证据 |
| `routing/skill-catalog.json` → `skills` | Skill ID、名称、描述、精确的包相对路径、可选 `requires` |
| `skills/README.md` | 每个目录 Skill 的当前 SHA256 行，以及原有 `LICENSE` 行 |
| `roles/<category>/<id>.md` | Role 合同及匹配的 front matter |
| `roles/catalog.json` → `roles` | ID、名称、类别、路径、`defaultSkills`、`optionalSkills`、可选 `requires` |
| `routing/model-routing.json` → `roles` | 每个目录 Role 的链、默认索引和最低索引 |
| `routing/role-selection.json` → `deliverableRoutes` | 需要时新增交付物映射 |
| `routing/skill-selection.json` → `riskRoutes` | 仅在相关时新增风险到方法的映射 |
| `PACKAGE-MANIFEST.json` → `deliverables` | 与最终 Role、Skill 目录匹配的数量；工作流数量保持准确 |

ID 和 Role 类别匹配 `^[a-z0-9][a-z0-9-]*$`；ID 在各自目录内唯一。Skill 路径必须是 `skills/<id>/SKILL.md`；Role 路径必须是 `roles/<category>/<id>.md`。允许正反斜杠，但不允许别名、路径穿越、包外文件、缺失文件或含链接的目录路径。Role 的默认和可选 Skill 数组必须存在，并引用已注册 ID。没有同级 Skill 回退，也没有项目目录覆盖解析器。

从 [skill-authoring.md](../../templates/skill-authoring.md) 和 [role-authoring.md](../../templates/role-authoring.md) 开始。下面给出完成后的合同示例；应把模板的编写提示替换成有用内容。

## 编写 Skill

创建 `skills/export-contract-check/SKILL.md`：

```markdown
---
name: export-contract-check
description: Compare a local export sample with its declared field and empty-result contract.
---

# Export Contract Check

## Method

Read the assigned export contract and local sample. List required fields and types, then compare every record. Distinguish a valid empty result from a missing file. Report mismatches by record and field without reproducing sensitive values.

## Worked example

For required fields id (string) and active (boolean), [{"id":"demo","active":"yes"}] fails because active is a string. An empty array passes only when the contract permits zero records.

## Failure signals

Missing fields, incorrect types, duplicate IDs, or an absent sample prevent a passing verdict. Preserve the sample and report the failing rule; do not repair source data.

## Evaluation scenario

Given one valid record, one wrong-type record, an empty array, and a missing file, classify all four against the contract and identify the evidence for each verdict.

## Completion

Return checks, observed results, and unverified items. This method grants no source-writing or orchestration authority.
```

此方法逐条比较字段及类型，把合法空结果与缺失文件分开，报告规则与证据而不复制敏感值。在 `routing/skill-catalog.json` 已有的 `skills` 数组末尾添加：

```json
{
  "id": "export-contract-check",
  "name": "Export Contract Check",
  "path": "skills/export-contract-check/SKILL.md",
  "description": "Compare local export samples with their declared contract."
}
```

核心方法留在 `SKILL.md`：必需 Skill 同时支持路径交付和全文内联。修改随包 Skill 时，它是基于记录的上游基线的**包内维护改编版**，不是冻结的逐字节副本。本项目的原创部分是 MIT；第三方 Skill 保留自己的许可证。保留 `skills/LICENSE` 或该 Skill 的 `LICENSE.txt` 中未改动的上游声明；每次有意修改正文后重新计算当前内容哈希。示例用于展示推理，不是测得的生产结果。参见[专业 Skill](professional-skills.md)。

## 编写 Role

创建 `roles/quality/export-reviewer.md`：

```markdown
---
id: export-reviewer
name: Export Reviewer
category: quality
defaultSkills:
  - export-contract-check
optionalSkills:
  - integration-verification
---

# Export Reviewer

## When to use

Independently assess a local export against the Task's approved data contract.

## Responsibilities

Read only assigned source and samples. Apply the selected methods, identify failed rules, and provide reproducible evidence. Product scope and acceptance changes belong to the user.

## Non-goals

Do not repair source, change sample data, contact services, merge branches, or dispatch workers.

## Inputs and outputs

Inputs: Task, applicable AGENTS.md, export contract, and local samples. Output: the assigned report with checks, findings, and explicit unverified items.

## Completion

All assigned cases have evidence and a verdict. Follow the injected Worker Contract and write only the assigned report path.
```

该角色只读已分配源码及样本，独立评估导出合同并写指定报告，不修复数据、不联网、不合并、不派发工作者。向 `roles/catalog.json` 的 `roles` 数组添加：

```json
{
  "id": "export-reviewer",
  "name": "Export Reviewer",
  "category": "quality",
  "path": "roles/quality/export-reviewer.md",
  "defaultSkills": ["export-contract-check"],
  "optionalSkills": ["integration-verification"]
}
```

在 `routing/model-routing.json` 的 `roles` 对象下增加 `export-reviewer` 属性，值为：

```json
{
  "chain": [
    { "tier": "sonnet", "effort": "high" },
    { "tier": "opus", "effort": "high" }
  ],
  "default": 1,
  "floor": 0,
  "taskTypes": ["Local export contract review"]
}
```

`default` 和 `floor` 是从零开始的整数索引：`0 <= floor <= default < chain.length`。链不能为空，并按文件中的 `modelLadder`、再按 `effortLevels` 严格递增；重复或降序步骤会失败。模型路由的 Role 集必须等于目录集。复用现有档位词汇与请求策略；此示例选择的是策略，并不证明主机接受或启动了该档位。所有工作者仍为 `claude`；requested/effective 模型证据与用户锁定规则保持不变。

要按交付物选择，在 `routing/role-selection.json` 的 `deliverableRoutes` 增加 `"export-contract-review": "export-reviewer"`。Role 默认值已推荐此 Skill，本例无需新增 `riskRoutes`。在已有项目中，应在 Task 中明确记录所选 Role 和 Skill，不要以为注册会自动触发派发。

## 声明依赖

依赖按条目声明；原有十六个方法不需要凭据，提供方 Skill 则声明其配置名称。要在示例中试用可选依赖，向**示例 Skill 的目录对象**添加如下 `requires` 属性（不要放进 Markdown front matter）：

```json
{
  "cli": ["pwsh"],
  "env": [
    { "name": "EXAMPLE_EXPORT_KEY", "secret": true, "purpose": "Synthetic export authentication presence check" },
    { "name": "EXAMPLE_EXPORT_MODE", "secret": false, "purpose": "Local export verification mode" }
  ],
  "api": [
    { "name": "example-export", "authEnv": "EXAMPLE_EXPORT_KEY", "purpose": "Synthetic API declaration; no request is made" }
  ]
}
```

Role 条目也支持同样的可选结构。[requirements.schema.json](../../schemas/requirements.schema.json) 只允许 `cli`、`env`、`api`，每项均可省略。声明只含**名称、元数据和用途**，绝不含值、端点、可执行 hook 或安装命令。CLI 名称匹配 `^[A-Za-z0-9][A-Za-z0-9._-]*$`，从 `PATH` 按 Application 解析；路径和命令字符串无效。环境变量名匹配 `^[A-Z][A-Z0-9_]*$`；`KEY`、`TOKEN`、`SECRET` 都是合法名称。每个 API 的 `authEnv` 必须引用同一条目里的 env 声明。API ID 使用小写 ID 模式。

同一条目内重复声明失败。跨所选条目，相同声明去重；env 的 `secret`/`purpose` 或 API 的 `authEnv`/`purpose` 不一致则失败。API 检查仅检查认证变量是否存在，并始终返回 `networkVerified: false`。它不验证认证、不联系提供方、不安装 CLI，也不产生付费 API 用量。

## 校验扩展

添加示例后，从编辑后的目录推导清单计数。把 `deliverables.roles` 和 `deliverables.professionalSkills` 分别设为下面打印的对应值，不要照抄其他修订的计数。完整的 2.3.0 包起始为 16 个 Role / 38 个 Skill，因此添加这两个示例后为 17 / 39。保留原有的 `VERSION` 及与之相同的清单 `version`；扩展旧检出不会使它升级到 2.3.0。工作流数量也要保持正确。

```powershell
(Get-Content -Raw ./roles/catalog.json | ConvertFrom-Json).roles.Count
(Get-Content -Raw ./routing/skill-catalog.json | ConvertFrom-Json).skills.Count
(Get-Content -Raw ./VERSION).Trim()
```

从编辑后的包副本目录运行这些命令。旧的 12 角色 / 16 Skill 检出添加后应为 13 / 17，且保留原版本；它仍然缺少 2.3.0 的能力。

在 PowerShell 7 会话中，将 `$package` 指向已编辑的包副本并计算哈希：

```powershell
$package = (Resolve-Path 'C:/work/orca-project-delivery-copy').Path
(Get-FileHash -LiteralPath "$package/skills/export-contract-check/SKILL.md" -Algorithm SHA256).Hash
```

向 `skills/README.md` 添加 ``| `export-contract-check/SKILL.md` | HASH |``，把 `HASH` 换为命令输出的大写结果。表必须**精确覆盖**所有目录 Skill 加 `LICENSE`，没有重复或过时行；表内路径相对于 `skills/`。维护正式扩展时，也更新介绍中的数量。哈希证明与当前表一致，不代表内容已获独立批准。

```powershell
& "$package/scripts/verify-package.ps1" -MetadataOnly
$metadataExit = $LASTEXITCODE
& "$package/scripts/verify-package.ps1"
$packageExit = $LASTEXITCODE
```

两者都必须退出 0，且 `FAIL=0`。`-MetadataOnly` 检查解析、编码、路由、入口大纲、目录、清单数量/版本和当前哈希；它跳过运行时夹具，不是完整验收门。完整套件离线运行合成的运行时与扩展夹具。数量不匹配、缺路由、无效路径或过时哈希必须失败。修正后再运行完整套件，检查 Git diff 和 `git diff --check`，然后走正常交付流程取得独立审查。

## 选择与交付方法

协调者按 `routing/skill-selection.json` 选择：除非 Task 证明无关，否则包含 Role 默认 Skill，通常 1–3 个必需、0–2 个条件 Skill，并根据实质范围/风险添加领域方法。**辅助脚本不会自动选择 Role 默认或可选 Skill**：通过 `-Skills` 精确传入必需和当前已激活的条件 ID。

示例 Task 选择 `role: "export-reviewer"`、`skills.required: ["export-contract-check"]`，仅在相关时设置 `skills.conditional: ["integration-verification"]`。完整 Task 结构见 [task-definition.json](../../templates/task-definition.json)。`assemble-task.ps1` 校验 ID，把 Role 加必需 Skill 的依赖标为必需，在 Inputs and Dependencies 内的 `### Declared Requirements` 下单独标出条件依赖。输出名称和用途，不含值。条件依赖出现在简报里不等于已激活；激活后，把对应 ID 加入并重新运行两个辅助脚本。

既有十段输入顺序保持不变：目标；Role；必需/条件 Skill；输入/依赖；范围；分支/工作树；报告合同；验收/测试；Worker Contract；最后为适用 `AGENTS.md`。`explicit-path` 提供精确的可读路径；`inline-extract` 内联必需 Skill 正文，条件 Skill 仍是路径引用。保留来源/哈希证据，要求读取或应用方法的证明。工作者执行自己的 Task，绝不运行完整协调者 Skill。

## 配置执行主机

在**实际运行辅助脚本和子进程的机器上显式传入 `-ProjectRoot`**。它必须是已有目录，通常是工作者实际的项目工作树。辅助脚本不搜索协调者目录、不复制其 `.env`、不推断远程路径，也不读取 `.dev-work` 覆盖文件。项目执行配置与指令优先级是两回事，见 [configuration-precedence.md](../../references/configuration-precedence.md)。

| 文件/来源 | 行为 |
| --- | --- |
| 进程环境 | 最高优先级，包括显式空值 |
| `<ProjectRoot>/.env` | 本地字面值；仅在所选条目声明 env 依赖时读取；保持不跟踪 |
| 显式 `-ConfigPath` | 最低优先级，只允许非秘密 JSON；没有默认配置文件名查找 |
| `.env.example` | 分享名称和空占位符，不放凭据；辅助脚本不加载它 |
| `project-config.example.json` | 起始结构，不会自动生效 |

协调者引导创建缺失的 `.env.example` 和 `project-config.example.json`，保留已有文件。它不创建填好值的 `.env`。它把 `/.env`、`/AGENTS.md` 和 `/.dev-work/` 加入本地 Git `info/exclude`；该排除文件由同一克隆的所有工作树共享。有意识地准备执行主机文件，不要在工作者处引导第二份 `.dev-work/`。使用真实本地值之前检查目标目录的忽略规则。

Dotenv 语法刻意保持简单：

- 每个物理行一个 `NAME=value`，名称大写并匹配 env 模式；名称前或名称与 `=` 之间不能有空格。允许空行和整行 `#` 注释（可缩进）。
- `=` 之后的一切都是字面值，包括空格、`#`、`$()`、`${...}`、反引号和反斜杠。不支持行内注释、`export`、展开、转义、dot-sourcing 或 shell 求值。
- 值若以 `'` 或 `"` 开始，必须以相同引号结束；移除外层引号后，内部不能再有同种引号。无引号值不裁剪空格。空值语法合法，但不满足依赖。
- 重复名称、格式错误、引号不匹配、多行值和 NUL 字符都失败。诊断指出名称/行号，不回显值。

非秘密配置使用 [project-config.schema.json](../../schemas/project-config.schema.json)：

```json
{
  "schemaVersion": 1,
  "env": { "EXAMPLE_EXPORT_MODE": "fixture" }
}
```

显式传入 `-ConfigPath 'project-config.json'`。相对路径从 `ProjectRoot` 解析；绝对路径仍必须在其内部，含链接的配置路径被拒绝。每个提供的名称都必须在包目录某处声明为非秘密；未知名称或在任意条目中标为秘密的名称会被拒绝，即使更高来源覆盖它也一样。值必须是字符串；重复 JSON 属性、未知属性、无效 JSON 和 NUL 值均失败。只有所选声明的变量才从文件加入子进程。

优先级先判断**键是否存在**，再判断值是否非空：进程 > `.env` > 显式配置。空进程覆盖会阻止非空 `.env`；空 `.env` 会阻止非空 JSON，都不向低优先级回退。`configured` 表示文件中存在非空值，`availableInProcess` 表示当前进程中存在非空值，`availableForChild` 反映最终来源。因此 `configured: true` 不代表当前 shell 或子进程可以使用它。`source` 为 `process-env`、`project-env-file`、`project-config` 或 `absent`（CLI 为 `process-command`/`absent`）。

## 运行离线示例

使用包含上述示例条目的包副本。在 **PowerShell 7 会话内部**（或 PowerShell 驱动脚本内）运行各块，这样 `@(...)` 才真正绑定为字符串数组。原生 `pwsh -File ... -Skills ...` 不是传递多元素数组的等价方式。片段使用假值和本地探针，不选择真实提供方，也不发网络请求。

创建全新的临时执行根及文件：

```powershell
$project = Join-Path ([IO.Path]::GetTempPath()) ('orca-extension-demo-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $project | Out-Null
@'
EXAMPLE_EXPORT_KEY=synthetic-not-a-credential
EXAMPLE_EXPORT_MODE=fixture
EXAMPLE_UNDECLARED=not-injected
'@ | Set-Content -LiteralPath "$project/.env" -Encoding utf8
@'
{"schemaVersion":1,"env":{"EXAMPLE_EXPORT_MODE":"json-fallback"}}
'@ | Set-Content -LiteralPath "$project/project-config.json" -Encoding utf8
@'
param([string]$Label)
if ($env:EXAMPLE_EXPORT_KEY -ne 'synthetic-not-a-credential') { exit 11 }
if ($env:EXAMPLE_EXPORT_MODE -ne 'fixture') { exit 12 }
if (Test-Path Env:EXAMPLE_UNDECLARED) { exit 13 }
if ($Label -ne 'local probe with spaces') { exit 14 }
if (-not (Test-Path -LiteralPath './.env')) { exit 15 }
Write-Output 'Synthetic child checks passed; no values printed.'
exit 23
'@ | Set-Content -LiteralPath "$project/probe.ps1" -Encoding utf8
```

在全新演示会话里运行，确保上述三个 `EXAMPLE_` 变量不存在。若已经存在，应另开干净会话，不要清除别人的配置。下面的父进程快照证明包装脚本不改变这些变量：

```powershell
$demoNames = @('EXAMPLE_EXPORT_KEY', 'EXAMPLE_EXPORT_MODE', 'EXAMPLE_UNDECLARED')
foreach ($name in $demoNames) {
  if (Test-Path "Env:$name") { throw "Use a demo session without $name" }
}
$parentBefore = [Environment]::GetEnvironmentVariables()
$selectedSkills = @('export-contract-check', 'integration-verification')
& "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role export-reviewer -Skills $selectedSkills -ConfigPath 'project-config.json'
$checkExit = $LASTEXITCODE
if ($checkExit -ne 0) { throw 'Dependency preflight failed' }
$executable = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$childArguments = @('-NoProfile', '-File', (Join-Path $project 'probe.ps1'), '-Label', 'local probe with spaces')
& "$package/scripts/invoke-with-requirements.ps1" -ProjectRoot $project -Role export-reviewer -Skills $selectedSkills -ConfigPath 'project-config.json' -Executable $executable -Arguments $childArguments
$childExit = $LASTEXITCODE
if ($childExit -ne 23) { throw "Unexpected child exit: $childExit" }
$parentAfter = [Environment]::GetEnvironmentVariables()
foreach ($name in $demoNames) {
  if ($parentAfter.Contains($name) -ne $parentBefore.Contains($name) -or $parentAfter[$name] -ne $parentBefore[$name]) { throw "Parent changed: $name" }
}
```

预期：预检退出 0；env/API 的文件配置为 true、进程可用性为 false、子进程可用性为 true；模式变量由 `.env` 覆盖 JSON；API 的 `networkVerified` 为 false。子进程只打印固定成功句，以 **23** 退出，包装脚本转发该退出码。未声明的文件变量不会出现在子进程中，但已有进程变量即使未声明也仍然继承。这不是环境隔离沙箱。外层驱动若需要返回子进程状态，应立即捕获并以 `exit $childExit` 结束。

两个脚本的公共参数为必需的 `-ProjectRoot <string>` 和 `-Role <id>`，可选的 `-Skills <string[]>`（默认空）和 `-ConfigPath <string>`（默认无）。执行脚本还要求 `-Executable <string>`，并接受 `-Arguments <string[]>`（默认空）。没有隐式选择整个目录的行为。检查脚本在依赖缺失/无效时退出 1；执行脚本在依赖缺失时拒绝启动，预检/启动错误返回 1，其余情况转发子进程退出码。

`-Executable` 是用户/Task 明确授权的命令或路径。相对路径从 `ProjectRoot` 解析；被授权的绝对可执行路径可以在根目录**之外**。配置路径约束不等于可执行文件约束。优先使用真实可执行文件/解释器加参数数组：直接 `ProcessStartInfo` 执行不保证 Windows `.cmd`/`.bat` 启动器可用。参数通过 `ArgumentList` 传递，不使用 shell 命令字符串。子进程工作目录为 `ProjectRoot`；辅助脚本保留父进程环境，在继承环境基础上只补入所选声明的文件变量。包装诊断不打印值或子进程参数，但 stdout/stderr 原样传递：子程序可能打印秘密，辅助脚本不会脱敏任意输出。这些示例已在 Windows 上运行；独立的非 Windows 执行尚未验证。

## 排查失败

| 症状 | 下一步检查 |
| --- | --- |
| 未知 Role/Skill 或无效路径 | 在辅助脚本实际使用的包副本中注册精确 ID 和文件；拒绝链接及包外路径 |
| 哈希/数量/路由失败 | 重新计算已审阅当前内容的哈希，对齐清单数量，注册新 Role 的路由 |
| `configured: true`、`availableForChild: false` | 查找空进程覆盖，不打印它的值 |
| 文件只在协调者工作树 | 在显式执行主机根目录准备目标文件；不存在自动复制 |
| API 存在性检查通过但真实操作失败 | 存在性不等于认证或网络验证；使用另行授权的诊断 |
| 有进程覆盖仍拒绝配置 | 所有提供的 JSON 名称和 schema 都会校验，包括未使用或已覆盖的名称 |
| CLI 检查通过但启动器不能启动 | 使用真实可执行文件/解释器；PATH 存在性不保证批处理兼容性 |
| 子进程泄露值 | 修正子进程输出；包装脚本无法清洗任意子进程日志 |

生命周期、审查和报告见[使用](usage.md)；扩展流程不改变这些边界。
