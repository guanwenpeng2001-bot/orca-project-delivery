# 使用已安装的外部 Skill

[English](../external-skills.md) | **简体中文**

**3.1.1** 支持通过显式配置使用已安装的外部 Skill，并与包内 **69 个 Skill、18 个 Role、5 个工作流** 混用。注册不会复制或改写第三方文件，不修改包目录，也不增加包计数。上游声明与许可证保留在原安装处。包内原生扩展见[扩展指南](extending.md)，环境规则见[配置优先级](../../references/configuration-precedence.md)。

## 注册已安装的文件

组装和两个依赖辅助脚本都应显式传入 `-ConfigPath 'project-config.json'` 以及执行主机的 `-ProjectRoot`。不会自动查找配置文件名。配置文件必须在该根目录内，但它注册的外部 Skill 可以位于根目录之外。

```json
{
  "schemaVersion": 2,
  "env": {},
  "externalSkills": [
    {
      "id": "vendor-method",
      "path": "C:/Users/you/.agents/skills/vendor-method/SKILL.md",
      "version": "upstream-declared-1.0",
      "requires": { "cli": ["pwsh"] }
    },
    {
      "id": "project-method",
      "path": "third-party/project-method/SKILL.md"
    }
  ],
  "roleBindings": {
    "software-implementer": {
      "defaultSkills": ["test-driven-development", "vendor-method"],
      "optionalSkills": ["integration-verification", "project-method"]
    }
  }
}
```

使用前将两个路径替换为实际存在的文件。完整绝对路径可以指向 `ProjectRoot` 外的全局安装；相对路径从显式 `ProjectRoot` 解析，不以配置目录或包目录为基准。每个需要它的工作树都必须准备相对文件。绝对安装路径属于具体机器，在执行主机上也必须存在。

- 配置版本 1 仍然**只支持 env**，拒绝 `externalSkills`/`roleBindings`。版本 2 允许这两个字段，但仍要求 `env`（没有值时用 `{}`）。参见 [schema](../../schemas/project-config.schema.json)。
- 每个注册项必须有 `id` 和 `path`，可选 `name`、`description`、`version`、`requires`，未知字段被拒绝。ID 匹配 `^[a-z0-9][a-z0-9-]*$`，区分大小写且唯一，不能与包内 ID 冲突。注册别名可以不同于上游 frontmatter 的 `name`，无需重命名源文件。不同别名可以指向同一文件，不按内容去重。
- 使用配置时校验所有注册项和绑定，包括未选择的项。文件必须存在；目录、`..` 穿越段、符号链接及 reparse point 均被拒绝。使用链接目录的安装器不受此解析器支持，应使用不经过链接段的实际可读安装路径。
- 不提供自动安装、扫描、下载、更新、环境或路径插值、frontmatter 依赖解析，也不模拟 hook 或其他宿主功能。外部 Skill 是受 Task 和 `AGENTS.md` 约束的专业说明，不会授予新的执行权限。

## 解析 Task 选择

使用完整的 [task-definition.json](../../templates/task-definition.json)。组装现在按 [task-definition.schema.json](../../schemas/task-definition.schema.json) 校验整个 Task，包括 branch、artifacts 和 Orca 字段；必需字段即使允许取 `null` 也应保留。

| Task 选择 | 组装行为 |
| --- | --- |
| 完全省略 `skills`，且所选 Role 有配置绑定 | `defaultSkills` 成为 `skills.required`；`optionalSkills` 成为 `skills.conditional` |
| 完全省略 `skills`，但该 Role 没有绑定（包括无配置或 v1 配置） | 写简报前拒绝；不推断原生 Role 默认值 |
| `"skills": {"required": ["project-method"], "conditional": []}` | 显式数组覆盖绑定，不与之合并 |
| `"skills": {"required": [], "conditional": []}` | 合法的显式空选择，无绑定时也合法 |
| `skills: null`、`{}`、类型错误、缺少数组、`skills` 内多余字段 | 写简报前因 schema 校验失败而拒绝 |

每个绑定必须同时提供 `defaultSkills` 和 `optionalSkills` 数组，并指定已有包内 Role。两个数组均可混用包内和已注册外部 ID。当该 Role 有绑定时，内嵌 Role YAML 与 Skill 列表正文反映**最终生效的 Task 选择**，包括显式覆盖；空列表在 YAML 中为 `[]`，正文为 `None`。JSON 的 `roleBinding` 单独报告配置绑定，`skills` 报告解析结果。原 Role 文件保持不变。无绑定时保留旧 Role 正文，由 Required/Conditional Skills 段标明 Task 的显式选择。

旧的顶层扩展字段仍可使用。只有已知的 `skillz` 拼写错误被明确拒绝；不要依赖任意拼写错误检测（例如 `skils` 仍被视为旧扩展字段）。

