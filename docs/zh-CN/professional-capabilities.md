# 专业能力

[English](../professional-capabilities.md) | **简体中文**

3.1.0 在现有交付、工程和媒体方法上新增游戏开发能力。本包共有 **69 个专业 Skill**、**18 个角色**和 **5 个工作流**。本指南说明各项能力的范围与验证限制。

本指南描述3.1.0 包：69 个 Skill、18 个角色、5 个工作流。安装完整且匹配的版本。运行[教程](professional-capability-tutorial.md)前，确认 `VERSION` 为 `3.1.0`、`routing/skill-catalog.json` 有 69 个 Skill、`roles/catalog.json` 有 18 个角色、`workflows/` 有 5 份定义，且 `PACKAGE-MANIFEST.json` 与之相符。教程会拒绝版本不匹配的安装。

## 游戏开发方法

3.1.0 新增 23 个方法：四个设计 Skill（`game-design`、`game-economy-design`、`game-level-design`、`game-3c-design`）；五个工程 Skill（`gameplay-programming`、`game-physics`、`game-content-pipeline`、`game-performance`、`game-multiplayer`）；六个引擎 Skill（`engine-urhox`、`engine-cocos-creator`、`engine-unity`、`engine-godot`、`engine-unreal`、`engine-web-canvas`）；三个制作/测试 Skill（`game-asset-pipeline`、`game-audio`、`game-testing-ladders`）；五个发行/运营 Skill（`game-publishing`、`game-build-release`、`game-live-ops`、`game-monetization-iaa`、`game-monetization-iap`）。

| 角色 | 默认 Skill | 可选 Skill |
| --- | --- | --- |
| `game-designer` | `game-design`、`game-economy-design`、`game-level-design` | `game-3c-design`、`game-monetization-iaa`、`game-monetization-iap`、`game-live-ops` |
| `game-test-engineer` | `game-testing-ladders` | `game-performance`、`game-publishing` |

[game-development 工作流](../../workflows/game-development.md) 按平台、引擎、品类、变现方式和熟悉度选择方法。设计先于玩法/素材并行制作，经济设计先于变现实施，分层测试与每次发布的就绪/合规复核先于最终验证，之后提供运营交接。现有 software-implementer 与 media-producer 仍负责实施和素材制作。

