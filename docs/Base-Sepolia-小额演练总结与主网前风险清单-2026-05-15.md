# Base Sepolia 小额演练总结与主网前风险清单 - 2026-05-15

本文档给项目 owner、前端窗口和后续开发者使用。它不是主网部署方案，也不是投资说明；当前结论仍然是：继续停留在本地 / Mock / Base Sepolia 测试网，不接真实资金，不部署 Base 主网。

## 官方参考

- Base 官方文档记录：Base Mainnet chainId 是 `8453`，公共 RPC 是 `https://mainnet.base.org`，且官方提示公共 endpoint 有限流，不适合生产系统直接依赖；Base Sepolia chainId 是 `84532`，RPC 是 `https://sepolia.base.org`。参考：[Base Connecting to Base](https://docs.base.org/chain/using-base)、[Base RPC Overview](https://docs.base.org/base-chain/api-reference/rpc-overview)。
- Safe 官方文档说明：Safe Smart Account 支持多 owner 和 threshold，多签交易需要达到 threshold 后才能执行；owner 可以是 EOA、其他智能账户或 passkey。参考：[Safe Smart Account overview](https://docs.safe.global/advanced/smart-account-overview)。
- Safe 帮助文档建议 threshold 高于 `1`，避免单个账户独自执行交易；常见个人方案是 3 个 signer、2 个确认。参考：[What Safe setup should I use?](https://help.safe.global/articles/1038062742-what-safe-setup-should-i-use)。

## 一句话结论

Base Sepolia 小额演练已经证明：SUN/MOON 曲线核心、测试版 USDC adapter、Uniswap v4 Hook、受控 `MOON/USDC` 测试池、小额加流动性、小额 swap、以及前端只读读取路径可以串起来。

但这只证明“测试网技术链路可跑通”，不等于“可以上主网”。2026-05-16 方向已更新：SUN/MOON 保持自由转账，不再试图禁止市场自行建池；项目下一阶段应设计 `SUN/USDC` 和 `MOON/USDC` 两类 v4 Hook 池收费路径。主网前仍必须完成权限治理、上线后放弃管理权方案、正式 Hook/adapter 方案、安全审计、前端交易风险控制、真实 USDC/官方地址复核、部署密钥隔离和应急预案。

## 已完成的测试网链路

| 环节 | 状态 | 关键结果 |
| --- | --- | --- |
| CREATE2 deployer | 已部署 | `0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D` |
| 曲线核心 + adapter | 已部署 | SUN/MOON token、curve、`TestnetUsdcAdapter` 均在 Base Sepolia |
| Hook 地址预检 | 已通过 | `HOOK_SALT=0x...22b9`，预测地址低 14 位权限 bit 为 `204` |
| Hook 部署 | 已广播成功 | `HOOK_DEPLOYED=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc` |
| Hook 绑定 | 已广播成功 | adapter 和 `SunCurve.moonAMM` 已指向 Hook |
| `MOON/USDC` 池白名单 | 已广播成功 | `allowedMoonPools(poolId)=true` |
| `MOON/USDC` 池初始化 | 已广播成功 | `slot0.tick=276300`，初始价格约 `1 MOON ~= 1.0024 USDC` |
| 测试资产 + Permit2 | 已完成 | 测试账户具备小额演练资产和授权 |
| 小额流动性 | 已广播成功 | Position NFT `22355` 归属测试账户 |
| 小额 swap | 已广播成功 | `0.1 USDC -> MOON` 路径跑通 |
| 前端只读读取 | 已完成 | SUN 价格、MOON 价格、Hook/Adapter/Position 状态可视化 |

## 当前测试网固定记录

```text
network=Base Sepolia
chainId=84532
rpc=https://sepolia.base.org

HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
PROTOCOL_BUDGET_ADDRESS=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
DEPLOYER_ADDRESS=0x2F6E887c6058deE520f9468a1022E3480A6334D3

USDC=0x036CbD53842c5426634e7929541eC2318f3dCF7e
SUN_TOKEN=0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE=0x7f4296686917Be97E826DC790c367d93585A32c3
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc

POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
STATE_VIEW=0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
POSITION_MANAGER=0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80
UNIVERSAL_ROUTER=0x492E6456D9528771018DeB9E87ef7750EF184104
PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3

MOON_USDC_POOL_ID=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
MOON_USDC_POSITION_TOKEN_ID=22355
```

## 成功交易

```text
CREATE2_DEPLOYER_TX=0x87c9033101907c8e24aa13714154a212431a677837027191b023c00e70909596
HOOK_DEPLOY_TX=0x376baf6403018674a6b61bc4b84324e13fc7fafcb8c1970c8f15b06215e59e17
HOOK_BINDING_ADAPTER_TX=0x1319e675384b1e014debdb806a27915797bbd0cf8da9e253f04b1cc643ef97c4
HOOK_BINDING_SUN_CURVE_TX=0x6a6154f5e075f4b6d0975c4b60e1d517885adccb4577eb678134f4cc3966ed7c
MOON_USDC_ALLOWLIST_TX=0x9f219d37f1a72dc6229df79217ed953f1e6ff01ed1f4d958854fe432616ed325
MOON_USDC_INITIALIZE_TX=0x72c93bb0a5bdb540b2e696eaff50614e4571cfe1dbe3bb64494ec9719cdc8310
TINY_MOON_USDC_LIQUIDITY_TX=0x99c69749bbd9199ac7476f8d0175d2f3a651b81d97a97a607e13ca2b5168517b
TINY_MOON_USDC_SWAP_TX=0x61744130044a25395399db900c542872fe8c887057025a8d6b86bc0c71aeebaa
```

## 测试网验证到的能力

- Hook 可以部署到满足 Uniswap v4 权限 bit 的地址。
- Hook 可以被绑定到 adapter 和 `SunCurve.moonAMM`。
- Hook 可以只允许指定 `MOON/USDC` pool，避免无控制的任意池接入。
- `MOON/USDC` pool 可以被初始化并读取 `slot0`。
- 小额流动性和小额 swap 可以在 Base Sepolia 跑通。
- 前端可以只读展示链上价格、Hook 状态、Adapter 状态和 Position NFT。
- 测试流程里每次广播前都有 dry-run / 预检 / 用户明确批准。

## 没有验证的内容

这些内容没有在测试网演练中被证明，不能假设已经安全：

- 主网真实 USDC 资金流。
- 大额流动性、大额 swap、极端滑点和价格冲击。
- 恶意 MEV、抢跑、夹子交易和低流动性价格操纵。
- 多钱包、多权限、多签治理流程。
- 主网正式 adapter 的真实兑换路径和失败处理。
- 长时间运行下的监控、暂停、恢复和应急提款。
- 第三方安全审计。
- 法律、合规、税务、用户协议和地区限制。

## 主网前风险清单

### 1. 权限与钱包风险

| 检查项 | 当前状态 | 主网前要求 |
| --- | --- | --- |
| 部署钱包 | 测试钱包可用 | 主网必须换成全新部署钱包，不复用测试私钥 |
| Hook owner | 测试管理员钱包 | 主网上线配置完成后应放弃管理权；旧测试网 Hook 不支持 renounce，本地新版统一 Hook 已支持，主网前仍需 review |
| Protocol budget | 测试预算钱包 | 主网唯一权益是接收协议经费；不得拥有 owner、pause、adapter、CREATE2、白名单、部署或治理权限 |
| Pause 权限 | 测试网已可读 | 如果坚持上线后无管理员，暂停权限也必须放弃或改成上线前临时权限 |
| SUN/MOON 自由转账 | 新方向已确认 | 不再从 token 层禁止市场自发 AMM；前端和文档必须区分协议支持池与第三方池 |
| `SUN/USDC` v4 Hook 池 | 本地统一 Hook 已覆盖 2% USDC 方向 | 主网前仍需与 MOON/USDC 一起 review、重挖 salt 和 fork dry-run |
| `MOON/USDC` v4 Hook 池 | 测试网已跑通旧版 5% 方向；本地统一 Hook 已覆盖新版 5% USDC 方向 | 主网前仍需与 SUN/USDC 一起 review、重挖 salt 和 fork dry-run |
| 地址确认 | 测试网已记录 | 主网所有地址必须重新生成和复核，不能照抄测试网地址 |

停止条件：

```text
任何主网私钥出现在聊天、文档、代码、截图或命令历史中，立即停止。
```

### 2. 合约与 Hook 风险

| 风险 | 说明 | 主网前动作 |
| --- | --- | --- |
| Hook 费用逻辑 | swap 过程中涉及 Hook fee 和 return delta | 增加极端路径测试、失败路径测试和审计 |
| 池白名单 | 只允许指定 pool 是保护点 | 主网前必须复核 poolId 由正式 PoolKey 算出 |
| 回调权限 | Uniswap v4 Hook callback 权限依赖地址低位 | 主网 CREATE2 salt 必须重新挖、重新 dry-run |
| 重入/外部调用 | adapter / router / token 交互可能引入风险 | 做安全审计和模糊测试 |
| 升级不可逆 | 已部署合约可能无法轻易修正 | 主网前先确定是否需要可暂停、可替换或迁移方案 |

### 3. Adapter 与 USDC 风险

当前 `TestnetUsdcAdapter` 是测试网 adapter，不应默认作为主网 adapter。2026-05-16 新方向下，正式方案应优先考虑统一 USDC 费用 Hook：`SUN/USDC` 收 `2% USDC`、`MOON/USDC` 收 `5% USDC`，adapter 只作为非 USDC 误调用防呆或后续扩展，不应在第一阶段启用任意非 USDC route。

主网前必须决定：

- 正式 adapter 是否继续存在。
- 如果存在，使用什么真实 router / swap path。
- 非 USDC 手续费资产如何转换成 USDC。
- router 失败时 Hook 如何处理。
- 最小输出、滑点、deadline、allowlist 如何设置。
- adapter 是否需要单独审计。

停止条件：

```text
正式 adapter 路径、滑点和失败处理没定稿前，不允许主网部署。
```

### 4. 流动性与价格风险

测试网只做了极小额演练：

```text
liquidity=1 USDC + 1 MOON
swap=0.1 USDC -> MOON
```

主网前需要补：

- 初始流动性规模方案。
- 首池价格设定依据。
- SUN 初始铸造价、当前曲线价和 AMM 市场价的展示规则。
- SUN/MOON 自由转账后，第三方 AMM 池价格与协议曲线价格不一致时的风险提示。
- `SUN/USDC` v4 Hook 池初始流动性、初始价格和 2% USDC 费用验证。
- `MOON/USDC` v4 Hook 池初始流动性、初始价格和 5% USDC 费用验证。
- 第三方池不触发项目费用、不注入 `SunCurve`、不代表协议支持路径的提示规则。
- 大额交易滑点限制。
- 流动性撤出权限和应急处理。

### 5. 前端交易风险

当前前端是只读页，安全边界比较清楚：

```text
READ_ONLY_MODE=true
sendTx() throws Base Sepolia readonly mode
inputs disabled
buttons disabled
```

打开真实交易前必须补：

- 钱包连接必须明确显示网络、合约地址和交易动作。
- 每次 mint / burn / swap 前显示费用、最小收到、滑点和失败后果。
- 禁止自动切换到主网或未知 RPC。
- 防止把 Base Sepolia 地址误用于 Base 主网。
- 前端 ABI 和合约地址必须来自同一份正式配置。
- 上线前做桌面和手机端完整验收。

### 6. 测试与审计风险

当前最新全量 Foundry 记录：

```text
forge test --threads 1 --isolate
259 passed, 0 failed
```

主网前还需要：

- 补充 mainnet fork dry-run。
- 补充 fuzz / invariant 测试。
- 补充失败路径和边界金额测试。
- 补充真实 USDC 小数位、Permit2、Universal Router 的集成测试。
- 至少一次独立安全审计或外部代码 review。
- 所有部署脚本必须有 mainnet chainId 防误操作保护和人工确认变量。

### 7. 运营、法律与用户风险

主网前还需要明确：

- 这是不是公开产品、封闭测试、还是内部演示。
- 哪些地区用户不能参与。
- 是否涉及代币发行、交易、收益描述或营销承诺。
- 网站文案是否避免投资建议和收益承诺。
- 出现漏洞、价格异常、资金错误时如何公告和处理。

## 主网前 Gate

只有下面所有 Gate 都完成，才允许进入“主网部署草案”阶段。

| Gate | 要求 | 当前状态 |
| --- | --- | --- |
| Gate A | Base Sepolia 演练总结完成 | 已完成本文档 |
| Gate B | 正式主网地址、角色钱包方案确定 | 普通钱包方案和正式参数模板已创建，四个角色钱包公开地址已填写，仍需最终复核；正式合约地址仍未完成 |
| Gate C | 正式 Hook/adapter 方案确定 | 2026-05-16 改为统一 USDC 费用方向：`SUN/USDC` 2%、`MOON/USDC` 5%；统一 Hook、CREATE2 本地预演和 poolId 本地计算测试已完成；旧 `Direct-USDC-only` 草图仍需重新 review |
| Gate D | 主网上线后最小权限与放弃管理权方案完成 | 文档已更新为 SUN/MOON 自由转账、项目支持指定 v4 Hook 池收费；统一 Hook 和 renounce 本地专项测试已完成，主网参数、fork dry-run、外部 review 未完成 |
| Gate E | mainnet fork 全流程 dry-run | 未完成 |
| Gate F | 安全审计 / 外部 review | 未完成 |
| Gate G | 前端交易模式验收 | 未完成 |
| Gate H | 应急暂停和恢复预案 | 未完成 |
| Gate I | 用户协议、风险提示、合规检查 | 未完成 |

## 给非技术 owner 的决策说明

现在可以做的事：

- 继续完善测试网前端。
- 继续写文档和风险清单。
- 继续做本地 / fork / Base Sepolia 小额测试。
- 继续设计 `SUN/USDC` 2% 和 `MOON/USDC` 5% 的统一 v4 Hook 池方案。
- 准备主网前普通钱包角色方案和正式参数公开地址填表，但不要发私钥。

现在不该做的事：

- 不部署 Base 主网。
- 不接真实资金。
- 不打开前端真实交易按钮。
- 不把测试网地址当成主网地址。
- 不复用测试钱包做主网管理钱包。

## 下一步建议

下一步不是主网广播。建议按下面顺序推进：

1. 先确认统一 v4 Hook 代码方案：SUN/MOON 自由转账，`SUN/USDC` 收 `2% USDC`，`MOON/USDC` 收 `5% USDC`。
2. 解决 Hook owner 可放弃问题，配置完成后必须能 `renounceOwnership()` 或进入等效不可管理状态。
3. 人工 review `DirectUsdcOnlyAdapter` 和 `PrepareBaseMainnetDirectUsdcOnlyAdapter`，按新方向确认它只作为 USDC 防呆基础，不启用非 USDC 手续费路由。
4. 准备并测试 `PROTOCOL_BUDGET_WALLET`，只记录公开地址；它唯一权益是接收协议经费，不赋予其他权限。
5. 增加 mainnet fork dry-run 脚本，但默认不广播。
6. 准备外部安全 review 清单。
