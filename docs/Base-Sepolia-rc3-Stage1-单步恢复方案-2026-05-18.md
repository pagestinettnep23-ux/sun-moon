# Base Sepolia rc3 Stage 1 单步恢复方案 - 2026-05-18

本文记录为什么 Stage 1 浏览器钱包执行没有一次跑完，以及新的解决方案。

## 1. 结论

这次不是合约交易失败。

问题出在执行方式：`forge --browser` 让浏览器钱包连续签多笔交易时，在当前环境里只成功推出第一笔，后面的交易队列没有继续稳定弹出/确认，命令就会卡住或被中断。

所以不要再用一个命令连续推剩余 9 笔。新方案改成：

```text
一次命令只准备一笔交易。
钱包只弹一次确认。
每完成一笔，就做一次只读复核。
```

## 2. 已看到的证据

第一次 Stage 1 执行后，链上只完成前 2 笔：

```text
SUN_TOKEN=0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
SUN_CURVE=0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
SEPOLIA_DEPLOYER nonce=18
```

recovery 10 笔执行后，链上只完成 recovery 的第 1 笔：

```text
MOON_TOKEN=0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
TX=0x8b5d7b459c9eaa2d5e25236749d96e498a97a8407f3bd6c8e8556ecfce237e31
SEPOLIA_DEPLOYER nonce=19
```

当前仍未完成：

```text
MOON_CURVE code=false
CREATE2_HOOK_DEPLOYER code=false
SUN minter=0x0000000000000000000000000000000000000000
SunCurve.moonCurve=0x0000000000000000000000000000000000000000
MOON minter=0x0000000000000000000000000000000000000000
```

这说明交易本身可以成功，但连续多笔的浏览器钱包流程不稳定。

## 3. 新增脚本

新增：

```text
script/PrepareBaseSepoliaRc3Stage1SingleStepDraft.s.sol
```

它只做一件事：根据 `BASE_SEPOLIA_RC3_STAGE1_SINGLE_STEP` 选择 1 到 9 的某一步，并且只调用一次 `vm.broadcast(...)`。

安全限制：

```text
拒绝 Base 主网
拒绝 PRIVATE_KEY 环境变量
默认不执行
必须显式确认 Base Sepolia single-step
必须匹配预期 nonce
必须匹配当前链上状态
每次只允许一个 step
```

## 4. 剩余 9 步

| Step | 预期 nonce | 只做这一件事 |
|---:|---:|---|
| 1 | 19 | 部署 `MoonCurve` |
| 2 | 20 | 部署 `Create2HookDeployer` |
| 3 | 21 | `SUN.setMinter(SunCurve)` |
| 4 | 22 | `SunCurve.setMoonCurve(MoonCurve)` |
| 5 | 23 | `MOON.setMinter(MoonCurve)` |
| 6 | 24 | `SUN.transferOwnership(admin)` |
| 7 | 25 | `SunCurve.transferOwnership(admin)` |
| 8 | 26 | `MOON.transferOwnership(admin)` |
| 9 | 27 | `MoonCurve.transferOwnership(admin)` |

## 5. 本轮验证结果

本地专项测试通过：

```text
forge test --match-contract BaseSepoliaRc3Stage1SingleStepDraftTest --threads 1 --isolate
6 passed, 0 failed
```

Base Sepolia 只读预检通过，未广播：

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
ready=true
```

## 6. 本轮没有做什么

```text
没有广播
没有部署新合约
没有使用私钥
没有使用 --private-key
没有执行 Stage 2
没有执行 Stage 3
没有碰 Base 主网
没有使用真实资金
```

## 7. 下一步

下一步只能由 owner 决定是否进入 `Step 1` 的单步测试网广播。

如果批准，也只准备 `Step 1: 部署 MoonCurve` 这一笔 Base Sepolia 测试网交易；不包含 Stage 2、Stage 3、Base 主网、真实资金或私钥。
