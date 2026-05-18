# Base Sepolia rc3 Stage 3 测试网广播草案 - 2026-05-18

本文只整理 Stage 3 的测试网广播草案，方便人工理解和复核。

这不是广播批准，也不是主网计划。

固定边界：

```text
不加 --broadcast
当前不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
不把预测地址当成已部署地址
```

## 1. Stage 3 是什么

Stage 3 只有 1 笔交易：

```text
Hook.renounceOwnership()
```

小白理解：

```text
这一步是放弃 Hook 管理权。
成功后 Hook owner 会变成 0x0000000000000000000000000000000000000000。
之后管理员不能再修改 Hook 白名单、协议经费地址或暂停状态。
```

## 2. Stage 3 为什么危险

`renounceOwnership()` 基本是不可逆动作。

执行后不能再做：

```text
不能再新增 SUN/USDC poolId 白名单
不能再新增 MOON/USDC poolId 白名单
不能再取消 poolId 白名单
不能再修改 protocolBudget
不能再 setPaused(true)
不能再 setPaused(false)
不能再 transferOwnership
```

所以 Stage 3 只能在 Stage 1 和 Stage 2 全部复核通过后考虑。

## 3. Stage 3 前置条件

Stage 3 只能在 Stage 2 完成并复核通过后考虑。

必须先确认：

- [ ] Stage 1 后复核清单全部通过。
- [ ] Stage 2 后复核清单全部通过。
- [ ] Hook code 不是 `0x`。
- [ ] Hook owner 仍是测试网管理员钱包。
- [ ] Hook `protocolBudget` 正确。
- [ ] Hook `paused=false`。
- [ ] `SunCurve.moonAMM` 已等于 Hook。
- [ ] `allowedSunUsdcPools(SUN_USDC_POOL_ID)=true`。
- [ ] `allowedMoonUsdcPools(MOON_USDC_POOL_ID)=true`。
- [ ] `SUN/USDC` 已初始化到目标价格。
- [ ] `MOON/USDC` 已初始化到目标价格。
- [ ] 两个池仍未添加流动性。
- [ ] 没有任何未知池被误认为项目支持池。

如果任一项不通过，不能进入 Stage 3。

## 4. 当前 Stage 3 公开参数

| 项目 | 地址 |
| --- | --- |
| Stage 3 renounce owner | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` |
| 预测 Hook | `0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc` |

说明：

```text
这些是 Base Sepolia 测试网参数，不是 Base 主网参数。
预测 Hook 不是已经部署地址。
如果 Stage 1 或 Stage 2 任何地址变化，Stage 3 也必须更新。
```

## 5. Stage 3 的 1 笔交易

| 顺序 | 操作 | 谁执行 | 小白解释 |
| ---: | --- | --- | --- |
| 1 | `Hook.renounceOwnership()` | Stage 3 renounce owner | 把 Hook 管理权放弃到零地址 |

Stage 3 完成后，应该看到：

```text
Hook.owner = 0x0000000000000000000000000000000000000000
allowedSunUsdcPools(SUN_USDC_POOL_ID) = true
allowedMoonUsdcPools(MOON_USDC_POOL_ID) = true
protocolBudget 仍是原测试网协议经费地址
paused 仍是 false
```

## 6. Stage 3 前只读检查命令

在任何真实 Stage 3 广播前，先只读检查：

```powershell
cast call <HOOK_ADDRESS> "owner()(address)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "protocolBudget()(address)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "paused()(bool)" --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "allowedSunUsdcPools(bytes32)(bool)" <SUN_USDC_POOL_ID> --rpc-url https://sepolia.base.org
cast call <HOOK_ADDRESS> "allowedMoonUsdcPools(bytes32)(bool)" <MOON_USDC_POOL_ID> --rpc-url https://sepolia.base.org
```

Stage 3 前期望结果：

```text
owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
paused=false
allowedSunUsdcPools(SUN_USDC_POOL_ID)=true
allowedMoonUsdcPools(MOON_USDC_POOL_ID)=true
```

人工复核：

- [ ] owner 仍是测试网管理员钱包。
- [ ] protocolBudget 正确。
- [ ] paused 是 `false`。
- [ ] SUN/USDC 白名单是 `true`。
- [ ] MOON/USDC 白名单是 `true`。

## 7. Stage 3 不会做什么

Stage 3 不包含这些内容：

```text
不会部署合约
不会创建池
不会初始化池
不会添加流动性
不会 swap
不会修改 poolId
不会修改 protocolBudget
不会碰 Base 主网
```

## 8. Stage 3 前必须重新检查

任何真实 Base Sepolia Stage 3 广播前，必须重新做：

- [ ] 重新跑 Base Sepolia fork 只读分阶段草案检查。
- [ ] 确认 `chainId=84532`。
- [ ] 确认 Stage 1 后复核清单全部通过。
- [ ] 确认 Stage 2 后复核清单全部通过。
- [ ] 确认 Hook owner 仍是测试网管理员钱包。
- [ ] 确认放弃 owner 后确实不需要再改白名单、protocolBudget 或 paused。
- [ ] 确认命令没有 `--broadcast`，除非 owner 单独明确批准测试网 Stage 3 广播。
- [ ] 确认没有把任何私钥、助记词、恢复词写进聊天或文档。
- [ ] 确认只使用 Base Sepolia 测试网，不触碰 Base 主网。

## 9. 绝对停止条件

出现任一情况，立即停止：

```text
命令指向 Base 主网
命令出现 --broadcast 但 owner 没有明确批准测试网 Stage 3 广播
有人要求提供私钥、助记词或恢复词
有人要求使用真实 ETH 或真实 USDC
Stage 1 后复核没有全部通过
Stage 2 后复核没有全部通过
Hook owner 已经不是测试网管理员钱包
任何白名单不是 true
protocolBudget 不符合预期
paused 不是 false
还有任何参数需要修改
```

## 10. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
Stage 3 后复核清单草案
列出如果未来 Stage 3 真的广播成功后，要如何确认 owner=0 且关键配置仍保持正确
继续保持不广播、不索要私钥
```
