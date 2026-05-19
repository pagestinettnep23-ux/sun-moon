# Base Sepolia 3 天只读观察清单 - 2026-05-19

本文档用于把原来的长期观察计划缩短为 3 天快速观察版。

重要说明：

```text
3 天是快速观察期，不是主网上线许可。
本清单只做 Base Sepolia 测试网只读检查。
不执行 Base 主网。
不使用真实资金。
不要求或记录私钥、助记词、恢复词。
不使用 --private-key。
默认不发交易，不使用 --broadcast。
```

## 1. 本清单覆盖什么

本清单覆盖当前已经完成的 Base Sepolia 测试网 rc3 小额演练状态：

```text
网络: Base Sepolia
chainId: 84532
admin / rehearsal actor: 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
SUN_TOKEN: 0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
SUN_CURVE: 0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4
MOON_TOKEN: 0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
MOON_CURVE: 0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8
HOOK: 0x6c40A03313A097dDe45694dc9E769392a0f940Cc
SWAP_ADAPTER: 0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
PROTOCOL_BUDGET: 0x277ba3Cf597CdAaF958C301db3cF6a631F793039
MOON_USDC_POOL_ID: 0x710ab2d815645e13484f0aeca86b754e56f29d4c93d9623bb8f6e5a079da51e5
POSITION_TOKEN_ID: 22719
```

注意：

```text
这里的 Stage 3 指本轮 Base Sepolia 小额池子、流动性和 swap 演练。
它不是旧文档里“放弃 Hook owner”的不可逆 renounce 阶段。
当前 Hook owner 仍应是 admin 钱包。
```

## 2. 3 天目标

3 天内只确认这些事：

```text
池子仍然存在并且 slot0 不为 0。
Hook 仍然未暂停。
Hook 白名单池仍然是 true。
Adapter 仍然授权给当前 Hook。
SunCurve.moonAMM 仍然指向当前 Hook。
测试仓位 NFT 仍归 admin 钱包。
测试仓位流动性仍能读到。
前端不混用旧地址和新地址。
前端不把 Base Sepolia 误显示成 Base 主网。
没有无法解释的余额变化。
```

3 天内不做这些事：

```text
不重复 Stage 3 小额流动性交易。
不重复 Stage 3 小额 swap 交易。
不做 Base 主网部署。
不接真实资金。
不做 renounce owner。
不把 3 天结果当成审计结论。
```

## 3. Day 1 - 基线快照

目标：把 Stage 3 完成后的状态固定下来，作为后面两天比较的标准。

只读检查项：

```text
[ ] chainId = 84532
[ ] admin nonce = 29 或更高，且更高部分能解释清楚
[ ] HOOK.owner() = 0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
[ ] HOOK.paused() = false
[ ] HOOK.allowedMoonPools(MOON_USDC_POOL_ID) = true
[ ] Adapter.authorizedHook() = 0x6c40A03313A097dDe45694dc9E769392a0f940Cc
[ ] Adapter.paused() = false
[ ] SunCurve.moonAMM() = 0x6c40A03313A097dDe45694dc9E769392a0f940Cc
[ ] StateView.getSlot0(MOON_USDC_POOL_ID) 的 sqrtPriceX96 不为 0
[ ] StateView.getSlot0(MOON_USDC_POOL_ID) 的 lpFee = 3000
[ ] PositionManager.ownerOf(22719) = admin 钱包
[ ] PositionManager.getPositionLiquidity(22719) > 0
[ ] admin 的 USDC / SUN / MOON 余额可以正常读取
[ ] protocol budget 的 USDC 余额可以正常读取
[ ] SunCurve 的 USDC reserve 可以正常读取
```

Day 1 通过标准：

```text
所有关键地址一致。
池子、Hook、Adapter、仓位都能正常读。
没有发送任何交易。
没有使用私钥或 --private-key。
```

## 4. Day 2 - 稳定性复查

目标：不操作，只看昨天的状态有没有异常变化。

