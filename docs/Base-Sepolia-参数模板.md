# Base Sepolia 参数模板

更新日期：2026-05-14

本模板用于收集 Base Sepolia 受控演练所需参数。不要在这里填写私钥、助记词、完整 RPC key 或任何真实资金相关敏感信息。

## 1. 官方公开参数

这些参数已在 2026-05-14 按公开文档复核一次。广播前仍需再次打开官方来源二次复核。

来源：

- Uniswap v4 deployments：`https://docs.uniswap.org/contracts/v4/deployments`
- Circle USDC contract addresses：`https://developers.circle.com/stablecoins/usdc-contract-addresses`

```text
BASE_CHAIN_ID=84532
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
POSITION_MANAGER=0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80
STATE_VIEW=0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
QUOTER=0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa
UNIVERSAL_ROUTER=0x492E6456D9528771018DeB9E87ef7750EF184104
USDC_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
```

说明：

- `POOL_MANAGER` 是 Hook 构造参数和预检脚本当前必用地址。
- `POSITION_MANAGER`、`UNIVERSAL_ROUTER` 当前用于参数复核和后续池子/路由准备。
- `STATE_VIEW`、`QUOTER` 是 Uniswap v4 查询/报价工具地址，当前先记录，暂不作为 Hook 构造参数。
- `USDC_TOKEN` 是 Base Sepolia 测试 USDC，不是 Base 主网 USDC。

## 2. 项目待填写参数

以下参数不能用零地址。填写后需要至少两轮人工复核。

新手准备钱包地址前，先看 `docs/Base-Sepolia-地址准备说明.md`。这里只填写公开地址，不填写私钥、助记词或完整 RPC key。

```text
MOON_TOKEN=
SUN_CURVE=
PROTOCOL_BUDGET_ADDRESS=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
SWAP_ADAPTER=
HOOK_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
DEPLOYER_ADDRESS=0x2F6E887c6058deE520f9468a1022E3480A6334D3
CREATE2_DEPLOYER=0xE5Df76A1DF2e959C70c8b7591754a3a2a542Fb6D
```

2026-05-14 已收到并校验以上 3 个公开测试钱包地址：

- `HOOK_OWNER`：checksum 格式通过。
- `PROTOCOL_BUDGET_ADDRESS`：checksum 格式通过。
- `DEPLOYER_ADDRESS`：checksum 格式通过。

`CREATE2_DEPLOYER` 已由第一次 Base Sepolia 小额广播固定，owner 已链上复核。选择说明见 `docs/Base-Sepolia-CREATE2-Deployer选择说明.md`，小额广播分步草案见 `docs/Base-Sepolia-小额广播草案清单.md`。`MOON_TOKEN`、`SUN_CURVE` 和 `SWAP_ADAPTER` 要等第二次测试网部署后才会产生。

## 3. CREATE2 输出参数

以下参数由 `script/FindBaseMoonAmmFeeV4HookSalt.s.sol` 生成，不手填猜测。

```text
HOOK_SALT=
PREDICTED_HOOK=
```

要求：

- `PREDICTED_HOOK` 非零。
- `PREDICTED_HOOK` 低 14 位权限 bit 必须等于 `204`。
- `HOOK_SALT`、`PREDICTED_HOOK` 和构造参数必须同时写入演练记录。

## 4. 初始策略占位

```text
SUN_FIRST_LIQUIDITY_WALLET=
SUN_POOL_ALLOWLIST=
MOON_POOL_ALLOWLIST=
ADAPTER_TOKEN_ALLOWLIST=
ADAPTER_ROUTER_ALLOWLIST=
MIN_USDT_OUT_SOURCE=script explicit input; must be non-zero
```

当前建议：

- SUN 首次加池钱包：主网新决策已取消该角色；历史测试网模板不再用于主网。
- SUN 池白名单初期只允许受控测试池。
- MOON 池白名单初期只允许 `MOON/USDC` 测试池。
- adapter token allowlist 初期只允许 USDC 直通和一个受控 Mock fee asset。
- adapter router allowlist 初期只允许 `MockUsdcSwapRouter` 或受控测试 router。
- `minUSDTOut` 初期由演练脚本显式传入，禁止为 0。

## 5. 本地命令模板

复跑本地状态：

```powershell
forge test
forge test --match-contract TestnetUsdcAdapterTest
forge test --match-contract BaseSepoliaAdapterRehearsalTest
forge test --match-contract BaseSepoliaCreate2DeployerPreparationTest
forge script script/RehearseBaseSepoliaAdapter.s.sol
forge script script/PrepareBaseSepoliaCreate2Deployer.s.sol
```

拿到项目地址后，生成和校验 Hook 参数：

```powershell
forge script script/FindBaseMoonAmmFeeV4HookSalt.s.sol
forge script script/CheckBaseSepoliaDeploymentParams.s.sol
```

## 6. 当前停止点

如果以下任一参数缺失，不进入测试网广播：

- `MOON_TOKEN`
- `SUN_CURVE`
- `SWAP_ADAPTER`
- `HOOK_SALT`
- `PREDICTED_HOOK`
