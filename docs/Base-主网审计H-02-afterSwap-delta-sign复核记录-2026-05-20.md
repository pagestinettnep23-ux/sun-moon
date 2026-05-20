# Base 主网审计 H-02 afterSwap delta sign 复核记录 - 2026-05-20

本文记录对审计项 `H-02: afterSwap delta sign` 的复核过程和当前结论。

这不是 Base 主网部署批准，也不是广播记录。

```text
不执行 Base 主网交易
不使用真实资金
不要求或记录私钥、助记词、恢复词
不使用 --private-key
不广播
```

## 1. 审计问题摘要

审计关注点：

```text
BaseSunMoonUsdcFeeV4Hook.afterSwap 返回正 delta。
担心正 delta 的符号方向错误，可能导致用户被双重收费或 Hook 收费路径异常。
```

当前复核判断：

```text
暂不按 confirmed high 处理。
```

原因：

```text
Uniswap v4 hook return delta 中，正 delta 表示 hook 在 unspecified token 上拿取资产。
当前 Hook 在 afterSwap 中配合 poolManager.take(...) 把 USDC 收到 Hook，再立即路由到 SunCurve 和 protocolBudget。
这符合 v4 自定义会计里的正常收费路径。
```

## 2. 本次处理原则

本次没有先改合约代码，而是先补测试验证。

```text
未修改 contracts/hooks/base/BaseSunMoonUsdcFeeV4Hook.sol
未修改任何生产合约
仅修改 test/hooks/base/BaseSunMoonUsdcFeeV4Hook.t.sol
```

## 3. 新增测试场景

新增两个 exact-output 测试：

```text
testExactOutputBuySunWithUsdcInputChargesAfterSwapFeeOnce
testExactOutputBuyMoonWithUsdcInputChargesAfterSwapFeeOnce
```

覆盖场景：

```text
用户用 USDC 作为输入，exact output 买 SUN。
用户用 USDC 作为输入，exact output 买 MOON。
```

这些场景会走 afterSwap 收费路径，因为：

```text
exact output 时，用户指定的是输出 token 数量。
USDC 是输入 token，但在该 swap 语义下是 unspecified token。
Hook 在 afterSwap 里对 unspecified USDC 返回正 delta 并 poolManager.take(...)。
```

## 4. 测试检查内容

新增测试检查：

```text
用户确实收到 exact output 的 SUN 或 MOON。
SunCurve.curveReserve() 增加正确的注入费用。
protocolBudget 收到正确协议费用。
Hook 的 USDC 余额最终为 0。
用户实际 USDC 支出 = 基础 USDC 输入 + 单次 Hook fee。
swap 返回的 USDC delta 等于用户实际 USDC 支出。
```

其中费用比例仍保持原逻辑：

```text
SUN/USDC：2% USDC fee
1.5% -> SunCurve.injectUSDT()
0.5% -> protocolBudget

MOON/USDC：5% USDC fee
3% -> SunCurve.injectUSDT()
2% -> protocolBudget
```

## 5. 测试结果

已执行专项测试：

```powershell
forge test --match-path test\hooks\base\BaseSunMoonUsdcFeeV4Hook.t.sol -vvv
```

结果：

```text
20 passed
0 failed
0 skipped
```

已执行 Base Hook / CREATE2 / 部署预检小范围回归。为避免历史脚本测试受本机环境变量串扰，按文件逐个执行以下 10 个测试文件：

```text
test/hooks/base/BaseSunMoonUsdcFeeV4Hook.t.sol
test/hooks/base/BaseSunMoonUsdcFeeV4HookCreate2Rehearsal.t.sol
test/hooks/base/BaseV4HookAddressMiner.t.sol
test/hooks/base/Create2HookDeployer.t.sol
test/hooks/base/Create2HookDeployerRehearsal.t.sol
test/hooks/base/BaseDeploymentPreflight.t.sol
test/hooks/base/BaseSepoliaRc3SunMoonUsdcDryRunPreparation.t.sol
test/hooks/base/BaseMainnetCoreDeployDryRunPreparation.t.sol
test/hooks/base/BaseMainnetSunMoonUsdcHookSaltPreparation.t.sol
test/hooks/base/BaseMainnetSunMoonUsdcForkDryRunPreparation.t.sol
```

结果：

```text
84 passed
0 failed
0 skipped
```

说明：

```text
本次测试只在本地 Foundry 环境执行。
没有广播，没有执行 Base 主网交易，没有使用真实资金，没有使用或记录私钥。
```

## 6. 复核结论

当前结论：

```text
H-02 暂不确认为 confirmed high。
```

理由：

```text
新增 exact-output 测试覆盖了 USDC 输入买 SUN 和 USDC 输入买 MOON。
测试证明 afterSwap 正 delta + poolManager.take(...) 可以正确完成单次收费。
SunCurve 和 protocolBudget 收款正确。
Hook 最终不滞留 USDC。
用户没有出现双重收费。
```

## 7. 后续建议

```text
把本项标记为 disputed / not confirmed，附上新增测试和测试结果。
如果审计方仍坚持该项为 High，需要他们给出一个可复现的交易路径或失败断言。
在没有新复现路径前，不建议修改 BaseSunMoonUsdcFeeV4Hook 生产逻辑。
```

下一步建议：

```text
把 H-02 新增测试和本复核记录提交为一个单独 commit。
提交后再按需要创建新的审计复核 tag。
```
