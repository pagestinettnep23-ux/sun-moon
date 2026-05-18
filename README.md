# SUN + MOON Hook Project

这是一个基于 `SUN + MOON` 双币机制的 Web3 项目。当前阶段继续保持本地 / Mock / 预演，不部署主网，也不接触真实资金。

## 当前阶段

阶段 2：Base + Uniswap v4 Hook/AMM 技术预研。

当前已完成：

- SUN/MOON 曲线合约、数学测试和本地 Anvil 交互验证。
- SUN AMM 加池守卫历史原型和 MOON AMM 费用路由 Mock 测试。
- Base + Uniswap v4 技术路线、官方地址检查和最小 Hook callback 验证。
- `BaseMoonAmmFeeV4Hook` v2 return delta 收费适配。
- CREATE2 Hook 地址预检、Base Sepolia 参数预检和测试版 USDC adapter。
- 本地 `Create2HookDeployer` 草图和 CREATE2 Hook 部署保护测试。
- 本地 `Create2HookDeployer` 完整预演脚本：部署 deployer、挖 salt、部署 Hook 并复核地址。
- 本地 Base Sepolia adapter 预演脚本和回归测试。
- Base Sepolia `Create2HookDeployer` 第一次小额广播已完成，只部署 deployer，不部署 Hook/曲线/adapter。
- Base Sepolia 曲线核心和 `TestnetUsdcAdapter` 第二次小额广播已完成，只部署测试网核心合约和 adapter，不部署 Hook。
- Base Sepolia Hook 第三次小额广播已完成，实际地址等于 CREATE2 预测地址。
- Base Sepolia adapter / SunCurve 绑定广播已完成，adapter 和 `SunCurve.moonAMM` 已指向 Hook。
- Base Sepolia 受控 `MOON/USDC` 测试池 `PoolKey -> poolId` dry-run、白名单广播、初始化广播和链上复核均已完成。
- Base Sepolia 极小额 `MOON/USDC` 流动性/交换演练准备、资产与 Permit2 授权准备、本地 fork 报价预检、小额流动性 + swap 广播草案 dry-run、以及真实 Base Sepolia 小额流动性 + swap 广播均已完成并链上复核。
- Base Sepolia 前端只读价格读取、Hook 状态、Adapter 状态、Position NFT 和测试网交易链接对齐已完成。
- Base Sepolia 小额演练总结和主网前风险清单已整理完成；当前仍不进入主网部署。
- Base 主网角色普通钱包方案草案已整理完成；owner 已确认不使用多签钱包，改用普通钱包公开地址，仍不收集私钥、不部署主网。
- Base 主网正式参数确认清单模板已新增，用于后续逐项确认公开地址、官方合约、CREATE2、poolId、初始化价格和 Gate；当前只是模板，不是部署批准。
- Base 主网正式参数“小白确认版”已新增，把后续 owner 需要确认的公开地址、池参数、初始价格、owner 放弃和停止条件用非技术语言列出；owner 已确认初始价格按两个代币的初始铸造价格设置：`SUN/USDC=1`，`MOON/USDC=0.24`；当前仍不部署主网。
- Base 主网 LP fee 与 tickSpacing 小白决策说明已新增；owner 已确认两个项目支持池都先采用 `LP fee=0.3%`、`tickSpacing=60` 作为草案参数，这不是主网执行。
- Base 主网正式参数填表版已新增，把公开参数、待填地址、已确认草案池参数和后续待计算项集中为 `KEY=VALUE` 格式；当前仍不广播、不部署。
- Base 主网正式合约地址与 CREATE2 参数草案已新增，明确正式合约地址、CREATE2 Hook deployer、Hook salt、预测 Hook、poolId、initial tick 和 sqrtPriceX96 的依赖顺序；当前仍不广播、不部署。
- Base 主网核心合约部署 dry-run 草案已新增，可预测 `SUN_TOKEN`、`SUN_CURVE`、`MOON_TOKEN`、`MOON_CURVE`、`CREATE2_HOOK_DEPLOYER`，并模拟 minter/owner/曲线绑定；当前仍不广播、不部署。
- Base 主网 mainnet fork dry-run 草案和只模拟 Foundry 脚本已新增；四个角色普通钱包公开地址已填写，2026-05-17 已用公开 Base RPC 跑通 Base mainnet fork 只模拟 dry-run；未广播、未部署、未用私钥、未接真实资金。
- Base 主网审计输入包和上线前人工复核清单已新增并更新到 `rc2`；下一步是外部审计或安全 review，不是主网广播。
- Base 主网审计版本已冻结为本地合约审计候选：`audit-sun-moon-base-contracts-2026-05-17-rc2`，commit `6b136193590bc981eb4689b822b8c921206d9d37`；前端暂未纳入本轮合约审计范围。
- Slither 免费工具预审已完成，主范围发现已修复并形成报告：`docs/Base-主网免费工具审查报告-2026-05-17.md` 和 `docs/slither-report-2026-05-17.json`。
- 免费审计替代流程阶段 A 已完成：新增 SUN/MOON 曲线 fuzz、invariant 安全测试，并增强统一 v4 Hook 费用和 renounce fuzz 测试；全量测试更新为 `307 passed, 0 failed`。
- 在没有正式审计预算且暂时跳过社区 review 的前提下，已新增 Base Sepolia 长期演练计划；建议至少观察 14 天，仍不进入主网部署。
- Base Sepolia 长期演练 Day 0 记录已创建，明确历史 `MOON/USDC` 测试池只能作为旧路径观察样本；rc3 最新统一 Hook 方案如果要完整验证，需要另起一轮 rc3 Base Sepolia dry-run / 测试网演练。
- Base Sepolia rc3 dry-run 草案脚本已新增：`PrepareBaseSepoliaRc3SunMoonUsdcDryRun`，可本地模拟新核心合约、统一 Hook、`SUN/USDC` 与 `MOON/USDC` 两个池、白名单、初始化和 renounce；脚本拒绝 Base 主网和广播开关。
- 2026-05-18 已跑通 Base Sepolia rc3 fork 只读 dry-run：`chainId=84532`、`broadcastRequested=false`、`simulationOnly=true`、两个池初始化和 renounce 锁定检查通过；未广播、未部署、未用私钥。
- Base Sepolia rc3 测试网广播草案已新增：`PrepareBaseSepoliaRc3SunMoonUsdcBroadcastDraft`，只生成分阶段计划，默认 `broadcastAllowed=false`，拒绝 `PRIVATE_KEY` 和执行开关；专项测试 9 passed，0 failed。
- 2026-05-18 已跑通 Base Sepolia rc3 广播草案 fork 只读检查：`chainId=84532`、`broadcastAllowed=false`、`executeRequested=false`、`privateKeyPresent=false`、`totalTransactionsPlanned=19`；未广播、未部署、未用私钥。
- Base Sepolia rc3 分阶段广播脚本草案已新增：`PrepareBaseSepoliaRc3SunMoonUsdcStagedBroadcastDraft`，把未来测试网广播拆成 Stage 1/2/3，默认 `executionBlocked=true`，不调用广播；专项测试 8 passed，0 failed。
- 2026-05-18 已跑通 Base Sepolia rc3 分阶段广播草案 fork 只读检查：`chainId=84532`、`broadcastAllowed=false`、`executionBlocked=true`、`privateKeyPresent=false`、`totalTransactionsPlanned=19`、`stage1AddressCollision=false`、`stage2HookCollision=false`；未广播、未部署、未用私钥。
- Base Sepolia rc3 分阶段广播人工复核表已新增，把 3 个阶段、预测地址、两个 poolId 和停止条件整理成小白可打勾清单；当前仍只是人工复核，不是广播批准。
- Base Sepolia rc3 Stage 1 测试网广播草案已新增，把核心合约部署的 12 笔交易拆成小白清单；当前仍不广播、不部署、不需要私钥。
- Base Sepolia rc3 Stage 1 广播前最终确认单已新增，把 Stage 1 做什么、不做什么、预测地址、最后只读检查、批准边界和停止条件整理成 owner 按钮前确认单；当前仍未批准广播。
- Base Sepolia rc3 Stage 1 操作员执行说明草案已新增，规定未来操作员只能先跑只读检查、记录公开输出，不能从该文档直接广播、不能使用私钥、不能碰主网；当前仍未批准广播。
- Base Sepolia rc3 Stage 1 广播指令草案（非执行版）已新增，明确当前不提供可复制广播命令；未来如需 Stage 1 广播必须另写最终指令并再次复核，仍不包含私钥或主网动作；当前仍未批准广播。
- 2026-05-18 已按 Stage 1 确认单和操作员说明重新跑通 Base Sepolia rc3 Stage 1 前 fork 只读检查：`chainId=84532`、`SEPOLIA_DEPLOYER nonce=16`、`broadcastAllowed=false`、`executionBlocked=true`、`privateKeyPresent=false`、`stage1AddressCollision=false`；未广播、未部署、未用私钥。
- 2026-05-18 已按 Stage 1 广播指令草案（非执行版）再次跑通 Base Sepolia rc3 fork 只读复查：`chainId=84532`、`selectedStage=0`、`selectedStageTxs=19`、`SEPOLIA_DEPLOYER nonce=16`、`broadcastAllowed=false`、`executionBlocked=true`、`privateKeyPresent=false`、`stage1AddressCollision=false`、`stage2HookCollision=false`；未广播、未部署、未用私钥。
- Base Sepolia rc3 Stage 1 最终广播指令草案（审阅版，不执行）已新增，整理 owner 批准语句、12 笔 Stage 1 交易边界、本地签名边界、交易哈希记录区和停止条件；当前仍不提供可执行广播命令，仍未批准广播。
- Base Sepolia rc3 Stage 1 最终广播前人工批准表已新增，并已记录 owner 的 Stage 1-only 精确批准语句；当前仍不是执行版，仍不广播、不部署、不需要私钥。
- Stage 1 批准表中的 `0x2F6E...`、`0x6E22...`、`0x277b...` 三个钱包地址已明确标注为 Base Sepolia 测试网地址，不是 Base 主网正式地址。
- owner 已给出精确批准语句：只批准 Base Sepolia 测试网 rc3 Stage 1，明确不批准 Stage 2/3、Base 主网、真实资金操作，且不会提供私钥/助记词/恢复词；这只形成 Stage 1-only 人工批准，仍不是执行版命令，下一步必须先重新跑只读复查。
- 2026-05-18 已在 Stage 1-only 人工批准后重新跑通 Base Sepolia rc3 Stage 1 最终广播前只读检查：`chainId=84532`、`selectedStage=1`、`selectedStageTxs=12`、`SEPOLIA_DEPLOYER nonce=16`、`broadcastAllowed=false`、`executionBlocked=true`、`privateKeyPresent=false`、`stage1AddressCollision=false`；未广播、未部署、未用私钥。
- Base Sepolia rc3 Stage 1 执行版命令审阅清单已新增，作为未来出现任何执行版命令前的最后人工检查表；当前仍不提供可复制执行命令，仍不广播、不部署、不需要私钥。
- Base Sepolia rc3 Stage 1 执行版命令草案（不广播）已新增，明确当前只提供不广播的只读复核命令，真正执行版必须另行准备、另行批准、另行复核；当前仍未广播、未部署、未用私钥。
- Base Sepolia rc3 Stage 1-only 执行脚本草案已新增：`PrepareBaseSepoliaRc3Stage1ExecutionDraft`，只覆盖 12 笔 Stage 1 核心部署/基础配置动作，默认 `executionBlocked=true`；拒绝 Base 主网、拒绝 `PRIVATE_KEY` 环境变量、拒绝未确认执行，专项测试 7 passed，0 failed；当前未广播、未部署。
- Base Sepolia rc3 Stage 1 广播后复核清单草案已新增，列出未来如果 Stage 1 真的广播成功后需要只读检查的 code、owner、minter、曲线配置和停止条件；当前仍未广播。
- Base Sepolia rc3 Stage 2 测试网广播草案已新增，把 Hook 部署、SunCurve 绑定、两个池白名单和两个池初始化拆成 6 笔小白清单；当前仍不广播、不部署、不需要私钥。
- Base Sepolia rc3 Stage 2 广播后复核清单草案已新增，列出未来如果 Stage 2 真的广播成功后需要只读检查的 Hook 配置、白名单、slot0 和 liquidity；当前仍未广播。
- Base Sepolia rc3 Stage 3 测试网广播草案已新增，把 `Hook.renounceOwnership()` 的 1 笔交易、不可逆风险和前置检查拆成小白清单；当前仍不广播、不部署、不需要私钥。
- Base Sepolia rc3 Stage 3 广播后复核清单草案已新增，列出未来如果 Stage 3 真的广播成功后需要只读确认的 `owner=0`、关键配置、白名单、slot0、liquidity 和管理员函数锁死检查；当前仍未广播。
- Base Sepolia rc3 Stage 1/2/3 总闸门清单已新增，把三阶段的广播前确认、广播后复核、owner 单独批准区和绝对停止条件合并成最终人工审批表；当前仍不广播、不部署、不需要私钥。
- 2026-05-18 已按总闸门要求重新跑通 Base Sepolia rc3 分阶段 fork 只读复查：`chainId=84532`、`broadcastAllowed=false`、`executionBlocked=true`、`privateKeyPresent=false`、`totalTransactionsPlanned=19`、`stage1AddressCollision=false`、`stage2HookCollision=false`；未广播、未部署、未用私钥。
- rc3 分阶段广播脚本草案新增后，最新全量 Foundry 测试已更新为 `334 passed, 0 failed`。
- 2026-05-16 方向已更新：SUN/MOON 都保持自由转账，不再试图在合约层禁止市场自行创建 AMM 池；项目只对明确支持的 Uniswap v4 Hook 池提供费用逻辑。
- 新的 Hook 池目标：`SUN/USDC` v4 Hook 池 swap 收 `2% USDC`，其中 `1.5%` 注入 `SunCurve`、`0.5%` 进入协议经费；`MOON/USDC` v4 Hook 池 swap 收 `5% USDC`，其中 `3%` 注入 `SunCurve`、`2%` 进入协议经费。
- 本地已新增 `BaseSunMoonUsdcFeeV4Hook`，统一支持 `SUN/USDC` 和 `MOON/USDC` 两类 USDC 计费 v4 Hook 池，并覆盖自由转账、SunCurve/MoonCurve mint/burn 兼容、2%/5% 收费、白名单和 renounce 后配置锁定测试。
- 本地已新增 `RehearseBaseSunMoonUsdcFeeV4Hook` 和对应测试，证明新版统一 Hook 可通过 CREATE2 预测并部署到正确 v4 Hook 权限地址；当前只是本地预演，不广播。
- 本地已新增 `ComputeBaseSunMoonUsdcPoolIds` 和对应测试，只计算新版 `SUN/USDC`、`MOON/USDC` v4 Hook 池的 `PoolKey -> poolId`、`initialTick`、`sqrtPriceX96`，不广播、不授权、不需要私钥。
- 使用 Base mainnet 预测地址已算出两个池参数：`SUN_USDC_POOL_ID=0xf0006d5dde476ffd2b43648468d5c6a6a8cf1f40bcac5c0c7d070491587e075a`、`MOON_USDC_POOL_ID=0xcf29a02432e947fe9240fe4378cb871b24691f7cd85e7e8c72464ff89c1c6735`；当前仍是预测计算结果，不是已部署池。
- Base 正式 USDC adapter 方案仍需按新方向人工 review：当前 `Direct-USDC-only` 草图可作为“只收 USDC 费用”的防呆基础，但主网前还需要用正式参数重新挖 salt、生成正式 poolId、跑 mainnet fork dry-run 和外部 review。
- `PrepareBaseMainnetDirectUsdcOnlyAdapter` 主网 dry-run 脚本和测试已完成；Base mainnet RPC dry-run 已通过，未广播、未部署、未用私钥。
- `PrepareBaseMainnetCoreDeployDryRun` 主网核心合约地址预测和配置模拟脚本已完成：本地测试 11 passed，0 failed；Base mainnet fork dry-run 已通过，输出 5 个预测核心地址；不调用 `startBroadcast`，拒绝广播标志。
- `ComputeBaseMainnetSunMoonUsdcHookSalt` 主网 Hook salt 计算脚本已完成：本地测试 10 passed，0 failed；Base mainnet fork dry-run 已通过，输出 `HOOK_SALT=0x0000000000000000000000000000000000000000000000000000000000001f79` 和 `PREDICTED_HOOK=0x04f968dE5cd57B1EB8215a9a488dC32508Fb80cc`；未广播、未部署、未用私钥。
- `PrepareBaseMainnetSunMoonUsdcForkDryRun` 只模拟脚本和测试已完成：本地测试 15 passed，0 failed；Base mainnet fork dry-run 已通过，模拟 CREATE2 Hook 部署、两个池白名单、两个池初始化和 renounce 后锁定检查；不调用 `startBroadcast`，拒绝广播标志。

