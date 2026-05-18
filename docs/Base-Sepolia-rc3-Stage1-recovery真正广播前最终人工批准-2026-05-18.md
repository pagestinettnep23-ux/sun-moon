# Base Sepolia rc3 Stage 1 recovery 真正广播前最终人工批准 - 2026-05-18

本文是 owner 在决定是否执行 recovery 前阅读的最终人工批准页。

当前本文档本身不是广播命令，不会执行交易，不包含私钥，不包含 `--private-key`，不包含 Base 主网。

## 1. 为什么需要 recovery

原 Base Sepolia rc3 Stage 1 共 12 笔测试网交易。浏览器钱包执行中断后，链上确认前 2 笔已经完成：

```text
SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
```

因此不能重跑原来的 12 笔脚本。

recovery 的目的只是从当前 nonce 18 继续补完剩余 10 笔 Stage 1 测试网交易。

## 2. recovery 允许范围

如果 owner 未来明确批准，recovery 只允许执行以下 10 笔 Base Sepolia 测试网交易：

```text
1. 部署 MOON Token
2. 部署 MoonCurve
3. 部署 Create2HookDeployer
4. 设置 SUN minter = 已部署 SunCurve
5. 设置 SunCurve.moonCurve = 新部署 MoonCurve
6. 设置 MOON minter = 新部署 MoonCurve
7. 转移 SUN owner 到测试网管理员钱包
8. 转移 SunCurve owner 到测试网管理员钱包
9. 转移 MOON owner 到测试网管理员钱包
10. 转移 MoonCurve owner 到测试网管理员钱包
```

预计新部署地址：

```text
PREDICTED_MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
PREDICTED_MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
PREDICTED_CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
```

## 3. recovery 明确禁止范围

本次 recovery 不允许包含：

```text
Stage 2
Stage 3
Hook 部署
Hook 白名单
建池
加流动性
swap
renounce
Base 主网
真实资金
私钥、助记词、恢复词
--private-key
```

## 4. 最新只读检查

2026-05-18，已重新跑 Base Sepolia recovery 只读检查。

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

解释：

```text
网络是 Base Sepolia 测试网
当前没有广播
当前没有私钥
当前 nonce 正好是 recovery 需要的 18
已部署的 SUN/SunCurve 状态满足 recovery 条件
剩余 3 个新合约预测地址当前没有代码
```

## 5. owner 批准语句

如果 owner 决定允许进入 recovery 真正执行命令准备，请在聊天里发送完整批准语句：

```text
我批准只在 Base Sepolia 测试网执行 rc3 Stage 1 recovery 剩余 10 笔测试网交易。
不执行原 Stage 1 12 笔脚本。
不执行 Stage 2。
不执行 Stage 3。
不执行 Base 主网。
不使用真实资金。
不提供私钥、助记词或恢复词。
不使用 --private-key。
```

如果没有这段完整批准语句，下一步只能继续只读检查或文档整理，不能执行 recovery 广播。

## 6. 批准后仍要做什么

即使 owner 给出完整批准，下一步也不是直接乱跑。

下一步只能准备一份 recovery 真正执行命令审阅版，并再次确认：

```text
只使用 Base Sepolia
只覆盖剩余 10 笔
使用浏览器钱包签名
不包含私钥
不包含 --private-key
不包含 Stage 2/3
不包含 Base 主网
不包含真实资金
```

owner 看懂并确认后，才可能进入实际浏览器钱包签名步骤。
