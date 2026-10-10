# 安装

[English](../installation.md) | **简体中文**

版本 2 项目注册、混合绑定、解析后的依赖选择及原位置同级资源，见[已安装外部 Skill 演练](external-skills.md)。包内 Skill 不需要单独安装。

本指南安装 `orca-project-delivery` 协调者 Skill，使 Claude Code 协调者会话能从控制工作树加载它。本包是一个普通文件目录 — 没有安装程序、没有包注册表，也没有构建步骤。

本指南描述2.7.0 包（46 个 Skill / 16 个角色 / 4 个工作流）。安装完整且匹配的版本。运行示例前先做[教程中的版本及目录检查](professional-capability-tutorial.md#1-确认你安装的是什么)。版本不匹配就不是本版本。

## 前置条件

| 要求 | 说明 |
| --- | --- |
| Windows | 所有脚本只在 Windows 上运行过。其他平台未经测试。 |
| PowerShell 7+（`pwsh`） | Windows PowerShell 5.1 不够。用 `pwsh -NoProfile -Command '$PSVersionTable.PSVersion'` 检查。 |
| Git | 在 `PATH` 上；用于分支、工作树、合并和证据校验。 |
| Claude Code | 已安装、在 `PATH` 上，并且已认证。所有工作者都是 Claude Code 智能体。 |
| Orca Runtime | `orca` CLI，加上已安装的全局 `orchestration`、`orca-cli` 和 `orca-per-workspace-env` Skill。它们拥有 Run / Task / Dispatch / Worker 生命周期；本包从不替代它们。 |
| 专业 Skill | **随包附带** — 全部 46 个专业 Skill 位于本包 `skills/<skill-id>/SKILL.md`。无需单独安装。原有十六个追溯到 [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills)；原有十六个的上游基线及后续原创方法的公开参考见 `skills/README.md`。 |

`routing/skill-catalog.json` 引用的 Skill 是原有十六个加上 2.3.0 新增的二十二个和 2.4.0 新增的八个。原有十六个是：codebase-reconnaissance、technical-research、product-discovery、product-design、requirements-analysis、solution-architecture、api-design、database-design、implementation-planning、test-driven-development、systematic-debugging、code-review、security-review、performance-review、integration-verification 和 merge-conflict-resolution。新增的 Skill 及其证据标签列在[专业能力](professional-capabilities.md)。

选定能力工具还需要本地依赖；安装本 Skill 不会替你安装它们，应在实际执行主机核验。

| 选定功能 | 运行时 / 依赖 | 缺失时行为 |
| --- | --- | --- |
| 对比度、字幕、合成/探测、manifest、Markdown | Node.js 22.15+，随包 Skill 文档规定的基线，适用于含 PNG 工具的完整教程 | 先解决具名可执行文件缺失或 Node 版本不支持。 |
| 浏览器示例 | Node 调用器、带 Playwright 的 Python、已安装的 Chromium | runner 按名报告缺失依赖，仅对应可选测试跳过。 |
| DOCX/PPTX/XLSX/PDF | Python 3.10+ 及 `skills/document-production/scripts/requirements.txt` 的固定版本 | 缺库退出 2，无效/不支持内容退出 1；非 ASCII PDF 还需 `--font`。 |
| 真实转码 | 本地 `ffmpeg`、`ffprobe`，可能不在 PATH | 必要时使用显式可执行文件路径；已保存探测结果的比较只需 Node。 |

## 目录约定

本包设计上放在技能根目录：

```text
~/.agents/skills/                 # 技能根目录（%USERPROFILE%\.agents\skills）
├── orchestration/                # 全局 Orca Skill — 不要覆盖
├── orca-cli/                     # 全局 Orca Skill — 不要覆盖
├── orca-per-workspace-env/       # 全局 Orca Skill — 不要覆盖
└── orca-project-delivery/        # <-- 本包（含 skills/ 子树）
```

两条规则：

1. 不要覆盖 Orca 提供的 Skill（`orchestration`、`orca-cli`、`orca-per-workspace-env`）。本包是加在它们之上的，从不替换它们。
2. 随包专业 Skill 从本包的 `skills/` 目录解析。外部 Skill 必须在版本 2 项目配置中显式注册，见[外部 Skill](external-skills.md)。随包条目缺失时**不会**静默回退到 `~/.agents/skills` 下的同级安装。

运行时创建的项目本地状态（`AGENTS.md`、`.dev-work/`）位于你交付的每个*项目*里，不在本包目录中。

工作者交付使用 `explicit-path`：协调者在任务里写明所选 Skill 可读的 `SKILL.md` 精确路径，并要求工作者读取它。路径不可读时，`inline-extract` 收录所需章节，并记录来源路径、哈希/版本、已包含的标题和省略的章节。只报一个 Skill 名称并不能证明它已被加载。

## 安装步骤

```powershell
# 1. 把包克隆到技能根目录（根目录不同时请自行调整）
git clone https://github.com/guanwenpeng2001-bot/orca-project-delivery.git "$env:USERPROFILE\.agents\skills\orca-project-delivery"

# 2. 校验安装（期望输出见下一节）
pwsh -NoProfile -File "$env:USERPROFILE\.agents\skills\orca-project-delivery\scripts\verify-package.ps1"
```

Skill 列表与上游来源见 [专业 Skill](professional-skills.md)。克隆本仓库即完成专业 Skill 的完整安装 — 不需要配套的复制步骤。

如果技能根目录里已有旧副本，请走 [升级](#升级)，不要直接克隆覆盖。

如果不想用默认位置，可以克隆到任意目录 — 工作者仍通过 `scripts/assemble-task.ps1` 从包自身的 `skills/` 目录解析 Skill。

## 校验安装

在包目录运行离线验收套件：

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.agents\skills\orca-project-delivery\scripts\verify-package.ps1"
```

健康安装的输出大致是：

- 许多 `PASS <check>` 行（解析、编码、路由、元数据、运行时夹具、证据夹具等）；
- 一行 `skills: N/N resolved (... package-bundled)` 汇总，其中 N 是你安装的修订的 Skill 数（2.7.0 能力版本为 46）；
- 最后一行形如 `SUMMARY PASS=<n> FAIL=0`；
- 进程退出码为 0。

引用你观察到的 `SUMMARY` 行。通过计数描述的是该修订，不是一个要从旧版本背下来的数字。

套件对包本身是只读的：所有夹具和副本都建在临时目录（`orca-package-verification-*`）下，结束时删除。结论看 `SUMMARY` 行和退出码；任何 `FAIL` 行都表示安装不被接受。

关于同级证据校验器：单独在运行时使用 `scripts/validate-git-evidence.ps1` 时，读它打印的 JSON `status` 字段，不要只看退出码 — `PASS` 和 `NOT_APPLICABLE` 都以 0 退出，而 `NOT_APPLICABLE` 不是验收。

## 扩展与本地执行配置

新增方法或职责时，按[扩展指南](extending.md)使用原生目录，包括当前内容哈希、清单数量与模型路由。原有十六个是维护中的 MIT 改编版，其后三十个为原创方法；本项目的原创部分是 MIT，第三方 Skill 保留自己的许可证，有意修改须先审阅再更新哈希。`verify-package.ps1 -MetadataOnly` 是快速结构检查，不能替代完整套件。上面的汇总描述你安装的修订；成功要求没有失败，不是永远固定数量。

能力版本为软件、本地资产、图像和音视频、文档新增了方法。安装它并不会运行其中任何一个。[能力教程](professional-capability-tutorial.md)检查安装并运行有界本地工具和依赖辅助脚本；它不调用提供方，包套件通过也不是关于生成产出的证据。

引导仅在缺失时创建 `.env.example` 与 `project-config.example.json`，已有文件保持不变。它把 `/.env` 加入本地 Git `info/exclude`，同一克隆的工作树共享此文件。实际执行主机上填有值的 `.env` 保持不跟踪。工作者必须显式提供自己的 `ProjectRoot`；辅助脚本不复制协调者配置，也不创建工作者 `.dev-work/` 状态。原有十六个不声明凭据依赖。一个 2.7.0 的 Skill 只在它点名时才声明凭据，文档中提到的在线连接器是示例，不是你已经选定的提供方。真实密钥不属于仓库。

## 升级

已安装的包是原地部署的，所以升级就是替换目录内容并重新校验：

```powershell
cd "$env:USERPROFILE\.agents\skills\orca-project-delivery"
git pull --ff-only
pwsh -NoProfile -File scripts\verify-package.ps1
```

更新前先看 `git status --short`，保留本地改动；不要覆盖已定制的安装。基于复制的安装，替换包文件前先备份旧目录。项目本地状态不受影响。

旧运行仍可读，但未完成的源码合并必须按当前门重建证据。用 `scripts/validate-run.ps1` 校验项目状态，用 `scripts/validate-git-evidence.ps1` 单独校验 Git 证据；升级不会自动迁移证据。

## 卸载

删除包目录：

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.agents\skills\orca-project-delivery"
```

这就是全部足迹。本包不留注册表项，也不在你交付的项目之外留状态；每个已交付项目保留自己的 `AGENTS.md` 和 `.dev-work/`，需要时单独删除。除非不再使用任何依赖它们的东西，否则不要删除全局 Orca Skill。

## 安装失败排障

### 缺少随包 Skill

症状：校验套件打印

```text
FAIL metadata/skill-paths: skill file missing: <...>\skills\code-review\SKILL.md
```

或 `metadata/bundled-skill-integrity` 下的哈希失败。

原因：某个随包的 `skills/<skill-id>/SKILL.md` 缺失、被本地删除，或不再匹配 `skills/README.md` 里的当前 SHA256 表。先检查并保留本地改动。意外损坏从包 Git 恢复；有意改编则按[扩展指南](extending.md)审阅正文并更新哈希，然后重跑套件。

### 找不到 PowerShell 7

症状：`pwsh` 无法识别，或套件拒绝在 Windows PowerShell 5.1 下运行。

修复：安装 PowerShell 7+，并用 `pwsh -NoProfile -File <script>` 显式调用脚本。验证：

```powershell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
```

### Git 配置注入

症状：脚本失败，报 `fatal: missing config key GIT_CONFIG_KEY_0`，但 Git 在普通终端里正常。

原因：有些宿主注入了 `GIT_CONFIG_COUNT`，同时剥离名称含 `KEY` / `TOKEN` / `SECRET` 的环境变量，留下一个孤立的计数，使每次 Git 调用都失败。引导、创建运行、对账、发布、运行校验和能力探测脚本会防护这种孤立计数。包套件会隔离其子进程的 Git 环境。对其他 Git 调用，检查并修复调用方环境；不要不加区分地清除仍然成对有效的配置。

```powershell
# 在你自己的 shell 里检查并清除孤立变量
Get-ChildItem Env:GIT_CONFIG_*
if ($env:GIT_CONFIG_COUNT -and -not $env:GIT_CONFIG_KEY_0) {
    Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
}
```

### 权限与执行策略

症状：`pwsh -File <script>` 因文件加载或执行策略错误而失败，或在技能目录内写入失败。

修复：

```powershell
# 查看当前用户的有效策略
pwsh -NoProfile -Command 'Get-ExecutionPolicy -List'

# 锁定机器上的常见修复（有意识地选一个）
pwsh -NoProfile -Command 'Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
# 或只对单次调用绕过策略
pwsh -NoProfile -ExecutionPolicy Bypass -File '<script>'
```

如果技能目录本身对你的账户不可写，授予写权限，或把技能根目录换到别处。

### 校验报告了意外的 FAIL 计数

在假定成功之前，先看每一行 `FAIL` 和 `skills: ... resolved` 那一行。确认你运行的 `scripts/verify-package.ps1` 来自刚刚安装的目录，`VERSION` 与预期发布一致，并且没有 `FAIL` 行滚出屏幕。任何 `FAIL` 行都表示安装不被接受，与 PASS 计数无关。