当前 Base Sepolia 测试网记录：

```text
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
CREATE2_DEPLOYER_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
CREATE2_DEPLOYER_TX=0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596

SUN_TOKEN=0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
SECOND_BROADCAST_FIRST_TX=0xd9a4e6645d9dcab6f0d5310d72a9ce638715791b41494ed79cf20e233f2928ac
SECOND_BROADCAST_LAST_TX=0x47d262a0ec7ccb1e2470112ad2e363929e2ed0f79b1ad074dc1a71d4971f6e46
DEPLOYER_NONCE_AFTER_SECOND_BROADCAST=14

HOOK_SALT=0x00000000000000000000000000000000000000000000000000000000000022b9
PREDICTED_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
PREDICTED_HOOK_LOW_14_BITS=204
HOOK_DRY_RUN=passed
HOOK_DRY_RUN_ESTIMATED_REQUIRED_ETH=0.000030782763
HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
HOOK_DEPLOY_TX=0x376baf6403018674a6b61bc4b84324e13fc7fafcb8c1970c8f15b06215e59e17
HOOK_DEPLOY_RECEIPT_STATUS=1
HOOK_OWNER_BALANCE_AFTER_HOOK=0.001988519245970799
HOOK_OWNER_NONCE_AFTER_HOOK=1

HOOK_BINDING_DRY_RUN=passed
HOOK_BINDING_TXS_PLANNED=2
HOOK_BINDING_ESTIMATED_REQUIRED_ETH=0.000001204511
ADAPTER_AUTHORIZED_HOOK_BEFORE_BINDING=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SUN_CURVE_MOON_AMM_BEFORE_BINDING=0x0000000000000000000000000000000000000000
HOOK_BINDING_ADAPTER_TX=0x1319e675384b1e014debdb806a27915797bbd0cf8da9e253f04b1cc643ef97c4
HOOK_BINDING_SUN_CURVE_TX=0x6a6154f5e075f4b6d0975c4b60e1d517885adccb4577eb678134f4cc3966ed7c
HOOK_BINDING_RECEIPT_STATUS=1
ADAPTER_AUTHORIZED_HOOK_AFTER_BINDING=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
SUN_CURVE_MOON_AMM_AFTER_BINDING=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc

CONTROLLED_MOON_USDC_POOL_DRY_RUN=passed
MOON_USDC_POOL_CURRENCY0=0x036CbD53842c5426634e7929541eC2318f3dCF7e
MOON_USDC_POOL_CURRENCY1=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_USDC_POOL_FEE=3000
MOON_USDC_POOL_TICK_SPACING=60
MOON_USDC_POOL_HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
MOON_USDC_POOL_ID=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
MOON_USDC_ALLOWED_BEFORE=false
MOON_USDC_ALLOWLIST_DRY_RUN_TXS_PLANNED=1
MOON_USDC_ALLOWLIST_DRY_RUN_ESTIMATED_REQUIRED_ETH=0.00000073733
MOON_USDC_ALLOWLIST_TX=0x9f219d37f1a72dc6229df79217ed953f1e6ff01ed1f4d958854fe432616ed325
MOON_USDC_ALLOWLIST_RECEIPT_STATUS=1
MOON_USDC_ALLOWLIST_BLOCK=41524110
MOON_USDC_ALLOWED_AFTER_BROADCAST=true
CONTROLLED_MOON_USDC_POOL_INITIALIZE_DRY_RUN=passed
MOON_USDC_INITIAL_TICK=276300
MOON_USDC_INITIAL_SQRT_PRICE_X96=79133045881256921541446514419412387
MOON_USDC_INITIAL_PRICE_APPROX=1 MOON ~= 1.0024 USDC
MOON_USDC_INITIALIZED_BEFORE=false
MOON_USDC_INITIALIZE_DRY_RUN_TXS_PLANNED=1
MOON_USDC_INITIALIZE_DRY_RUN_ESTIMATED_REQUIRED_ETH=0.000000839773
MOON_USDC_INITIALIZE_TX=0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310
MOON_USDC_INITIALIZE_RECEIPT_STATUS=1
MOON_USDC_INITIALIZE_BLOCK=41525115
MOON_USDC_INITIALIZE_GAS_USED=52201
MOON_USDC_INITIALIZED_AFTER_BROADCAST=true
MOON_USDC_SLOT0_SQRT_PRICE_X96=79133045881256921541446514419412387
MOON_USDC_SLOT0_TICK=276300
MOON_USDC_SLOT0_PROTOCOL_FEE=0
MOON_USDC_SLOT0_LP_FEE=3000
MOON_USDC_INITIALIZE_POST_BROADCAST_TXS_PLANNED=0

TINY_MOON_USDC_BROADCAST=completed
TINY_MOON_USDC_LIQUIDITY_TX=0x99c69749bbd9199ac7476f8d0175d2f3a651b81d97a97a607e13ca2b5168517b
TINY_MOON_USDC_SWAP_TX=0x61744130044a25395399db900c542872fe8c887057025a8d6b86bc0c71aeebaa
TINY_MOON_USDC_POSITION_TOKEN_ID=22355
TINY_MOON_USDC_POSITION_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
TINY_MOON_USDC_ACTOR_USDC_BALANCE_AFTER=18400000
TINY_MOON_USDC_ACTOR_MOON_BALANCE_AFTER=284123473562317985

TINY_MOON_USDC_REHEARSAL_DRY_RUN=passed
REHEARSAL_ACTOR=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
TINY_LIQUIDITY_USDC_AMOUNT=1000000
TINY_LIQUIDITY_MOON_AMOUNT=1000000000000000000
TINY_SWAP_USDC_IN=100000
TINY_SWAP_FEE_TO_SUN_CURVE=3000
TINY_SWAP_FEE_TO_PROTOCOL=2000
TINY_SWAP_USDC_GROSS_INPUT_WITH_HOOK_FEE=105000
TINY_SWAP_MIN_USDC_TO_CURVE=3000
TINY_SWAP_HOOK_DATA=0x0000000000000000000000000000000000000000000000000000000000000bb8
REHEARSAL_ACTOR_USDC_BALANCE=0
REHEARSAL_ACTOR_MOON_BALANCE=0
REHEARSAL_ACTOR_USDC_ALLOWANCE_TO_PERMIT2=0
REHEARSAL_ACTOR_MOON_ALLOWANCE_TO_PERMIT2=0
REHEARSAL_READY_FOR_LIQUIDITY_DRY_RUN=false
REHEARSAL_READY_FOR_SWAP_DRY_RUN=false
REHEARSAL_READY_FOR_COMBINED_DRY_RUN=false
REHEARSAL_TRANSACTIONS_PLANNED=0

TINY_REHEARSAL_ASSET_APPROVALS_DRY_RUN=passed
ASSET_SUN_MINT_USDC_AMOUNT=500000
ASSET_MOON_MINT_SUN_AMOUNT=300000000000000000
ASSET_PROJECTED_SUN_OUT=490000000000000000
ASSET_PROJECTED_MOON_OUT=1187499858980000000
ASSET_REQUIRED_USDC_FOR_REHEARSAL=1105000
ASSET_REQUIRED_USDC_BEFORE_PREP=1605000
ASSET_ACTOR_USDC_BALANCE=0
ASSET_ACTOR_SUN_BALANCE=0
ASSET_ACTOR_MOON_BALANCE=0
ASSET_CAN_EXECUTE=false
ASSET_TRANSACTIONS_PLANNED=9
ASSET_TRANSACTIONS_EXECUTED=0
```

