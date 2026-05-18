# Base Sepolia rc3 Stage 1 recovery 真正执行命令审阅版 - 不广播 - 2026-05-18

本文根据 owner 已发送的完整批准语句准备。

本轮只准备命令审阅版，不运行命令，不广播交易，不接触主网，不使用真实资金，不需要私钥，不包含 `--private-key`。

## 1. owner 已批准的范围

owner 已在聊天中明确批准：

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

## 2. 本命令审阅版仍不做什么

本文档当前不执行任何交易。

本轮不做：

```text
不广播
不部署
不打开钱包签名
不使用真实资金
不执行 Stage 2
不执行 Stage 3
不执行 Base 主网
不记录私钥、助记词或恢复词
不使用 --private-key
```

## 3. recovery 执行前必须先跑的只读复查命令

真正执行前，应先跑这条只读复查命令。

它不会广播，因为：

```text
EXECUTE_BASE_SEPOLIA_RC3_STAGE1_RECOVERY=0
没有 --broadcast
PRIVATE_KEY 为空
```

命令：

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGE1_RECOVERY_DRAFT='1';
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE1_RECOVERY='0';
$env:PRIVATE_KEY='';
$env:BASE_SEPOLIA_RC3_STAGE1_RECOVERY_EXPECTED_NONCE='18';
forge script script/PrepareBaseSepoliaRc3Stage1RecoveryDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

只读复查必须看到：

```text
chainId=84532
executeRequested=false
privateKeyPresent=false
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
remainingTransactionsPlanned=10
stage1CoreDeployerNonce=18
expectedRecoveryNonce=18
recoveryNonceMatches=true
partialStateReady=true
remainingAddressCollision=false
```

如果任一项不一致，停止，不进入执行命令。

## 4. 未来真正 recovery 执行命令草案

只有在只读复查仍通过、owner 再次说“开始执行 recovery”之后，才允许运行下面这条命令。

这条命令使用浏览器钱包签名，不包含私钥，不包含 `--private-key`。

命令：

```powershell
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGE1_RECOVERY_DRAFT='1';
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE1_RECOVERY='1';
$env:PRIVATE_KEY='';
$env:BASE_SEPOLIA_RC3_STAGE1_RECOVERY_EXPECTED_NONCE='18';
forge script script/PrepareBaseSepoliaRc3Stage1RecoveryDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow --sender 0x2F6E887c6058deE520f9468a1022E3480A6334D3 --broadcast --browser --browser-port 9545
```

预期只会请求浏览器钱包签 10 笔 Base Sepolia 测试网交易。

## 5. 这 10 笔是什么

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

预计新地址：

```text
MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
MOON_CURVE=0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
CREATE2_HOOK_DEPLOYER=0x6E34D98e1925eaf6680941213E49741b8764DdfE
```

已有地址：

```text
SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
```

## 6. 停止条件

出现任何一种情况，立即停止：

```text
钱包显示不是 Base Sepolia
钱包显示 Base 主网
钱包要求导入、粘贴、输入私钥或助记词
命令里出现 --private-key
nonce 不是 18
脚本显示 remainingTransactionsPlanned 不是 10
脚本显示 remainingAddressCollision=true
脚本显示 partialStateReady=false
钱包签名数量明显不是 10 笔
出现 Stage 2、Stage 3、Hook、建池、加流动性、swap、renounce 字样
```

## 7. 执行后第一件事

如果未来 recovery 真正广播并完成，第一件事不是 Stage 2。

第一件事必须是只读复核：

```text
确认 MOON Token 有代码
确认 MoonCurve 有代码
确认 Create2HookDeployer 有代码
确认 SUN minter = SunCurve
确认 SunCurve.moonCurve = MoonCurve
确认 MOON minter = MoonCurve
确认 4 个核心合约 owner 都是测试网管理员钱包
确认 Create2HookDeployer owner 是测试网 Create2 owner
```

复核通过后，才允许讨论 Stage 2。