这些是方法文档，包含新手导航与资深决策判据，不附带引擎或商店自动化，也不声称实际游戏、购买、广告或发布已测试成功。API/SDK/CLI 操作归项目侧资料。参阅[23 项用途](professional-skills.md#310-新增的二十三个-skill)及[逐项溯源](../../skills/README.md#game-family-provenance-310)；引擎与政策日期快照必须复核当前政策。

## 如何阅读一项能力

每项新能力都属于下面四类之一。这几个标签不能互相替换。

| 标签 | 含义 | 不代表什么 |
| --- | --- | --- |
| **方法** | 一份 `SKILL.md`，告诉工作者如何判断、检查和报告。 | 它自己不执行任何东西，加载它也不是测试结果。 |
| **已实现的本地工具** | 本包确实随附、且本修订的脚本能够运行的命令，例如对比度、缩图、图像头、字幕、合成时间线与探测结果比较脚本。 | 不代表浏览器、数据库、编码器或模型运行过。 |
| **离线验证** | 不需要网络、也不需要提供方账号的检查。包结构校验属于这一类。 | 通过一项不能衡量生成的图片、音频或视频。 |
| **真实在线，未验证** | 一次需要密钥、网络，以及明确批准提供方、预算和上传范围的提供方调用。 | 本版本没有做过任何这样的调用。配置存在不是一次成功的生成。 |

一个方法可以在交付并审查之后，其执行仍然未经验证。文档会标明是哪一种。它从不把生成结果报告为已测试，也从不把示例提供方当成用户已经选定的提供方。

## 原有的十六个

这些仍是交付的核心方法。用途不变；逐个说明和完整性规则见[专业 Skill](professional-skills.md)。

`codebase-reconnaissance`、`technical-research`、`product-discovery`、`product-design`、`requirements-analysis`、`solution-architecture`、`api-design`、`database-design`、`implementation-planning`、`test-driven-development`、`systematic-debugging`、`code-review`、`security-review`、`performance-review`、`integration-verification`、`merge-conflict-resolution`。

它们是包内维护的改编版。上游基线与来源记录仍在 `skills/README.md`。

## 软件方法

八个 Skill。都不声明提供方密钥，只需要方法的任务不必新增凭据。其中三个在 2.4.0 中获得本地工具或工具衔接，其余五个仍为方法。

| Skill | 补充什么 | 不替代什么 | 执行状态 |
| --- | --- | --- | --- |
| `frontend-visual-design` | 页面或组件的排版、色彩和视觉层级，含错误态、键盘路径和 200% 缩放；2.4.0 新增 `scripts/contrast-ratio.mjs`，本地计算 WCAG 2.2 对比度。 | `product-design` 负责流程和交互状态，`design-system` 负责跨屏 token。 | 方法及本地工具。实际页面检查仍需要项目运行时和浏览器，本版本未检查用户页面。 |
| `browser-e2e` | 浏览器选择器、trace 和夹具，以及静态页面上的本地旅程示例。 | 通用验收方法 `integration-verification`。 | 方法及本地脚本。示例经调用者的 Python Playwright 启动已安装的 Chromium；缺少 Python、Playwright 或 Chromium 时返回具名依赖错误，对应可选测试跳过。跳过不是覆盖，不会自行安装浏览器。 |
| `accessibility-audit` | 焦点、标签、错误关联及通过 `frontend-visual-design` 脚本测量的对比度证据。 | 在设计期提出要求的 `product-design`。 | 方法。自动扫描不是 WCAG 符合性声明。 |
| `postgres-practices` | PostgreSQL 专项规则：索引、`EXPLAIN`、行级安全。 | `database-design`，它仍是通用建模和迁移方法。 | 方法。测量需要独立的测试数据库。方法不涉及共享库或生产库。 |
| `observability` | 先确定要回答的运行问题，再布置指标、日志和追踪。 | `systematic-debugging`，它从缺陷出发，而不是从仪表化设计出发。 | 方法。供应商中立；没有选定遥测供应商。 |
| `ci-pipeline` | 按项目真实拥有的检查来组织质量门。 | 临时拼凑的 CI 模板。本 Skill 不附带流水线。 | 方法。本地模拟和远端流水线运行是不同的证据，必须分开标注。 |
| `react-performance` | React 和 Next.js 的请求瀑布与包体积规则，仅在任务是 React 时使用。 | `performance-review`，它仍是通用测量方法。 | 方法，以任务中的 React 版本为条件。验收要有前后测量；一份意见清单不是验收。 |
| `react-composition` | 组件组合、状态共享和布尔属性膨胀。 | 为了重构而重构。 | 方法。仅 React 19 适用的建议，只在任务写明 React 19 时生效。 |

这些不是新角色。实施者、架构师、审查者或验证者按需加载对应 Skill。一个 Skill 不对应一个角色。

## 工程方法

2.4.0 新增八个 Skill：七个是方法（部分有离线示例检查），一个附带本地转换器。它们不调用服务，均为引用公开规范的原创方法，不复制上游 Skill 文本。

| Skill | 判断什么 | 可核对的实例 | 限制 |
| --- | --- | --- | --- |
| `skill-authoring-evaluation` | 描述是否正确触发、明确反例并提供可观察结果。 | 对照 `database-design` 为弱描述与强描述评分。 | 只评估文本，不是智能体实验。 |
| `design-system` | 跨屏原始、语义、组件 token 及组件契约。 | 示例声明 CSS 自定义属性，并在正文中写明 muted-on-surface 对比度为 `4.48:1`。同一数值可由 `frontend-visual-design` 的 `contrast-ratio.mjs` 命令得到。 | 工具中立，不替代单屏视觉规范。 |
| `domain-modeling` | 实体、值对象、聚合及不变量归属。 | 拒绝允许两个住宿记录写入同一房晚的模型。 | 到持久化之前止步，schema 与迁移归 `database-design`。 |
| `migration-upgrade` | 依赖、框架或 API 的扩展、双路径运行、切换和收缩顺序。 | 用 `Accept-Version` 探测，分四次部署把 HTTP 字段移入 `data`。 | 不重复 schema 回填方案。 |
| `mcp-server-development` | 工具名、schema、错误通道与传输。 | 固定协议修订 `2025-11-25`，展示有效 `tools/call`、未知工具的 `-32602` 协议错误及超范围值的工具错误。 | 不附服务器脚手架，测试只检查夹具，不启动服务器。 |
| `technical-diagrams` | SVG/Mermaid 中的真实文字、字号、对比度 token 和描述。 | 时序图与 `examples/version-header.svg` 的源码语义检查。 | 源码检查不是渲染，不声称屏幕效果已验证。 |
| `localization` | 术语表、ICU 占位符、文本膨胀与从右到左布局。 | 将拼接计数改为一条 ICU `plural` 消息，各语言保留相同占位符。 | 处理源文案，不调用翻译服务，不编造翻译。 |

`subtitle-production` 在[音频、视频与文档方法](#音频视频与文档方法)中列出，以便清单对每个后续 Skill 只计数一次。

具体命令和输出见[教程](professional-capability-tutorial.md#6-运行-240-本地工具)。

## 本地资产方法

四个 Skill，加上 `media-producer` 角色。它们产出网站要保留的文件：图标、Logo、favicon、manifest 和压缩图片。它们不把这些文件发布到任何地方。

| Skill | 产出 | 依赖 | 限制 |
| --- | --- | --- | --- |
| `icon-assets` | 选定的图标，并按图标集记录来源和许可。 | 本地工具需要 Node。查询公开的 Iconify 索引需要网络，不需要密钥。 | 不是离线。每个图标集保留自己的许可。 |
| `svg-logo-design` | 一个 SVG Logo 和一次导出检查。 | 只用本地 SVG 工具。 | 是方法和导出。没有选定托管的 Logo 服务。 |
| `web-assets` | 来自本地母版的 favicon、web manifest 和社交图片尺寸。 | Node 生成 manifest，`png-resize.mjs` 从审阅过的母版导出较小 PNG。 | 不生成画作；512px 母版直接作为 512 条目，不能缩到自身大小。SVG 栅格化需要本包不附带的外部工具。 |
| `image-compression` | 压缩图片、实测压缩比与保留的透明度，以及从母版导出的较小 PNG。 | Node；`png-compressor.mjs` 无损压缩，`png-resize.mjs` 缩小 8-bit 非隔行 RGB/RGBA PNG。 | 不保证压缩比，非缩小请求失败；RGB `tRNS` 色键先展开为 alpha 再平均，其他不支持的辅助块按名拒绝而非丢弃。 |

`icon-assets` 是资产 Skill 里默认在线的一个。其余三个是本地的。四个都不是付费 API。压缩与缩图已在生成的离线夹具上检查结构及解码像素，不代表视觉质量；[资产验收行](professional-capability-tutorial.md#资产验收)仍须逐项记录实际输出及未运行项。

## 图像方法

四个 Skill。规划一张图和生成一张图是两个步骤。规划是方法，不需要密钥。生成是真实的在线调用，**尚未验证**。

| Skill | 规划什么 | 仅在何时生成 |
| --- | --- | --- |
| `image-generation` | 一个后端的提示词、宽高比和验收，以及读取 PNG/JPEG/WebP 头的 `scripts/image-info.mjs`。 | 用户批准提供方、预算和上传内容后才生成；本地图像头检查不解码像素。 |
| `infographic-design` | 版式、阅读顺序，以及图片必须承载的结论。 | 使用同一个已批准的后端。 |
| `editorial-illustration` | 封面和文章配图的方向。 | 使用同一个后端。 |
| `visual-slide-deck` | 以图片呈现的幻灯片序列。 | 使用同一个后端。结果是图片型 deck，不是可编辑的 Office 文档。 |

最多接入一个图像后端。本包不预先在 OpenAI、Google、OpenRouter 或任何其他供应商之间做选择，下文把某一个当作示例也不是选择。安装本包并不授权任何图像调用。

## 音频、视频与文档方法

七个 Skill。本地渲染和在线生成始终分开，即使同一件交付物两种都能做。

| Skill | 是什么 | 本地还是在线 | 状态 |
| --- | --- | --- | --- |
| `code-video-production` | 以帧规划的代码视频，渲染前由 `scripts/composition-check.mjs` 检查时间线。 | 本地渲染；联网素材与语音另行批准。 | 方法及本地检查。优先 HyperFrames，检查只读 HTML 并输出帧映射，不渲染；本版本未运行 HyperFrames 渲染。 |
| `generated-video` | 向在线视频提供方请求的视频。 | 在线。需要密钥、网络和已批准的预算。 | 真实在线，未验证。Pexo 是示例连接器，不是选定的供应商。OpenMontage 不包含在内；见许可证。 |
| `speech-production` | 对一段指定文本做语音合成。 | 在线。 | 真实在线，未验证。ElevenLabs 是示例连接器，不是选定的供应商。 |
| `audio-transcription` | 对一段给定录音做转录和时间戳。 | 在线。 | 真实在线，未验证。同一个示例连接器，同样不是选择。 |
| `media-transcoding` | 本地 FFmpeg 剪切、重封装或转码，并用 `scripts/probe-compare.mjs` 比较探测结果。 | 执行主机上的 `ffmpeg` 与 `ffprobe`。 | 方法及本地检查。比较器只读调用者保存的 ffprobe JSON，不运行 ffprobe。构建与编码器许可另行核查。 |
| `document-production` | 从有界块生成可编辑文档、幻灯片、表格和 PDF，使用许可允许的库。 | 按格式选择本地库。 | 方法及本地脚本；不复制 Anthropic docx、pptx、pdf 或 xlsx Skill。 |
| `subtitle-production` | 带时间校验的 SRT/WebVTT 转换。 | 仅 Node。 | 本地工具；只有文本，不支持样式、定位或烧录。 |

`media-producer` 承载资产、图像、音视频和字幕 Skill。`document-specialist` 承载文档制作和图片型幻灯片。两个角色都不得在没有明确批准该任务的提供方、预算和上传范围时上传、发布或发起付费调用。

## 2.3.0 新增的四个角色

合计十六个角色：原有十二个，加上这四个。角色是身份和边界。它不提升权限，也不加载该领域的全部 Skill。

| 角色 | 类别 | 何时使用 | 默认 Skill | 可选 Skill | 绝不 |
| --- | --- | --- | --- | --- | --- |
| `ui-designer` | product | 页面或组件需要视觉规范、状态矩阵或设计评审。 | `product-design`、`frontend-visual-design` | `accessibility-audit`、`icon-assets`、`design-system`、`localization` | 不收集需求，不实现产品 UI，只在任务授权路径写原型。 |
| `browser-test-engineer` | quality | 任务需要浏览器回归证据、可访问性审计，或缺陷的 trace。 | `browser-e2e`、`integration-verification` | `accessibility-audit`、`systematic-debugging` | 不实现被测产品，也不替代 `release-verifier`。实现某页面的人不同时验收该页面。 |
| `media-producer` | media | 图标、Logo、网站资产、插图、分镜、字幕或音视频母版，附来源和许可清单。 | 默认没有，任务选一到三个。 | 相关资产、图像、音视频、`subtitle-production` 与 `technical-diagrams`。 | 未经明确批准不上传、发布或花钱，不改产品源码。 |
| `document-specialist` | product | 任务产出可编辑的文档、幻灯片、电子表格或 PDF，并检查它能往返打开。 | `document-production` | `visual-slide-deck`、`editorial-illustration` | 不把图片型 deck 说成可编辑对象，也不复制专有的文档 Skill。 |

其余十二个角色的身份不变。架构师按需加载 `domain-modeling`、`migration-upgrade`、`mcp-server-development`、`technical-diagrams`；实施者按需加载 `migration-upgrade`、`mcp-server-development`、`localization`、`skill-authoring-evaluation`。React、PostgreSQL、可观测性与 CI 仍不新增角色。可选 Skill 的权威是安装版本的 `roles/catalog.json`。

模型路由、交付物路由和风险路由是 `routing/` 里的包数据。本指南不复制它们，因为复制的表会在包一变时就过时。

## 六组增强

| 组 | 实质改动 | 边界 |
| --- | --- | --- |
| 前端与产品 | 共享 token、实测对比度，以及写明 token 引用、状态矩阵、文案和可观察验收的设计交接。 | 一个对比度数字不能验收整个页面。 |
| 浏览器与无障碍 | 两条键盘旅程、植入缺陷检测，以及焦点、标签、错误、对比度和缩放审计表。 | 只覆盖本地示例，不是 WCAG 认证或用户应用测试。 |
| 文档 | 标题、段落、有序列表及 Markdown/DOCX/XLSX 真实表格，保留原有 title/bullets 用法。 | PPTX/PDF 拒绝表格，不支持合并单元格、图表、宏或任意模板。 |
| 图标与网站资产 | 按尺寸记录母版、导出和许可，有界 PNG 缩图生成 manifest 中较小尺寸。 | 16/32 使用简化小图标母版，180/192 使用大母版，512 条目直接复制审阅过的 512 母版。 |
| 图像 | PNG/JPEG/WebP 头检查、信息图数值与图形匹配、插图对象来源记录、幻灯片可读性阈值。 | 1920px 宽幻灯片正文至少 28px、对比度 4.5:1；头检查不能验证标签、真实性或视觉可读性。 |
| 代码视频与转码 | 合成帧映射与已保存 ffprobe JSON 比较。 | 两条命令都不渲染或转码，这些操作需要另有本地工具。 |

## 说法与证据

| 本版本中的说法 | 你可以核验的证据 | 本版本没有的证据 |
| --- | --- | --- |
| 本包离线验证自身结构。 | 在你安装的修订上，`scripts/verify-package.ps1` 以 0 退出且 `FAIL=0`。 | 套件通过并不能说明生成的图片、视频或文档。 |
| 方法以 Skill 文件交付。 | Skill 文件存在于 `skills/<id>/SKILL.md`，目录解析到它。 | 加载一个 Skill 不是对其产出的测试。 |
| 本地工具离线运行。 | 教程运行对比度、PNG 缩图、图像头、字幕、帧映射、探测比较、PNG 压缩、manifest、Markdown、依赖检查和提供方夹具。 | 帧映射不是视频，探测比较不是转码，头检查不是解码，夹具不证明提供方质量。 |
| Office/PDF 块能往返打开。 | 程序重开 docx、xlsx、pptx、pdf 并比较文本。 | 未检查视觉布局、表格溢出、字体替换和 PDF 分页；PPTX/PDF 拒绝 table 块。 |
| 在线连接器以示例存在。 | 教程把 OpenAI 作为图像示例、Pexo 作为视频示例、ElevenLabs 作为语音和转录示例。 | 没有发起调用。没有选定提供方。没有测量生成质量。 |

内容审查曾在 Windows 本地运行 Chromium 两条旅程（Python 3.14.6、Chromium revision 1234），并用 FFmpeg 8.1 生成合成媒体、探测及解码到空输出。这些是有界本地结果，不代表跨平台验证。HyperFrames 渲染、Office/PDF 视觉审查、真实提供方调用仍未验证，图像头检查也不证明完整解码和视觉质量。

## 许可证与来源

`skills/README.md` 按 Skill 记录原有十六个的固定上游与 MIT 声明，以及后续原创方法的公开参考；引用不意味着复制上游 Skill 文本。

- **本项目保留自己的 MIT 许可证**，位于仓库根目录。MIT 覆盖本项目的原创文本：协调者 Skill、脚本、路由和公开文档。
- **第三方材料保留它带来的许可证。** 一个 Apache-2.0 的 Skill 仍是 Apache-2.0，声明原样保留在旁边。项目的 MIT 许可证不把它重新许可。
- **原有的十六个**是 [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills) 在提交 `d9a174c7143bfb4c76ed042f457fb7785c35cea3` 上的包内维护 MIT 改编版，并在本包内做了补充。它们的上游 MIT 声明留在 `skills/LICENSE`。
- **2.3.0 与 2.4.0 的三十个均为原创方法。** 2.3.0 的二十二个和 2.4.0 的八个均在本项目编写，引用 WCAG 2.2、PNG、WebVTT、MCP、PostgreSQL、OpenTelemetry、React 等公开资料，不复制上游 Skill 文本。没有 Skill 目录附带 `LICENSE.txt`，来源表标记为 `Original`。3.1.0 新增的 23 个游戏方法也采用原创文字，固定提交的方法集合引用与带日期的官方引擎/平台来源单列于游戏族溯源表。
- **有两个上游有意不复制。** Anthropic 的 docx、pptx、pdf 和 xlsx Skill 是专有的，不包含在内；`document-production` 针对许可允许的库独立编写。OpenMontage 是 AGPL-3.0，不包含在内；`media-transcoding` 依据 FFmpeg 自身文档编写，所装 FFmpeg 构建及其编码器的许可另行核查。
- **资产自带许可。** 图标集、字体和素材图片不由获取它们的工具的许可覆盖。`icon-assets` 要求每个图标集都有来源和许可。

公开参考提供技术事实，原创方法不导入其他产品的编排指令。

## 相关

- [安装](installation.md)：离线包检查。
- [专业能力教程](professional-capability-tutorial.md)：本地工具与依赖辅助脚本走读。
- [扩展](extending.md)：计数所依据的注册规则。
- [专业 Skill](professional-skills.md)：完整清单。
