# Base Sepolia rc3 Stage 1 Step 1 单步执行命令审阅版 - 不广播 - 2026-05-18

本文只准备 `Step 1` 的命令审阅版。

本轮没有广播、没有部署、没有使用私钥、没有 `--private-key`、没有 Stage 2/3、没有 Base 主网、没有真实资金。

## 1. Step 1 只做什么

```text
网络：Base Sepolia 测试网
Step：1
动作：部署 MoonCurve
预计只需要钱包确认：1 次
执行钱包公开地址：0x2F6E887c6058deE520f9468a1022E3480A6334D3
预期 nonce：19
目标 MoonCurve 地址：0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
```

## 2. Step 1 不做什么

```text
不执行 Step 2-9
不部署 Create2HookDeployer
不设置 minter
不转移 owner
不执行 Stage 2
不执行 Stage 3
不部署 Hook
不建池
不加流动性
不 swap
不 renounce
不碰 Base 主网
不使用真实资金
不要求私钥
不使用 --private-key
```

## 3. 最新只读预检结果

已重新跑 Step 1 只读预检，结果通过：

```text
chainId=84532
step=1
executeRequested=false
privateKeyPresent=false
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
stage1CoreDeployerNonce=19
expectedNonce=19
nonceMatches=true
moonCurveHasCode=false
create2HookDeployerHasCode=false
sunTokenOwner=0x2F6E887c6058deE520f9468a1022E3480A6334D3
sunCurveOwner=0x2F6E887c6058deE520f9468a1022E3480A6334D3
moonTokenOwner=0x2F6E887c6058deE520f9468a1022E3480A6334D3
sunTokenMinter=0x0000000000000000000000000000000000000000
sunCurveMoonCurve=0x0000000000000000000000000000000000000000
moonTokenMinter=0x0000000000000000000000000000000000000000
ready=true
```

## 4. 已运行的只读命令

这条已经运行过，只读，不广播：

```powershell
$env:BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP='1'
$env:BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP_EXPECTED_NONCE='19'
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP='1'
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP='0'
$env:PRIVATE_KEY=''
forge script script/PrepareBaseSepoliaRc3Stage1SingleStepDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow
```

## 5. 未来真正执行命令外形

下面只是审阅版，本轮不运行。

它不包含私钥，也不包含 `--private-key`。如果未来 owner 单独批准 Step 1，才可以把 `EXECUTE_BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP` 从 `0` 改成 `1`，并使用浏览器钱包弹窗确认这一笔测试网交易。

```powershell
$env:BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP='1'
$env:BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP_EXPECTED_NONCE='19'
$env:CONFIRM_BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP='1'
$env:EXECUTE_BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP='1'
$env:PRIVATE_KEY=''
forge script script/PrepareBaseSepoliaRc3Stage1SingleStepDraft.s.sol --rpc-url https://sepolia.base.org --rpc-timeout 120 --slow --sender 0x2F6E887c6058deE520f9468a1022E3480A6334D3 --broadcast --browser --browser-port 9545
```

## 6. 如果 Step 1 未来成功

成功后第一件事不是继续 Step 2，而是只读复核：

```text
确认 MoonCurve 地址有代码
确认 MoonCurve.owner() 仍是 0x2F6E887c6058deE520f9468a1022E3480A6334D3
确认 SEPOLIA_DEPLOYER nonce 变成 20
确认 Create2HookDeployer 仍未部署
```

## 7. 下一步

下一步由 owner 决定是否批准 `Step 1` 这一笔 Base Sepolia 测试网交易。

如果批准，建议使用这句简单批准语：

```text
我批准只在 Base Sepolia 测试网执行 rc3 Stage 1 Step 1 的 1 笔测试网交易：部署 MoonCurve。
不执行 Step 2-9。
不执行 Stage 2。
不执行 Stage 3。
不执行 Base 主网。
不使用真实资金。
不提供私钥、助记词或恢复词。
不使用 --private-key。
```
