---
name: game-publishing
description: Assess game release readiness across stores, mini-game platforms, and self-hosted web distribution with dated policy checks. Use when selecting a release surface or preparing any game content update for publication.
---

# Game Publishing

## 1. When to use / When not to use

Use to select distribution surfaces, prepare a first submission, or re-check a content update. Do not use a successful upload as proof of publication, a historical policy snapshot as current legal advice, or this method as authorization to submit or publish. Engine build mechanics belong to engine-* skills; storefront operations belong to project-side official platform tools.

## 2. Novice orientation

Publishing makes a particular game version available to an intended audience. The console is the platform's management site; qualifications establish eligibility; materials are listing text and media; a package is the playable artifact. Submission asks for review, approval permits a next step, and publication makes the release available. These states are different.

For the first session:

1. Write down audience, countries/regions, platform surface, engine, and monetization (ads, purchases, both, or explicitly none).
2. Choose the matching profile below. Identify the account owner and the exact app/project; leave unknown identifiers unset rather than guessing.
3. Create a small checklist with item, applicability, decision, owner, source/date, and observed result. First fill account access, qualifications, listing materials, and build availability.
4. Open the current official requirement pages through the project's platform guidance. Record missing information as a blocker and assign its next check.
5. Test the candidate on one target device, then schedule the remaining release checks with game-testing-ladders. Stop at a readiness assessment until publication is authorized.

A checklist item explicitly set to `none` records a decision with a reason (for example, no paid products). An unset item records a missing decision. **Unset is not none:** the former must produce an unresolved/blocking result; the latter can be accepted only if applicability and rationale support it.

## 3. Core method

### Release gates and decisions

Track the generic sequence **account ready → qualifications green → materials green → package bound → submitted → published**. Store materials and playable-build checks can progress in parallel, but both must be green before submission readiness. Bind the exact tested package identity, version, audience, and listing. Replacing any of them reopens the affected checks. Observe platform acceptance and public availability separately; a submission receipt proves neither.

Compliance gates **re-open on every content update**. Re-run the China checklist where applicable, data/privacy declarations, rights, monetization, and platform requirements per release, including remote content changes. This is an internal readiness rule; it does not assert that every platform mandates a new formal review for every update.

For each decision record the current source, applicable region/account type, owner, and result. Unknown or unavailable policy that affects this release blocks a green verdict until resolved. An explicit non-applicable decision needs rationale. Do not replace computed platform qualification requirements with a blanket list of all possible certificates.

### Reading the platform profiles

`verified-2026-10-23` preserves the supplied reconnaissance's dated observation; it is not a fresh live check by this skill. `verify-current-policy` requires a release-time check. `unavailable` means the scout could not establish the fact. Unlabeled artifact descriptions are planning inputs to confirm against the actual target, not promises of platform acceptance. Automation entries below are reference pointers only, not executable procedures.