只读检查项：

```text
[ ] chainId 仍然是 84532
[ ] HOOK.paused() 仍然是 false
[ ] HOOK.allowedMoonPools(MOON_USDC_POOL_ID) 仍然是 true
[ ] Adapter.authorizedHook() 仍然是当前 Hook
[ ] SunCurve.moonAMM() 仍然是当前 Hook
[ ] pool slot0 仍然能读到
[ ] POSITION_TOKEN_ID=22719 仍归 admin 钱包
[ ] 仓位 liquidity 仍大于 0
[ ] admin 余额变化能解释清楚
[ ] protocol budget 余额变化能解释清楚
[ ] SunCurve reserve 变化能解释清楚
```

Day 2 通过标准：

```text
如果没有人为测试交易，余额和仓位不应出现无法解释的变化。
如果发现异常，先记录问题，不继续下一阶段。
```

## 5. Day 3 - 前端只读对齐

目标：确认页面显示的是当前新部署，而不是旧测试地址。

前端只读检查项：

```text
[ ] 页面明确显示 Base Sepolia / chainId 84532
[ ] 页面没有把 Base Sepolia 写成 Base 主网
[ ] 页面使用当前 HOOK: 0x6c40A03313A097dDe45694dc9E769392a0f940Cc
[ ] 页面使用当前 SUN_TOKEN: 0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293
[ ] 页面使用当前 MOON_TOKEN: 0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71
[ ] 页面使用当前 MOON_USDC_POOL_ID
[ ] 页面不再把旧 Hook 0xF612... 当成当前 Hook
[ ] 页面不再把旧 Position NFT 22355 当成当前演练仓位
[ ] 页面能显示当前 Position NFT 22719
[ ] 页面上的外部链接指向 https://sepolia.basescan.org
[ ] 页面没有要求输入私钥、助记词或恢复词
```

Day 3 通过标准：

```text
前端读取地址与链上当前地址一致。
前端显示清楚这是测试网。
前端没有主网执行入口。
发现旧地址时，只记录为“需要前端修正”，不直接发交易。
```

## 6. 立即停止条件

出现任意一条，立刻停止，不继续：

```text
链 ID 不是 84532。
任何命令准备连接 Base 主网。
任何命令包含 --private-key。
有人要求提供私钥、助记词、恢复词。
前端把 Base Sepolia 当成 Base 主网。
Hook 地址不是 0x6c40A03313A097dDe45694dc9E769392a0f940Cc。
Adapter.authorizedHook 不是当前 Hook。
SunCurve.moonAMM 不是当前 Hook。
pool slot0 读不到或 sqrtPriceX96 = 0。
Position NFT 22719 owner 不是 admin 钱包。
出现无法解释的余额变化。
```

## 7. 每天记录模板

每天检查完，在记录里填写：

```text
日期:
第几天: Day 1 / Day 2 / Day 3
网络: Base Sepolia
chainId:
是否只读: 是
是否发送交易: 否
是否使用真实资金: 否
是否使用私钥 / 助记词 / 恢复词: 否
是否出现 --private-key: 否

Hook 状态:
Adapter 状态:
SunCurve.moonAMM:
Pool slot0:
Position NFT:
admin 余额:
protocol budget 余额:
SunCurve reserve:
前端状态:

异常:
结论:
下一步:
```

## 8. 3 天结束后的结论规则

如果 3 天全部通过：

```text
可以记录为“Base Sepolia 3 天快速观察通过”。
可以进入下一步：安全复核、前端修正、文档整理。
仍然不自动进入 Base 主网。
仍然不接真实资金。
仍然不能替代正式审计。
```

如果 3 天内任一天失败：

```text
先停止。
先写问题记录。
先解释原因。
必要时修代码或修前端。
修完后重新开始观察期。
```

## 9. 建议下一步

建议下一步先执行：

```text
Day 1 只读基线快照
```

这一步只读，不发交易。
