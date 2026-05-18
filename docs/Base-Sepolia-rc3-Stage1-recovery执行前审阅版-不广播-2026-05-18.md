# Base Sepolia rc3 Stage 1 recovery 执行前审阅版 - 不广播 - 2026-05-18

本文只给 owner 人工审阅。当前不广播、不部署、不使用真实资金、不需要私钥、不包含 `--private-key`、不包含 Base 主网。

## 1. 当前结论

原 Stage 1 12 笔执行在浏览器钱包处中断，但 Base Sepolia 链上已经确认前 2 笔完成。

已完成：

```text
SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
```

因此不能重跑原 12 笔脚本。否则会从 nonce 18 开始部署第二套 SUN/SunCurve，造成地址混乱。

## 2. recovery 只允许做什么

如果未来 owner 另行批准真实 Base Sepolia 测试网 recovery 执行，只允许补剩余 10 笔 Stage 1 测试网交易：

```text
1. 部署 MOON Token
2. 部署 MoonCurve
3. 部署 Create2HookDeployer
4. 设置 SUN minter = 已部署的 SunCurve
5. 设置 SunCurve.moonCurve = 新部署的 MoonCurve
6. 设置 MOON minter = 新部署的 MoonCurve
7. 转移 SUN owner 到测试网管理员钱包
8. 转移 SunCurve owner 到测试网管理员钱包
9. 转移 MOON owner 到测试网管理员钱包
10. 转移 MoonCurve owner 到测试网管理员钱包
```

不允许包含：

```text
Stage 2
Stage 3
Hook 部署
建池
加流动性
swap
renounce
Base 主网
真实资金
私钥、助记词、恢复词
--private-key
```

## 3. 最新只读复核结果

2026-05-18 已重新跑 recovery 只读检查。

关键结果：

```text
chainId=84532
executeRequested=false
privateKeyPresent=false
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
remainingTransactionsPlanned=10
stage1CoreDeployer=0x2F6E887c6058deE520f9468a1022E3480A6334D3
stage1CoreDeployerNonce=18
expectedRecoveryNonce=18
recoveryNonceMatches=true
partialStateReady=true
remainingAddressCollision=false
```

剩余 3 个新合约预测地址：

```text
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
```

只读检查显示这些地址当前没有代码。本轮没有广播。

## 4. 下一步

下一步只能由 owner 决定是否进入真正 recovery 广播前最终人工批准。

如果没有新的明确批准，继续只读检查和文档整理；不执行交易。
