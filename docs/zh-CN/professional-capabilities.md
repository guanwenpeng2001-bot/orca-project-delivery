# 专业能力

[English](../professional-capabilities.md) | **简体中文**

2.3.0 为软件交付、本地视觉资产、图像规划，以及音频、视频和文档制作补充专业方法。加上原有的十六个，本包共有 **38 个专业 Skill** 和 **16 个角色**。本指南说明每项新能力做什么、不做什么，以及它的说法实际核到了哪一步。

计数、目录注册和可执行的依赖面属于并行的能力包。在该包落地之前，把下面的 ID 当作已批准的能力合同，并在你安装的那个修订里读取 `routing/skill-catalog.json`、`roles/catalog.json` 和 `PACKAGE-MANIFEST.json` 来确认注册。本指南里的一句话不能当作文件存在的证明。

## 如何阅读一项能力

每项新能力都属于下面四类之一。这几个标签不能互相替换。

| 标签 | 含义 | 不代表什么 |
| --- | --- | --- |
| **方法** | 一份 `SKILL.md`，告诉工作者如何判断、检查和报告。 | 它自己不执行任何东西，加载它也不是测试结果。 |
| **已实现的本地工具** | 本包确实随附、且本修订的脚本能够运行的命令，例如现有的依赖辅助脚本。 | 不代表浏览器、数据库、编码器或模型运行过。 |
| **离线验证** | 不需要网络、也不需要提供方账号的检查。包结构校验属于这一类。 | 通过一项不能衡量生成的图片、音频或视频。 |
| **真实在线，未验证** | 一次需要密钥、网络，以及明确批准提供方、预算和上传范围的提供方调用。 | 本版本没有做过任何这样的调用。配置存在不是一次成功的生成。 |

一个方法可以在交付并审查之后，其执行仍然未经验证。文档会标明是哪一种。它从不把生成结果报告为已测试，也从不把示例提供方当成用户已经选定的提供方。

## 原有的十六个

这些仍是交付的核心方法。用途不变；逐个说明和完整性规则见[专业 Skill](professional-skills.md)。

`codebase-reconnaissance`、`technical-research`、`product-discovery`、`product-design`、`requirements-analysis`、`solution-architecture`、`api-design`、`database-design`、`implementation-planning`、`test-driven-development`、`systematic-debugging`、`code-review`、`security-review`、`performance-review`、`integration-verification`、`merge-conflict-resolution`。

它们是包内维护的改编版。上游基线和当前内容哈希仍在 `skills/README.md`。

## 软件方法

八个 Skill。都不声明提供方密钥。只需要方法的任务不必新增凭据。

| Skill | 补充什么 | 不替代什么 | 执行状态 |
| --- | --- | --- | --- |
| `frontend-visual-design` | 页面或组件的排版、色彩和视觉层级，并检查层级、错误态、键盘路径和 200% 缩放。 | `product-design`，它仍负责流程、信息架构和交互状态。 | 方法。页面检查需要项目自身的运行时和浏览器；本版本没有做过该检查。 |
| `browser-e2e` | 浏览器回归的选择器策略、trace 取证和夹具处理。 | `integration-verification`，它仍是通用验收方法。 | 方法。执行期望项目已有的 Node 和 Playwright。不新增 Python 辅助脚本。这里不声称做过浏览器运行。 |
| `accessibility-audit` | 把可访问性要求变成证据：焦点顺序、标签、错误关联、对比度。 | `product-design`，它在设计期提出要求。 | 方法。自动扫描不是 WCAG 符合性声明。 |
| `postgres-practices` | PostgreSQL 专项规则：索引、`EXPLAIN`、行级安全。 | `database-design`，它仍是通用建模和迁移方法。 | 方法。测量需要独立的测试数据库。方法不涉及共享库或生产库。 |
| `observability` | 先确定要回答的运行问题，再布置指标、日志和追踪。 | `systematic-debugging`，它从缺陷出发，而不是从仪表化设计出发。 | 方法。供应商中立；没有选定遥测供应商。 |
| `ci-pipeline` | 按项目真实拥有的检查来组织质量门。 | 临时拼凑的 CI 模板。本 Skill 不附带流水线。 | 方法。本地模拟和远端流水线运行是不同的证据，必须分开标注。 |
| `react-performance` | React 和 Next.js 的请求瀑布与包体积规则，仅在任务是 React 时使用。 | `performance-review`，它仍是通用测量方法。 | 方法，以任务中的 React 版本为条件。验收要有前后测量；一份意见清单不是验收。 |
| `react-composition` | 组件组合、状态共享和布尔属性膨胀。 | 为了重构而重构。 | 方法。仅 React 19 适用的建议，只在任务写明 React 19 时生效。 |

这些不是新角色。实施者、架构师、审查者或验证者按需加载对应 Skill。一个 Skill 不对应一个角色。

## 本地资产方法

