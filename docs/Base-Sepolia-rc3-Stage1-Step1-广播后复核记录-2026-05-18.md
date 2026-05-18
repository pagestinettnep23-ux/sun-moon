# Base Sepolia rc3 Stage 1 Step 1 广播后复核记录 - 2026-05-18

本文记录 `Step 1` 的测试网执行和广播后只读复核结果。

## 1. 本次批准范围

owner 批准范围：

```text
只在 Base Sepolia 测试网执行 rc3 Stage 1 Step 1 的 1 笔测试网交易：部署 MoonCurve。
不执行 Step 2-9。
不执行 Stage 2。
不执行 Stage 3。
不执行 Base 主网。
不使用真实资金。
不提供私钥、助记词或恢复词。
不使用 --private-key。
```

实际执行也只覆盖 Step 1。

## 2. 执行结果

```text
网络：Base Sepolia
chainId：84532
Step：1
动作：部署 MoonCurve
执行钱包公开地址：0x2F6E887c6058deE520f9468a1022E3480A6334D3
交易哈希：0xe832e024dafd43dff14f2068dd162d1a78a4ed992ad517f7255d5e4925bba1fa
交易状态：success
区块号：41667450
合约地址：0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
gasUsed：1919043
```

Foundry 输出：

```text
ONCHAIN EXECUTION COMPLETE & SUCCESSFUL
```

## 3. 广播后只读复核

已完成只读复核：

```text
MoonCurve code：已存在
MoonCurve.owner()：0x2F6E887c6058deE520f9468a1022E3480A6334D3
SEPOLIA_DEPLOYER nonce：20
Create2HookDeployer code：0x
```

说明：

```text
MoonCurve 已部署成功。
MoonCurve owner 仍是 Stage 1 测试网执行钱包。
nonce 已从 19 变成 20，符合只执行 1 笔交易的预期。
Create2HookDeployer 仍未部署，说明 Step 2 没有执行。
```

## 4. Step 2 只读预检

广播后额外跑了 Step 2 只读预检，只读，不广播。

结果：

```text
step=2
executeRequested=false
privateKeyPresent=false
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
stage1CoreDeployerNonce=20
expectedNonce=20
nonceMatches=true
moonCurveHasCode=true
create2HookDeployerHasCode=false
moonCurveOwner=0x2F6E887c6058deE520f9468a1022E3480A6334D3
ready=true
```

这只说明 Step 2 已具备只读预检条件，不等于批准 Step 2。

## 5. 本次没有做什么

```text
没有执行 Step 2-9
没有执行 Stage 2
没有执行 Stage 3
没有部署 Hook
没有建池
没有加流动性
没有 swap
没有 renounce
没有碰 Base 主网
没有使用真实资金
没有使用私钥
没有使用 --private-key
```

## 6. 下一步

下一步只能准备 `Step 2` 的单步执行命令审阅版，不广播。

Step 2 只会是：

```text
部署 Create2HookDeployer
预期 nonce：20
预计钱包确认：1 次
```

Step 2 必须由 owner 再单独批准，不能因为 Step 1 成功就自动执行。