## 声明并检查依赖

在注册项的 `requires` 中声明外部依赖，使用与包内条目相同的[依赖 schema](../../schemas/requirements.schema.json)：CLI 名称、env 声明（`name`、`secret`、`purpose`）和 API 声明（`name`、`authEnv`、`purpose`）。每个 API 的 `authEnv` 必须由同一条目声明。无法从任意正文推断依赖。声明中不能放安装命令、hook、端点或秘密值。

配置 `env` 只能存放已声明为非秘密的变量值，包括外部 Skill 注册声明的名称。秘密来自执行环境或有意识准备的本地 `.env`。进程值（包括空覆盖）优先于项目 `.env`，后者优先于显式配置；空值不会回退。声明冲突会失败；API 只检查存在性并报告 `networkVerified: false`。依赖缺失时报告具名的 `cli:`、`env:`、`api:` 项并阻止子进程启动。

**依赖辅助脚本绝不推断 Role 绑定或默认值。** 读取组装 JSON 的 `skills.required`，只添加已激活的 `skills.conditional`，然后把数组及相同的 `ProjectRoot`、`ConfigPath` 显式传给两个脚本。数组示例须在 PowerShell 7 内部运行，不能用原生 `pwsh -File ... -Skills ...` 多数组命令替代。子进程工作目录为 `ProjectRoot`；所选声明的文件值补入其继承环境，父进程保持不变，并转发子进程退出码。子进程输出不会脱敏。

## 交付说明与解析资源

`explicit-path` 引用原始绝对 `SKILL.md` 路径并要求工作者读取。`inline-extract` 内联必需 Skill 正文快照、降低标题层级并把开头 frontmatter 围成数据代码块；两个模式中的条件 Skill 都保留为路径引用。源文件后续修改不会更新内联快照。两个模式都不保证任意宿主实际加载或信任 Skill，也不保证支持上游宿主专有功能。

组装和检查器 JSON 仅对所选外部条目输出 `skillProvenance`；仅选择包内条目时不增加该字段。每条包含 `id`、`origin: "project-external"`、解析后的绝对 `path`、原声明 `declaredPath`、原样传入 `-ConfigPath` 的 `configPath`（可能是相对路径）、原目录的绝对 `resourceBase`、观察到的小写 `sha256` 和 `declaredVersion`（未声明则为 null）。声明版本没有经过验证；哈希标识入口文件内容，不代表批准，也不涵盖所有同级资源。简报中同样包含来源信息。

**两个交付模式**都应从原始 `resourceBase` 解析 Skill 的相对脚本和资源，不以工作者当前目录、包目录或简报位置为基准。执行辅助脚本不会自动发现或运行这些脚本；Task 必须授权可执行文件和资源路径。以下配方显式把 `resourceBase` 与 `resources/probe.ps1` 拼接。

## 离线演练

从包根目录在 PowerShell 7 中运行下方完整代码块；文档测试另需 Node。它创建独立临时项目及项目外的合成已安装 Skill，并创建项目相对 Skill。这些是夹具，不下载内容，也不修改已有安装。它组装两个交付模式、预检解析后的选择、运行原位置同级脚本，最后核对源文件哈希和具名依赖失败。不调用提供方，不读取真实凭据，结束时只移除本次唯一的临时夹具目录。