四个 Skill，加上 `media-producer` 角色。它们产出网站要保留的文件：图标、Logo、favicon、manifest 和压缩图片。它们不把这些文件发布到任何地方。

| Skill | 产出 | 依赖 | 限制 |
| --- | --- | --- | --- |
| `icon-assets` | 选定的图标，并按图标集记录来源和许可。 | 本地工具需要 Node。查询公开的 Iconify 索引需要网络，不需要密钥。 | 不是离线。每个图标集保留自己的许可。 |
| `svg-logo-design` | 一个 SVG Logo 和一次导出检查。 | 只用本地 SVG 工具。 | 是方法和导出。没有选定托管的 Logo 服务。 |
| `web-assets` | 从本地母版生成的 favicon、web manifest 和社交图片尺寸。 | 项目环境中的 Python 与 Pillow。 | 只有位图尺寸。它不生成画作。 |
| `image-compression` | 压缩后的图片、实测压缩比，并保留透明度。 | 本地编码器，例如 `cwebp` 或 ImageMagick，由实现选定，不由本指南选定。 | 不保证任何压缩比。在 Windows 上失败就是失败，不是跳过。 |

`icon-assets` 是资产 Skill 里默认在线的一个。其余三个是本地的。四个都不是付费 API，本版本也都没有测得的产出：教程里的验收行是要去跑的检查，不是已经通过的检查。

## 图像方法

四个 Skill。规划一张图和生成一张图是两个步骤。规划是方法，不需要密钥。生成是真实的在线调用，**尚未验证**。

| Skill | 规划什么 | 仅在何时生成 |
| --- | --- | --- |
| `image-generation` | 针对一个选定后端的提示词、宽高比和验收检查。 | 用户已批准一个提供方、一笔预算，以及允许上传的内容。 |
| `infographic-design` | 版式、阅读顺序，以及图片必须承载的结论。 | 使用同一个已批准的后端。 |
| `editorial-illustration` | 封面和文章配图的方向。 | 使用同一个后端。 |
| `visual-slide-deck` | 以图片呈现的幻灯片序列。 | 使用同一个后端。结果是图片型 deck，不是可编辑的 Office 文档。 |

最多接入一个图像后端。本包不预先在 OpenAI、Google、OpenRouter 或任何其他供应商之间做选择，下文把某一个当作示例也不是选择。安装本包并不授权任何图像调用。

## 音频、视频与文档方法

六个 Skill。本地渲染和在线生成始终分开，即使同一件交付物两种都能做。

| Skill | 是什么 | 本地还是在线 | 状态 |
| --- | --- | --- | --- |
| `code-video-production` | 以帧来规划、在本地渲染的代码讲解视频。 | 本地渲染。可选的联网素材或语音是单独批准的步骤。 | 方法。优先的编写方法是 HyperFrames。Remotion 和 video-shotcraft 是未入选的备选。本版本没有跑过渲染。 |
| `generated-video` | 向在线视频提供方请求的视频。 | 在线。需要密钥、网络和已批准的预算。 | 真实在线，未验证。Pexo 是示例连接器，不是选定的供应商。OpenMontage 不包含在内；见许可证。 |
| `speech-production` | 对一段指定文本做语音合成。 | 在线。 | 真实在线，未验证。ElevenLabs 是示例连接器，不是选定的供应商。 |
| `audio-transcription` | 对一段给定录音做转录和时间戳。 | 在线。 | 真实在线，未验证。同一个示例连接器，同样不是选择。 |
| `media-transcoding` | 用本地 FFmpeg 做剪切、重封装或转码。 | 本地。执行主机上的 `ffmpeg` 和 `ffprobe`。 | 方法。所装 FFmpeg 的编码器与构建许可另行核查。本版本没有跑过转码。 |
| `document-production` | 可编辑的文档、幻灯片、电子表格和 PDF，基于许可允许的库编写。 | 本地库，按格式选择。 | 方法。这不是 Anthropic docx、pptx、pdf 或 xlsx Skill 的副本；那些不包含在内。 |

`media-producer` 承载资产、图像和音视频 Skill。`document-specialist` 承载文档制作和图片型幻灯片。两个角色都不得在没有明确批准该任务的提供方、预算和上传范围时上传、发布或发起付费调用。

## 四个新角色

合计十六个角色：原有十二个，加上这四个。角色是身份和边界。它不提升权限，也不加载该领域的全部 Skill。

