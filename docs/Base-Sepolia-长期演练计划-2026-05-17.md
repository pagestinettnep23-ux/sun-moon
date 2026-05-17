# Base Sepolia 长期演练计划 - 2026-05-17

本文用于在没有预算做正式审计、也暂时跳过社区 review 的情况下，继续用 Base Sepolia 测试网做长期观察。它不是主网部署批准。

当前仍然：

```text
不部署 Base 主网
不广播 Base 主网交易
不接真实资金
不索要私钥
不把测试网成功当成主网安全
```

## 1. 目标

长期演练的目标不是“证明一定安全”，而是尽量暴露日常使用路径中的问题：

```text
SUN/MOON 自由转账是否一直正常
SunCurve mint / burn 是否稳定
MoonCurve mint / burn 是否稳定
SUN/USDC v4 Hook 池是否按 2% USDC 收费
MOON/USDC v4 Hook 池是否按 5% USDC 收费
Hook renounce 后配置是否永久锁定
前端是否能正确显示协议价格、市场价格和 Hook 状态
```

## 2. 建议持续时间

最低建议：

```text
14 天
```

更稳妥建议：

```text
30 天
```

原因：

```text
一天内只能证明脚本能跑通
两周可以覆盖多次手动交互、前端刷新、不同金额测试和异常排查
一个月更适合观察配置、文档、前端和用户流程是否长期一致
```

## 3. 每周节奏

第 1 周：

```text
只做小额测试网操作
确认基础路径都能完成
重点找明显报错、前端显示错误、交易 revert
```

第 2 周：

```text
重复相同路径，确认结果稳定
加入不同金额、不同顺序的操作
重点看手续费分配、曲线价格、池状态是否一致
```

第 3-4 周：

```text
只做低频复核
观察文档和前端是否仍然能按最新配置工作
整理所有问题，决定是否需要 rc4
```

## 4. 每次演练前检查

每次测试网操作前都要确认：

```text
网络是 Base Sepolia，不是 Base 主网
使用的是测试网地址，不是主网预测地址
只使用测试币，不使用真实资金
命令没有 --broadcast，除非 owner 明确批准“测试网广播”
命令没有 PRIVATE_KEY 粘贴在聊天里
```

如果出现以下情况，立即停止：

```text
任何人要求提供私钥、助记词或恢复词
任何脚本指向 Base mainnet 并准备广播
任何真实资金地址被当成测试资金使用
任何测试网地址被写成主网正式地址
```

## 5. 每次演练建议动作

基础动作：

```text
1. 用测试 USDC mint SUN
2. 自由转账 SUN
3. 用 SUN mint MOON
4. 自由转账 MOON
5. burn 少量 MOON 得到 SUN
6. burn 少量 SUN 得到测试 USDC
```

Hook 池动作：

```text
1. 检查 SUN/USDC 测试池是否存在
2. 检查 MOON/USDC 测试池是否存在
3. 用测试 USDC 小额 swap SUN
4. 用测试 USDC 小额 swap MOON
5. 复核 SUN/USDC 的 1.5% USDC 进入 SunCurve，0.5% 进入协议经费地址
6. 复核 MOON/USDC 的 3% USDC 进入 SunCurve，2% 进入协议经费地址
```

前端动作：

```text
1. 前端显示 Base Sepolia
2. 前端不显示 Base 主网执行按钮
3. 前端正确显示 SunCurve 协议价格
4. 前端正确显示 AMM 市场价格
5. 前端不把第三方池标成协议支持池
```

## 6. 每次必须记录

每次演练写一条记录：

```text
日期
测试网络
测试钱包公开地址
执行了哪些动作
交易 hash
是否成功
是否出现 revert
SUN/MOON 是否能自由转账
SunCurve reserve 前后变化
协议经费地址余额前后变化
前端是否显示正确
问题截图或错误信息
```

建议记录到：

```text
docs/演练记录-Base-Sepolia-长期-2026-05.md
```

## 7. 通过标准

至少连续满足：

```text
14 天内没有发现高危或无法解释的问题
全量 Foundry 测试保持 0 failed
fuzz / invariant 测试保持 0 failed
测试网小额路径可重复完成
前端显示没有混淆主网和测试网
所有发现的问题都已记录并处理
```

## 8. 不能通过的情况

只要出现这些情况之一，就不能进入下一阶段：

```text
SUN/MOON 转账异常
SunCurve reserve 与 USDC 余额不一致
MoonCurve sunReserve 与 SUN 余额不一致
Hook 收费比例错误
renounce 后还能改配置
前端把主网和测试网混淆
测试失败但没有解释
出现无法复现或无法解释的资金差异
```

## 9. 长期演练后的下一步

如果长期演练通过：

```text
整理测试网长期演练总结
创建新的本地候选版本，例如 rc4
重新跑 Slither 和全量测试
再次决定是否继续等正式审计 / 社区 review
仍然不自动进入主网
```

如果长期演练发现问题：

```text
暂停后续计划
先写问题记录
修复代码或文档
新增回归测试
重新创建候选版本
重新开始观察周期
```

## 10. Day 0 范围澄清

Base Sepolia 上已经完成过一轮历史 `MOON/USDC` 小额演练，但它主要验证的是旧版 `BaseMoonAmmFeeV4Hook` 路径。

当前 rc3 主网候选范围已经更新为：

```text
BaseSunMoonUsdcFeeV4Hook
SUN/USDC v4 Hook 池收 2% USDC
MOON/USDC v4 Hook 池收 5% USDC
SUN/MOON 都保持自由转账
市场可以自行创建第三方池，项目只支持指定 v4 Hook 池
```

所以长期演练要分清楚两件事：

```text
历史 Base Sepolia MOON/USDC 池可以继续作为旧路径观察样本
rc3 最新方案如果要做完整测试网观察，需要另起一轮 rc3 Base Sepolia 演练
```

Day 0 启动记录见：

```text
docs/演练记录-Base-Sepolia-长期-2026-05.md
```

rc3 dry-run 草案见：

```text
docs/Base-Sepolia-rc3-dry-run草案-2026-05-17.md
script/PrepareBaseSepoliaRc3SunMoonUsdcDryRun.s.sol
```

2026-05-18 已完成 Base Sepolia rc3 fork 只读 dry-run：

```text
chainId=84532
broadcastRequested=false
simulationOnly=true
script_result=Script ran successfully
mainnet_broadcast=false
testnet_broadcast=false
private_key_requested=false
```

## 11. 当前建议

在没有正式审计预算、也跳过社区 review 的前提下，建议至少做：

```text
14 天 Base Sepolia 长期演练
每周至少 2 次手动复核
每次复核都写记录
任何异常都先修复，不进入主网讨论
```