```powershell
$ErrorActionPreference = 'Stop'
$package = (Get-Location).Path
$demo = Join-Path ([IO.Path]::GetTempPath()) ('orca-installed-demo-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $demo 'project'
$installed = Join-Path $demo 'installed-method'
New-Item -ItemType Directory -Path "$installed/resources", "$project/third-party/project-method" -Force | Out-Null
try {
  if (Test-Path Env:ORCA_EXTERNAL_DEMO_MODE) { throw 'Use a session without ORCA_EXTERNAL_DEMO_MODE' }
  @'
---
name: upstream-method-name
---
# Installed method
Run resources/probe.ps1 relative to this Skill directory when the Task authorizes it.
'@ | Set-Content -LiteralPath "$installed/SKILL.md" -Encoding utf8
  @'
if ($env:ORCA_EXTERNAL_DEMO_MODE -ne 'offline') { exit 81 }
if ((Get-Content -LiteralPath "$PSScriptRoot/sibling.txt" -Raw).Trim() -ne 'sibling-resource') { exit 82 }
if ((Get-Location).Path -eq $PSScriptRoot) { exit 83 }
Write-Output 'External sibling resource passed.'
exit 37
'@ | Set-Content -LiteralPath "$installed/resources/probe.ps1" -Encoding utf8
  'sibling-resource' | Set-Content -LiteralPath "$installed/resources/sibling.txt" -Encoding utf8
  '# Project method' | Set-Content -LiteralPath "$project/third-party/project-method/SKILL.md" -Encoding utf8
  '# Demo rules: execute only the authorized offline sibling probe.' | Set-Content -LiteralPath "$project/AGENTS.md" -Encoding utf8
  $sourcePaths = @("$installed/SKILL.md", "$installed/resources/probe.ps1", "$installed/resources/sibling.txt", "$project/third-party/project-method/SKILL.md")
  $before = @($sourcePaths | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
  $config = @{
    schemaVersion = 2
    env = @{ ORCA_EXTERNAL_DEMO_MODE = 'offline' }
    externalSkills = @(
      @{ id = 'vendor-method'; path = "$installed/SKILL.md"; version = 'declared-demo'; requires = @{
        cli = @('pwsh'); env = @(@{ name = 'ORCA_EXTERNAL_DEMO_MODE'; secret = $false; purpose = 'Offline demo mode' })
      } },
      @{ id = 'project-method'; path = 'third-party/project-method/SKILL.md' }
    )
    roleBindings = @{ 'software-implementer' = @{
      defaultSkills = @('test-driven-development', 'vendor-method', 'project-method')
      optionalSkills = @('integration-verification')
    } }
  }
  $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$project/project-config.json" -Encoding utf8
  $task = Get-Content -LiteralPath "$package/templates/task-definition.json" -Raw | ConvertFrom-Json
  $task.taskKey = 'installed-demo'
  $task.title = 'Verify an installed method'
  $task.objective = 'Run the authorized local sibling probe without changing installed sources.'
  $task.role = 'software-implementer'
  $task.branch.worktree = $project
  $task.artifacts.reportPath = "$project/result.md"
  $task.artifacts.evidencePath = "$project/evidence.json"
  $task.PSObject.Properties.Remove('skills')
  foreach ($mode in @('explicit-path', 'inline-extract')) {
    $task.skillDeliveryMode = $mode
    $task | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$project/task.json" -Encoding utf8
    $assembled = & "$package/scripts/assemble-task.ps1" -ProjectRoot $project -TaskDefinitionPath "$project/task.json" -OutputPath "$project/$mode.md" -ConfigPath 'project-config.json' | ConvertFrom-Json
    if (-not $assembled.ok) { throw 'Assembly failed' }
    $selectedSkills = @($assembled.skills.required)
    if (($selectedSkills -join ',') -ne 'test-driven-development,vendor-method,project-method') { throw 'Unexpected selection' }
    $checked = & "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role $task.role -Skills $selectedSkills -ConfigPath 'project-config.json' | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $checked.ok) { throw 'Preflight failed' }
    $origin = $assembled.skillProvenance | Where-Object id -eq 'vendor-method'
    if ($origin.configPath -ne 'project-config.json' -or $origin.declaredVersion -ne 'declared-demo') { throw 'Unexpected provenance' }
    if ($origin.sha256 -cne (Get-FileHash -LiteralPath "$installed/SKILL.md").Hash.ToLowerInvariant()) { throw 'Entry hash differs' }
    $resource = Join-Path $origin.resourceBase 'resources/probe.ps1'
    $executable = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    & "$package/scripts/invoke-with-requirements.ps1" -ProjectRoot $project -Role $task.role -Skills $selectedSkills -ConfigPath 'project-config.json' -Executable $executable -Arguments @('-NoProfile', '-File', $resource)
    if ($LASTEXITCODE -ne 37) { throw 'Child exit was not forwarded' }
  }
  if (Test-Path Env:ORCA_EXTERNAL_DEMO_MODE) { throw 'Parent environment changed' }
  $after = @($sourcePaths | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
  if (Compare-Object $before $after) { throw 'Installed source changed' }
  $config.externalSkills[0].requires.cli = @('orca-external-demo-missing-command')
  $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$project/project-config.json" -Encoding utf8
  $missing = & "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role $task.role -Skills $selectedSkills -ConfigPath 'project-config.json' | ConvertFrom-Json
  if ($LASTEXITCODE -ne 1 -or $missing.missing -notcontains 'cli:orca-external-demo-missing-command') { throw 'Missing CLI was not named' }
  Write-Output 'External Skill walkthrough passed: both delivery modes, original resources, unchanged sources, named failure.'
} finally {
  Remove-Item -LiteralPath $demo -Recurse -Force
}
```

预期输出两次 `External sibling resource passed.`，最后输出演练成功句。内部子进程退出码 **37** 是预期值；最后的缺少 CLI 检查有意返回 **1**。Node 文档测试在成功的驱动中检查这些结果。非 Windows 执行、真实宿主加载和方法效果尚未验证；宣称真实 Task 使用了该方法之前，仍需审阅简报以及工作者读取或应用方法的证据。