下一步不是主网。Hook 已部署并链上复核通过，adapter 授权和 `SunCurve.moonAMM` 绑定也已完成并复核通过。受控 `MOON/USDC` 测试池 poolId 已算出，`setAllowedMoonPool(poolId, true)` 和 `PoolManager.initialize(poolKey, sqrtPriceX96)` 都已在用户明确批准后广播成功，链上复核 `allowedMoonPools(poolId)=true` 且 `slot0.tick=276300`。极小额流动性/交换演练准备、资产/Permit2 授权、报价预检、真实小额加流动性和 `0.1 USDC -> MOON` swap 都已完成。2026-05-16 后主网前方案改为：SUN/MOON 自由转账，市场可自行建池；本地已新增统一 v4 Hook 池费用逻辑，`SUN/USDC` 收 `2% USDC`、`MOON/USDC` 收 `5% USDC`，并新增只计算两类新池 `PoolKey -> poolId`、`initialTick`、`sqrtPriceX96` 的 dry-run 脚本。2026-05-17 已跑通 Base mainnet fork 只模拟总 dry-run；2026-05-18 已跑通 Base Sepolia rc3 fork 只读 dry-run、广播草案 fork 只读检查、分阶段广播草案 fork 只读检查。仍不进入 Base 主网部署，也不接真实资金。

