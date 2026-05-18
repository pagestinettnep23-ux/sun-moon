# Base Sepolia rc3 分阶段广播人工复核表 - 2026-05-18

本文用于人工复核 rc3 分阶段广播草案的 fork 只读检查结果。

这不是测试网广播批准，更不是主网广播批准。

固定边界：

```text
不加 --broadcast
不部署测试网合约
不部署主网合约
不使用真实资金
不索要私钥
不读取 PRIVATE_KEY
```

## 1. 本次检查结论

```text
检查类型=Base Sepolia fork 只读检查
script_result=Script ran successfully
chainId=84532
broadcastAllowed=false
executionBlocked=true
simulationOnly=true
executeRequested=false
privateKeyPresent=false
mainnet_broadcast=false
testnet_broadcast=false
private_key_requested=false
```

小白理解：

```text
脚本能生成计划。
脚本仍然锁住执行。
这一步没有发交易。
这一步没有部署任何合约。
这一步没有使用私钥。
```

## 2. 已由脚本确认的安全项

| 项目 | 结果 | 小白解释 |
| --- | --- | --- |
| 网络是 Base Sepolia | 已确认，chainId=84532 | 这是测试网，不是 Base 主网 |
| Base 主网广播 | false | 没有主网动作 |
| 测试网广播 | false | 本次也没有发测试网交易 |
| 是否允许广播 | broadcastAllowed=false | 脚本层面不允许广播 |
| 是否锁住执行 | executionBlocked=true | 执行开关仍然锁住 |
| 是否只模拟 | simulationOnly=true | 只做 fork 模拟 |
| 是否请求执行 | executeRequested=false | 没有请求执行阶段广播 |
| 是否检测到私钥 | privateKeyPresent=false | 没有读取到私钥 |
| Stage 1 地址冲突 | false | 预测核心地址当前没有代码冲突 |
| Stage 2 Hook 冲突 | false | 预测 Hook 当前没有冲突 |

## 3. 三个阶段复核

| 阶段 | 预计交易数 | 谁执行 | 做什么 | 当前状态 |
| --- | ---: | --- | --- | --- |
| Stage 1 | 12 | `0x2F6E887c6058deE520f9468a1022E3480A6334D3` | 部署测试版 SUN/MOON 核心合约和基础配置 | 只读检查通过，未广播 |
| Stage 2 | 6 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` | 部署 Hook、绑定、白名单两个池、初始化两个池 | 只读检查通过，未广播 |
| Stage 3 | 1 | `0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986` | renounce Hook owner | 只读检查通过，未广播 |

合计：

```text
totalTransactionsPlanned=19
```

人工复核：

- [ ] 确认 Stage 1/2/3 的顺序可以理解。
- [ ] 确认 Stage 3 是最后才做，不能提前 renounce。
- [ ] 确认任何真实测试网广播都必须再次单独批准。

## 4. 官方测试网基础设施

| 项目 | 地址 |
| --- | --- |
| PoolManager | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| StateView | `0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4` |
| Base Sepolia USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

人工复核：

- [ ] 确认这些是 Base Sepolia 测试网参数，不是 Base 主网参数。
- [ ] 任何真正测试网广播前，再重新跑一次只读检查，避免官方地址或脚本输出被误用。

## 5. 预测合约地址

这些地址是 fork 只读检查结果，不是已经部署地址。

| 项目 | 预测地址 |
| --- | --- |
| PREDICTED_SUN_TOKEN | `0xb5287fBbAD0e25B12f18497209fDac7e0ACf7293` |
| PREDICTED_SUN_CURVE | `0xe8D048aB83727419b00F4e30F4898C6B3bB91aD4` |
| PREDICTED_MOON_TOKEN | `0x92dC3B8056cA62A7dbc5c1C339891B45463bEe71` |
| PREDICTED_MOON_CURVE | `0x095c91aB279121300Ac16c57D1ecebB9ceEa1cd8` |
| PREDICTED_CREATE2_HOOK_DEPLOYER | `0x6E34D98e1925eaf6680941213E49741b8764DdfE` |
| PREDICTED_HOOK | `0x675D7a468d4d3b8d02d530539867F9e5feEFc0cc` |

Hook 参数：

```text
HOOK_SALT=0x0000000000000000000000000000000000000000000000000000000000002a9c
actualLow14Bits=204
expectedHookMask=204
```

人工复核：

- [ ] 确认这些只是预测地址，不是已经部署地址。
- [ ] 确认如果 Stage 1 执行钱包 nonce 改变，核心合约预测地址可能变化。
- [ ] 确认任何真正测试网广播前必须重新生成并复核这一组地址。

## 6. 两个 v4 Hook 池

这些 poolId 是基于上面的预测地址计算出的 fork 检查结果，不是已经部署池。

| 池 | poolId | LP fee | tickSpacing | 初始价格 |
| --- | --- | ---: | ---: | --- |
| SUN/USDC | `0xdbf2bf05916b4f79d43e3ee74fa48b36301e8e8c13805335e186648b792451dc` | 0.3% | 60 | `1 SUN = 1 USDC` |
| MOON/USDC | `0x5b2a79878be8e421c919a9acb8d853731d6d61b8053aa25bd32e0c994130bdfd` | 0.3% | 60 | `1 MOON = 0.24 USDC` |

初始化参数：

```text
SUN_USDC_INITIAL_TICK=276324
SUN_USDC_SQRT_PRICE_X96=79228162514264337593543950336000000
MOON_USDC_INITIAL_TICK=290595
MOON_USDC_SQRT_PRICE_X96=161723809515207654377831473576838109
```

费用逻辑：

```text
SUN/USDC Hook fee=2% USDC
MOON/USDC Hook fee=5% USDC
Uniswap LP fee=0.3%
```

人工复核：

- [ ] 确认 `LP fee=0.3%` 是 LP 手续费，不是项目 Hook 收费。
- [ ] 确认 `SUN/USDC Hook fee=2% USDC`。
- [ ] 确认 `MOON/USDC Hook fee=5% USDC`。
- [ ] 确认两个 poolId 只是预测结果，不是已经上线的池。

## 7. 绝对停止条件

出现任一情况，立即停止：

```text
命令出现 --broadcast
有人要求提供私钥、助记词或恢复词
有人要求使用真实资金
有人要求广播 Base 主网
测试网地址和主网地址混用
预测地址被说成已经部署地址
旧版 MOON/USDC 演练被说成 rc3 全范围通过
```

## 8. 下一步建议

下一步仍然不是广播。

建议下一步只做：

```text
Stage 1/2/3 测试网广播草案和广播后复核清单已经准备完成
下一步只建议准备 rc3 Stage 1/2/3 总闸门清单
把广播前确认、广播后复核、停止条件合并成一张最终人工审批表
继续保持执行锁定
不加 --broadcast
不需要私钥
```

只有当 owner 明确批准“测试网 Stage 1 广播”，才进入真实 Base Sepolia 测试网广播准备。主网仍然不进入。

已准备文档：

```text
docs/Base-Sepolia-rc3-Stage1-测试网广播草案-2026-05-18.md
docs/Base-Sepolia-rc3-Stage1-广播后复核清单草案-2026-05-18.md
docs/Base-Sepolia-rc3-Stage2-测试网广播草案-2026-05-18.md
docs/Base-Sepolia-rc3-Stage2-广播后复核清单草案-2026-05-18.md
docs/Base-Sepolia-rc3-Stage3-测试网广播草案-2026-05-18.md
docs/Base-Sepolia-rc3-Stage3-广播后复核清单草案-2026-05-18.md
```