| 角色 | 类别 | 何时使用 | 默认 Skill | 可选 Skill | 绝不 |
| --- | --- | --- | --- | --- | --- |
| `ui-designer` | product | 页面或组件需要视觉规范、组件状态矩阵或设计评审。 | `product-design`、`frontend-visual-design` | `accessibility-audit`，以及 `icon-assets` 注册之后。 | 不收集需求，不实现产品 UI。只在任务点名的路径上写原型代码。 |
| `browser-test-engineer` | quality | 任务需要浏览器回归证据、可访问性审计，或缺陷的 trace。 | `browser-e2e`、`integration-verification` | `accessibility-audit`、`systematic-debugging` | 不实现被测产品，也不替代 `release-verifier`。实现某页面的人不同时验收该页面。 |
| `media-producer` | media | 任务产出图标、Logo、网站资产、插图、分镜或音视频母版，并附来源与许可清单。 | 默认没有；任务选一到三个。 | 与该任务相关的资产、图像和音视频 Skill。 | 未经明确批准不上传、不发布、不花钱。不修改产品源码。 |
| `document-specialist` | product | 任务产出可编辑的文档、幻灯片、电子表格或 PDF，并检查它能往返打开。 | `document-production` | `visual-slide-deck` | 不把图片型 deck 说成可编辑对象，也不复制专有的文档 Skill。 |

其余十二个角色不变。React、PostgreSQL、可观测性和 CI 不单设角色；它们是 Skill，由需要它们的实施者、架构师、审查者或验证者加载。

模型路由、交付物路由和风险路由是 `routing/` 里的包数据。本指南不复制它们，因为复制的表会在包一变时就过时。

## 说法与证据

| 本版本中的说法 | 你可以核验的证据 | 本版本没有的证据 |
| --- | --- | --- |
| 本包离线验证自身结构。 | 在你安装的修订上，`scripts/verify-package.ps1` 以 0 退出且 `FAIL=0`。 | 套件通过并不能说明生成的图片、视频或文档。 |
| 方法以 Skill 文件交付。 | Skill 文件存在于 `skills/<id>/SKILL.md`，且哈希与 `skills/README.md` 一致。 | 加载一个 Skill 不是对其产出的测试。 |
| 依赖辅助脚本在本地运行。 | 教程的离线走读使用 `check-requirements.ps1` 和 `invoke-with-requirements.ps1`，用假值、不联网。 | 在能力包定义之前，这里不断言它们针对新 Skill 的参数。 |
| 在线连接器以示例存在。 | 教程把 OpenAI 作为图像示例、Pexo 作为视频示例、ElevenLabs 作为语音和转录示例。 | 没有发起调用。没有选定提供方。没有测量生成质量。 |

## 许可证与来源

出处按 Skill 记录，不是一个笼统的上游。权威表是能力包里的 `skills/README.md`：每个 Skill 一行，写明上游仓库、固定提交、许可证，以及复制进包内的许可证文件。本指南说明这些行必须满足的规则。

- **本项目保留自己的 MIT 许可证**，位于仓库根目录。MIT 覆盖本项目的原创文本：协调者 Skill、脚本、路由和公开文档。
- **第三方材料保留它带来的许可证。** 一个 Apache-2.0 的 Skill 仍是 Apache-2.0，声明原样保留在旁边。项目的 MIT 许可证不把它重新许可。
- **原有的十六个**是 [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills) 在提交 `d9a174c7143bfb4c76ed042f457fb7785c35cea3` 上的包内维护 MIT 改编版，并在本包内做了补充。它们的上游 MIT 声明留在 `skills/LICENSE`。当前哈希跟踪改编后的文本，不是逐字节一致的上游副本。
- **新增的改编**各自携带自己的 `LICENSE.txt` 和固定的上游提交。软件方法改编的上游包括 Anthropic frontend-design（Apache-2.0）、ECC e2e-testing（MIT）、wshobson 可访问性模式（MIT）、Supabase PostgreSQL 实践（MIT），以及 Addy Osmani 的可观测性与 CI 方法（MIT）。资产和图像方法改编 MIT 许可的上游。固定提交写在 `skills/README.md`，不写在这里，以免本指南与导入事实漂移。
- **有两个上游有意不复制。** Anthropic 的 docx、pptx、pdf 和 xlsx Skill 是专有的，不包含在内；`document-production` 针对许可允许的库独立编写。OpenMontage 是 AGPL-3.0，不包含在内；`media-transcoding` 依据 FFmpeg 自身文档编写，所装 FFmpeg 构建及其编码器的许可另行核查。
- **React 方法是有条件的。** Vercel 的 react-best-practices 和 composition-patterns 上游声明 MIT，但研究时没有根目录 `LICENSE` 文本。只有当能力包在某个固定提交记录了授权文本时才纳入，否则改为不复制上游文字的独立编写。在该记录存在之前，不要把它们描述为已清除。
- **资产自带许可。** 图标集、字体和素材图片不由获取它们的工具的许可覆盖。`icon-assets` 要求每个图标集都有来源和许可。

新增 Skill 不复制会启动另一种智能体产品的上游指令。改编保留方法，去掉那一部分。

## 相关

- [安装](installation.md)：离线包检查。
- [专业能力教程](professional-capability-tutorial.md)：一次只用依赖辅助脚本的走读。
- [扩展](extending.md)：计数所依据的注册规则。
- [专业 Skill](professional-skills.md)：原有的十六个。