最新全量 Foundry 测试记录：

```text
forge test --threads 1 --isolate
334 passed, 0 failed
```

## 项目结构

```text
contracts/        Solidity 合约
test/             Foundry 测试
script/           部署和辅助脚本
frontend/         前端应用
docs/             项目文档
```

## 本地工具

建议安装：

- Foundry：用于合约编译、测试和部署。
- Git：用于版本管理。
- Node.js：后续前端会用到。

常用命令：

```powershell
forge --version
forge build
forge test
forge fmt
```

如果本机还没有 Foundry，后续需要先安装 Foundry，再继续合约编译和测试。

更多入口：

- `docs/Base-Uniswap-v4-技术路线.md`
- `docs/Base-USDC-Adapter方案.md`
- `docs/Base-Sepolia-测试网前部署参数清单.md`
- `docs/Base-Sepolia-受控演练计划.md`
- `docs/Base-Sepolia-前端只读状态卡验收-2026-05-15.md`
- `docs/Base-Sepolia-小额演练总结与主网前风险清单-2026-05-15.md`
- `docs/Base-SUN-MOON-v4-Hook池新方案-2026-05-16.md`
- `docs/Base-主网角色普通钱包方案-草案-2026-05-16.md`
- `docs/Base-主网正式合约地址与CREATE2参数草案-2026-05-17.md`
- `docs/Base-主网mainnet-fork-dry-run草案-2026-05-16.md`
- `docs/Base-主网审计输入包-2026-05-17.md`
- `docs/Base-主网免费工具审查报告-2026-05-17.md`
- `docs/Base-主网免费审计替代流程-阶段A-2026-05-17.md`
- `docs/Base-Sepolia-长期演练计划-2026-05-17.md`
- `docs/演练记录-Base-Sepolia-长期-2026-05.md`
- `docs/Base-Sepolia-rc3-dry-run草案-2026-05-17.md`
- `docs/Base-Sepolia-rc3-测试网广播草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-分阶段广播脚本草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-分阶段广播人工复核表-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage1-测试网广播草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage1-广播前最终确认单-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage1-操作员执行说明草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage1-广播指令草案-非执行版-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage1-最终广播指令草案-审阅版-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage1-最终广播前人工批准表-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage2-测试网广播草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage2-广播后复核清单草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage3-测试网广播草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage3-广播后复核清单草案-2026-05-18.md`
- `docs/Base-Sepolia-rc3-Stage1-2-3-总闸门清单-2026-05-18.md`
- `docs/Base-主网上线前人工复核清单-2026-05-17.md`
- `docs/Base-主网角色钱包与多签方案-草案-2026-05-15.md`（历史方案，已被普通钱包方案取代）
- `docs/Base-主网上线后最小权限与放弃管理权方案-2026-05-15.md`
- `docs/Base-正式USDC-Adapter方案选择-2026-05-15.md`
- `docs/Base-Sepolia-最小部署规划.md`
- `docs/Base-Sepolia-小额广播草案清单.md`
- `docs/Base-Sepolia-前端读取对齐清单.md`
- `docs/Base-Sepolia-前端验收记录-2026-05-15.md`
- `docs/Base-Sepolia-地址准备说明.md`
- `docs/Base-Sepolia-CREATE2-Deployer选择说明.md`
- `docs/Base-Sepolia-参数模板.md`
- `docs/演练记录-Base-Sepolia-2026-05-14.md`
- `script/README.md`

## 安全提醒

- 不要把私钥、助记词、真实 RPC Key 写进代码。
- `.env` 文件不能提交。
- 主网部署前必须先经过本地测试、测试网验证和安全检查。