### WeChat mini-game

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | `mp.weixin.qq.com`; verified account/app identity described by the [CI documentation](https://developers.weixin.qq.com/miniprogram/dev/devtools/ci.html), `verified-2026-10-23`. |
| Build form | Mini-game code package from the project and WeChat toolchain; confirm the mini-game app binding. |
| Automation | [miniprogram-ci](https://developers.weixin.qq.com/miniprogram/dev/devtools/ci.html), official compile/upload/preview support with upload-key and IP-allowlist prerequisites, `verified-2026-10-23`. A public one-command production-release API is `unavailable`; upload does not establish publication. |
| Compliance gates | ISBN applicability, filing, privacy, real-name/anti-addiction: `verify-current-policy`, using the China matrix and current console qualification cards. No current IAA exemption list is established. |
| Material-spec source | [Mini-game materials](https://developers.weixin.qq.com/minigame/product/material.html), `unavailable` (404 in the scout). Re-fetch or use the current console material requirements. |
| Monetization | Ads and virtual payment eligibility/fees: `verify-current-policy`; consult current WeChat platform guidance. The [IAA introduction](https://developers.weixin.qq.com/minigame/introduction/iaa) was unavailable. |

### Douyin mini-game

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | `developer.open-douyin.com`, mini-game console; `verified-2026-10-23` via the [developer-tools page](https://partner.open-douyin.com/docs/resource/zh-CN/mini-game/develop/dev-tools/development-assistance/ide-cli). |
| Build form | Project directory/package matched to the engine and mini-game toolchain; distinguish older/newer Unity package formats. |
| Automation | [tt-minigame-ide-cli / tmg](https://partner.open-douyin.com/docs/resource/zh-CN/mini-game/develop/dev-tools/development-assistance/ide-cli), `verified-2026-10-23`; upload/preview does not submit for review. Do not substitute the separate mini-app tool. |
| Compliance gates | [Game information audit](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/operation1/norms/game-info-audit): copyright/game-name match, ISBN name match, operator identity or authorization, and third-party IP authorization when used, `verified-2026-10-23`. Forced authorization, plaintext transmission and unmasked PII are prohibited; location collection requires consent, same dated source. ISBN exemptions, privacy and real-name specifics remain `verify-current-policy`; see also [review norms](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/operation1/norms/standard). |
| Material-spec source | Same audit page: filing description 120–300 Chinese characters, `verified-2026-10-23`; full image-size requirements in the current mini-game information page are `verify-current-policy`. |
| Monetization | Ads and platform payments: `verify-current-policy` for eligibility and terms. |

### TapTap store

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | [Developer console](https://developer.taptap.cn), `verified-2026-10-23` in the scout's local CLI/setup evidence. |
| Build form | Appropriate signed APK/RPK/H5/mini-game package in the package library; select the actual distribution surface. |
| Automation | Official taptap-cli, locally observed version 2026.10.21, `verified-2026-10-23`; consult its project-installed official skills and [developer documentation](https://developer.taptap.cn/docs/store/release/publish/). The web publish page itself was `unavailable` (403); CLI evidence is local, not evidence that this URL rendered. |
| Compliance gates | Computed required qualifications, not all eight possible slots indiscriminately: `verified-2026-10-23` from local official qualification skill inspection. Current applicability of copyright, ISBN, filing, privacy, AI and IP slots is `verify-current-policy`. |
| Material-spec source | [Official materials v4](https://developer.taptap.cn/docs/store/release/publish/material/), `verified-2026-10-23`. Use the live table rather than copying pixel specifications. |
| Monetization | TapTap payment and applicable ad/settlement arrangements: `verify-current-policy` for the chosen surface and financial entity. Do not assume Maker ad support applies to every store build. |

### TapTap Maker / Creative Workshop

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | [Maker console](https://maker.taptap.cn), `verified-2026-10-23` from local setup evidence; distinguish its project from a store app. |
| Build form | Maker project remotely built through its connected MCP; hosted Workshop H5 is not a locally distributable binary. |
| Automation | Maker MCP / @taptap/maker, `verified-2026-10-23` in the scout's local tool inventory. Use project-side provider guidance reached through the [Maker console](https://maker.taptap.cn). Remote-build operations belong to that integration; local preview is not release evidence. |
| Compliance gates | [Ordinary mini-game pre-filing guide](https://developer.taptap.cn/minigameapidoc/quick-start/guide/pre-filing/) explicitly excludes automatic application to Workshop/Maker, `verified-2026-10-23`. Workshop-specific review rules are `unavailable`; confirm them in the current console. The pinned Creative Workshop Content Authorization Agreement, effective 2026-03-11 and inspected 2026-10-23, grants the named publisher worldwide exclusive, royalty-free, sublicensable rights for the specified content uses, with withdrawal requiring the stated takedown process and 30 days' written notice. This is a dated agreement snapshot, not a claim that the review rules were retrieved. Read the current agreement in the console and confirm rights/authorization before acceptance: `verify-current-policy`. |
| Material-spec source | Workshop/Maker-specific current console requirements: `verify-current-policy`; the [store materials v4 page](https://developer.taptap.cn/docs/store/release/publish/material/) is a reference, not proof of identical requirements. |
| Monetization | Maker ad integration and financial-entity settlement setup are described in local provider guidance; current availability, IAP availability for this particular surface, and terms are `verify-current-policy`. |

### Steam

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | Steamworks App Admin at `partner.steamgames.com`; required publishing/build-account permissions, `verified-2026-10-23` via [uploading documentation](https://partner.steamgames.com/doc/sdk/uploading). |
| Build form | Game content organized into SteamPipe depots with a build description. |
| Automation | [SteamCMD / SteamPipe](https://partner.steamgames.com/doc/sdk/uploading), `verified-2026-10-23`. The default branch cannot be set live automatically through the documented build setting; uploading a depot is not release. |
| Compliance gates | [Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee): USD 100 per app, recoupable after USD 1,000 Adjusted Gross Revenue, `verified-2026-10-23`; re-check at launch. Distribution/content/privacy agreements and [store/build reviews](https://partner.steamgames.com/doc/store/review_process), `verified-2026-10-23`. Treat territory-specific obligations as `verify-current-policy`; this global storefront profile does not waive China obligations or describe Steam China. |
| Material-spec source | [Review process](https://partner.steamgames.com/doc/store/review_process) and App Admin capsule/screenshots fields; exact pixel matrix is `verify-current-policy`. |
| Monetization | Steam Wallet microtransactions; no platform ad network, `verified-2026-10-23` in the scout. Re-check current product terms in Steamworks before selecting the model. |

### Google Play

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | `play.google.com/console`; registration fee/account eligibility are `verify-current-policy`. |
| Build form | Signed Android App Bundle or eligible APK; confirm package format eligibility for this app. |
| Automation | [Google Play Developer Publishing API](https://developers.google.com/android-publisher) and [fastlane supply](https://docs.fastlane.tools/actions/supply/), `verified-2026-10-23`. Draft edits require commit before taking effect; publication state remains a separate observation. |
| Compliance gates | [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469): published apps, including zero-data apps, need accurate declarations and privacy policy; internal-testing-only apps, system services, and private apps have the documented exemptions, `verified-2026-10-23`. Declarations cover the package and must remain accurate across live versions. [New personal accounts after 2023-11-13](https://support.google.com/googleplay/android-developer/answer/14151465): at least 12 testers continuously opted in for 14 days before applying for production access, `verified-2026-10-23`; re-check current applicability. |
| Material-spec source | Current Play Console field help plus [supply metadata reference](https://docs.fastlane.tools/actions/supply/); exact pixel sizes are `verify-current-policy`. |
| Monetization | Play Billing/subscriptions and ad-network integration: `verify-current-policy` for fees, billing eligibility, data use and audience rules. |

### iOS App Store

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | `appstoreconnect.apple.com`; membership fee and eligibility are `verify-current-policy`. |
| Build form | Signed iOS artifact produced with macOS + Xcode; this host requirement was recorded by the scout as `verified-2026-10-23` from fastlane's build/signing context. |
| Automation | [fastlane deliver](https://docs.fastlane.tools/actions/deliver/) and [pilot](https://docs.fastlane.tools/actions/pilot/), `verified-2026-10-23`. Exact current Apple upload command surface is `unavailable`; consult [Apple distribution documentation](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases). Do not treat notarization as an interchangeable iOS upload operation. |
| Compliance gates | [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): functional final build, reviewer access to login/IAP, digital unlock IAP requirements, pre-purchase randomized-item odds disclosure, non-expiring purchased currency and restoration of restorable purchases, `verified-2026-10-23` snapshot. Regional exceptions/entitlements and current applicability are `verify-current-policy`; this summary is not a universal billing-exception ruling. No review-time SLA was established in the scout. |
| Material-spec source | App Store Connect screenshot/preview fields and [deliver reference](https://docs.fastlane.tools/actions/deliver/); exact device dimensions are `verify-current-policy`. |
| Monetization | StoreKit purchases/subscriptions and third-party ads; tracking/ATT applicability and current billing terms are `verify-current-policy`. |

### Huawei AppGallery / HarmonyOS

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | `developer.huawei.com/consumer/en/service/josp/agc/index.html`; identify the AGC app and Android versus HarmonyOS track. |
| Build form | Android APK/AAB versus HarmonyOS project outputs (HAP/HSP/HAR and distribution assembly); these are distinct outputs, not interchangeable upload packages. Confirm the accepted release artifact. |
| Automation | AGC Publishing/Upload Management families, `verified-2026-10-23` from the [package endpoint documentation](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-References/agcapi-add-packageurl-0000001158245065). [AGC overview](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-Guides/agcapi-overview-0000001158245083) timed out; its prose remains inferred, not verified. [hvigorw build documentation](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-hvigor-commandline) was `verified-2026-10-23` from the official search index only, not a full-page fetch. HarmonyOS-specific release submission API is `unavailable`. |
| Compliance gates | China-market matrix plus Huawei quality/privacy and HarmonyOS-specific requirements: `verify-current-policy`. |
| Material-spec source | Current AGC app-information fields; consolidated material matrix not retrieved, `verify-current-policy`. |
| Monetization | Huawei IAP/HMS payment and Huawei/Petal ads: `verify-current-policy` by target track and region. |

### Domestic Android channels

Treat Xiaomi, OPPO, vivo, and Yingyongbao as separate releases within this profile; a generic Android upload path does not establish game joint-operation eligibility.

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | [Xiaomi](https://dev.mi.com/xiaomihyperos/documentation), [OPPO](https://open.oppomobile.com/), [vivo](https://developer.vivo.com/), and Tencent/Yingyongbao documentation at [open.qq.com](https://wikinew.open.qq.com/index.html). Validate current account/product entry: `verify-current-policy`; the scout's additional `open.play.cn/dev/` pointer is unconfirmed for this identity and must not be used as proof of Tencent ownership. |
| Build form | Signed Android package for the selected app/game channel; Xiaomi's mini-game RPK path is distinct. |
| Automation | [Xiaomi APK upload API](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1134) and [mini-game listing guide](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1454), `verified-2026-10-23` from the scout's official search-index evidence. OPPO/vivo/Yingyongbao game-upload API applicability: `verify-current-policy`; full game-specific docs were not retrieved. [DCloud configuration](https://uniapp.dcloud.net.cn/uni-publish/config.html) and [first-publication guide](https://uniapp.dcloud.net.cn/uni-publish/first.html) are third-party leads only; credential and initial-console-creation claims remain inferred. |
| Compliance gates | ISBN, filing, software copyright, real-name/anti-addiction, privacy, joint-operation agreements: `verify-current-policy` independently for each channel. |
| Material-spec source | Each current console's game-listing fields; exact material requirements are `verify-current-policy`, not shared Android constants. |
| Monetization | Channel payment/ad eligibility and revenue terms: `verify-current-policy` separately; no common SDK or business agreement is assumed. |

### H5 self-hosting

| Checklist field | Reference and decision to make |
| --- | --- |
| Console entry | No store console; identify the actual hosting/deployment owner. |
| Build form | Web directory that opens correctly over HTTPS, including runtime assets and any required server services. |
| Automation | Host-specific deployment capability, `verify-current-policy` against the chosen host's current documentation. No universal publishing CLI or public API is asserted; record that provider's exact documentation URL once selected. |
| Compliance gates | China-facing publication can still require filing/content and other approvals; jurisdiction, privacy and minor obligations are `verify-current-policy`. Absence of a store is not an exemption. |
| Material-spec source | `none` with rationale: no store listing. If an embedding/discovery partner exists, use its current specifications instead. |
| Monetization | Self-integrated ads/payments and provider terms are `verify-current-policy`. Assign dispute/refund responsibility explicitly; no store-managed refund process is assumed. |

Test web loading, asset paths, console errors, HTTPS, MIME types, cache/update behavior, and the engine's actual requirements. WASM and cross-origin isolation requirements depend on the export; do not impose one header recipe on every engine.

### China compliance topic checklist

This matrix asks what applies; it does not decide the law. **Every row is `verify-current-policy` on every release**, including an explicit applicability decision and responsible owner. Separate filing types rather than treating ICP, cultural licensing, and platform pre-filing as synonyms.

| Topic | Release-time question | Source/check route | Status |
| --- | --- | --- | --- |
| Banhao / ISBN (版号) | Does this game, business model, operator and territory require publication approval, and do names/entities match? Do not assume ads imply exemption. | [NPPA](https://www.nppa.gov.cn/) publishes approval batches; current applicability must be established with the relevant authority/platform. | `verify-current-policy` |
| Filing / beian (备案) | Which website/app, cultural-operation, or mini-game filing applies to this surface and entity? | [TapTap ordinary mini-game pre-filing](https://developer.taptap.cn/minigameapidoc/quick-start/guide/pre-filing/) is a platform-specific example, not a rule for Maker/Workshop or all channels; confirm with the responsible authority. | `verify-current-policy` |
| Real-name / anti-addiction | What identity, play-time and spending protections apply to the audience, and have they been tested? | Current platform rules and competent regulator guidance; no universal integration was established. | `verify-current-policy` |
| Privacy policy | Do the policy and consent/data disclosures match the build, SDKs, backend and all live variants? | [Douyin norms](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/operation1/norms/standard), [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469), plus local law and platform-specific policy. | `verify-current-policy` |
| Minor refunds | Who handles minor-initiated purchase claims, what current rules apply, and can support reconcile entitlements? | No primary Chinese rule retrieved; obtain current guidance from the relevant regulator/consumer-protection authority and platform before approving paid release. | `verify-current-policy` |
| Loot-box odds | Are probabilities displayed before purchase, and do displayed values match the active reward configuration? | [Apple guideline 3.1.1](https://developer.apple.com/app-store/review/guidelines/) is a dated platform example; Chinese-market obligations need their own current authority. | `verify-current-policy` |

The 2019 WeChat qualification mirror is only a historical category hint, never a current exemption or certificate rule. Re-check content rights and applicable licenses alongside this matrix, including the scope of any sublicensing permission.

### Compare surfaces before committing to a launch order

Use audience fit, existing qualifications/accounts, automation coverage, review dependencies, recovery cost, and support burden. The following is planning judgment from the scout, not measured performance or a guaranteed review schedule.

| Surface | Main planning tradeoff |
| --- | --- |
| WeChat | Automated upload/preview helps iteration; China eligibility and unavailable materials source still need resolution. |
| Douyin | Upload automation is useful, but manual review submission and entity/name matching remain separate work. |
| TapTap store | Official project skills cover operations; computed qualification requirements prevent inventing blanket blockers. |
| Maker / Workshop | Hosted delivery can simplify technical recovery; content authorization and distinct review rules can constrain migration. |
| Steam | Mature build upload does not remove store/build gates or manual default-branch promotion; app fee is a sunk launch commitment until recouped. |
| Google Play | Publishing automation is broad; account testing gates and package-wide data declarations affect schedule. |
| iOS | macOS/Xcode capacity and review uncertainty increase preparation cost; existing infrastructure can reverse that disadvantage. |
| Huawei / HarmonyOS | Android API capability does not establish HarmonyOS submission support; plan the tracks separately. |
| Domestic Android | Per-channel qualification and game-specific automation gaps multiply coordination work. |
| H5 self-host | Technical redeployment may be simple; payments, disputes, security and China-facing obligations remain the operator's work. |

Prefer a first surface where the intended audience, usable toolchain, and qualifications already align. International-first and China-first projects can rationally choose different orders. Do not convert the comparison into a claim that global stores eliminate territory-specific law or that a hosted platform guarantees rollback.

## 4. Failure criteria and measurable invariants

- Without target region, app identity, candidate version, and current applicable requirements, report `NOT ASSESSED — NO DATA` for release readiness.
- Every applicable mandatory checklist item has a current result and owner; unresolved required items total zero before a green verdict.
- Every unset decision produces unresolved output. An explicit `none` with valid applicability rationale produces a distinct recorded decision, never a silently empty field.
- Every release/content update reopens and rechecks its compliance gates. A previous release's green result cannot silently carry over.
- Submitted package identity equals the tested candidate and listing binding. Upload success, approval, and public availability remain separate states.
- H5 smoke checks show zero unexplained load errors on the selected browser/device matrix; missing device coverage is reported rather than inferred.

Evaluation: a fully uploaded build with an unset privacy decision is blocked. A game with explicitly no purchases can mark purchase-product setup not applicable with rationale, but still evaluates privacy and audience protections. A new SDK in an update reopens the data/privacy check even when the store previously approved the app.

## 5. Platform/engine boundary

The package owns readiness questions, sequencing, blocking criteria, and source freshness. The **12 official taptap-cli skills** own TapTap console-specific operations and are never vendored, forked, or reimplemented here. Their ownership remains with TapTap and project-side installation. Reference inventory (`verified-2026-10-23`, local official CLI inspection): taptap-cli, taptap-identity, taptap-publish-game, taptap-app-edit, taptap-asset-library, taptap-materials, taptap-package-management, taptap-test-plan, taptap-qualification, taptap-dashboard-stats, taptap-player-feedback, and taptap-community-management.

Defer computed qualification analysis and slot inspection to the official qualification skill; do not substitute a raw slot inventory for its requirement calculation. Maker MCP owns its remote build/assets/test integration; the store CLI and Maker are complementary. Console schemas, credentials, write gating, upload arguments and publication commands stay in current project-side official guidance, reached through [TapTap developer documentation](https://developer.taptap.cn/docs/store/release/publish/) or the installed provider skills.

Likewise, the named automation tools in the profiles are citation pointers only. Engine-* skills own export mechanics, game-build-release owns candidate/recovery discipline, game-monetization-* owns business design, and project-side platform documentation owns execution. This method never authorizes a production write.

## 6. Sources and verification status

Prepared 2026-10-23 from the assigned platform reconnaissance dated 2026-10-23 and the pinned Creative Workshop agreement inspected on that date (effective 2026-03-11). URLs next to claims preserve the source context. Local CLI observations are explicitly marked local; search-index evidence is not presented as full-page retrieval. The agreement snapshot did not carry its canonical URL, so the console is a discovery pointer rather than an invented agreement URL. Re-check the agreement there before accepting it.

Method references, rewritten in original prose:

- [Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios), `05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418`, MIT: launch-checklist's distinction between absent and explicit negative decisions; no workflow shell copied.
- [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills), `38a4c2500eeb5ff9ac084336b8f66108069d2f8d`, Apache-2.0: store/build readiness as parallel tracks that must both pass; no source files, scripts, or passages copied.

### Nine explicitly open points

1. **WeChat material specifications — unavailable:** the [material page](https://developers.weixin.qq.com/minigame/product/material.html) returned 404; obtain the current console table.
2. **WeChat IAA/IAP ISBN applicability — verify-current-policy:** the [IAA page](https://developers.weixin.qq.com/minigame/introduction/iaa) returned 404; the 2019 mirror cannot establish exemptions.
3. **Creative Workshop review rules — unavailable:** the [publish page](https://developer.taptap.cn/docs/store/release/publish/) returned 403; ordinary pre-filing rules exclude automatic application. The later agreement snapshot resolves authorization text, not this missing review ruleset.
4. **Apple altool/xcrun upload surface — unavailable:** [distribution documentation](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases) was blocked to the scout. Verify the actual current upload route; do not infer it from notarization tools.
5. **HarmonyOS release-submission API — unavailable:** [AGC overview](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-Guides/agcapi-overview-0000001158245083) and Android endpoint support do not prove a HarmonyOS release-submission path.
6. **OPPO/vivo/Yingyongbao game-upload APIs — verify-current-policy:** [DCloud's guide](https://uniapp.dcloud.net.cn/uni-publish/config.html) supplies third-party leads, not authoritative game-channel credentials or release support.
7. **Steam wishlist release threshold — verify-current-policy:** no threshold was established by the [review-process page](https://partner.steamgames.com/doc/store/review_process); do not manufacture a prerequisite.
8. **Chinese minor refunds — verify-current-policy:** no primary source was retrieved; resolve the applicable regulator/platform rule before paid-release readiness.
9. **Huawei AGC overview prose — unavailable on direct fetch; inferred from endpoints:** the [overview](https://developer.huawei.com/consumer/en/doc/AppGallery-connect-Guides/agcapi-overview-0000001158245083) timed out. Endpoint-supported API family naming remains `verified-2026-10-23`; unobserved overview details do not inherit that label.

These gaps remain visible even when irrelevant to a selected release. Record explicit non-applicability rather than claiming they were resolved. Policy snapshots, fees, review gates, and automation availability all require release-time confirmation.
