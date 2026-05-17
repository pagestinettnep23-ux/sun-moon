# Base 主网 LP Fee 与 TickSpacing 小白决策说明 - 2026-05-16

本文档只帮助 owner 理解 `SUN/USDC` 和 `MOON/USDC` 两个 v4 Hook 池的 `LP fee` 与 `tickSpacing` 怎么选。它不是主网部署批准，不广播交易，不接真实资金，不需要私钥。

## 一句话结论

当前建议先采用测试默认值：

```text
SUN_USDC_POOL_FEE=3000
SUN_USDC_TICK_SPACING=60

MOON_USDC_POOL_FEE=3000
MOON_USDC_TICK_SPACING=60
```

人话解释：

```text
两个池都使用 Uniswap LP fee 0.3%
两个池都使用 tickSpacing 60
```

这只是“主网参数草案建议”，不是执行。

## 先分清两种手续费

项目现在有两种手续费，名字很像，但不是一回事。

| 类型 | 谁收 | 用途 | 当前值 |
| --- | --- | --- | --- |
| Hook fee | SUN/MOON 项目 Hook | 回灌 `SunCurve` 和协议经费 | SUN 2%，MOON 5% |
| LP fee | Uniswap v4 池子 | 给流动性提供者 | 建议 0.3% |

所以用户真实交易时，会同时受到：

```text
Hook fee + LP fee + 价格滑点
```

粗略理解：

| 池子 | Hook fee | LP fee 草案 | 粗略交易成本，不含滑点 |
| --- | --- | --- | --- |
| `SUN/USDC` | 2% | 0.3% | 约 2.3% |
| `MOON/USDC` | 5% | 0.3% | 约 5.3% |

前端以后必须分别显示，不要只写一个总数糊过去。

## `POOL_FEE=3000` 是什么意思

Uniswap v4 的 `fee` 单位不是百分号，而是“百万分之一”级别的整数。简单看：

```text
3000 = 0.3%
10000 = 1%
1000000 = 100%
```

所以：

```text
POOL_FEE=3000
```

就是：

```text
每次 swap，Uniswap 池子额外收 0.3% 给 LP
```

注意：这不是项目的 2% / 5% Hook fee。

## `tickSpacing=60` 是什么意思

Uniswap v4 的价格不是一条完全连续的线，而是按 tick 这个价格刻度移动。

```text
tickSpacing=60
```

意思是：

```text
流动性仓位的价格范围必须按 60 个 tick 对齐。
```

小白理解：

- tickSpacing 越小，价格范围可以设得越细。
- tickSpacing 越大，价格范围更粗。
- 60 是比较常见、好解释、也已经在本项目 Base Sepolia 演练里用过的默认值。

## 为什么建议先用 3000 / 60

推荐理由：

- 项目 Base Sepolia 受控 `MOON/USDC` 演练已经用过 `fee=3000`、`tickSpacing=60`。
- 本地新版 `SUN/USDC` 和 `MOON/USDC` poolId 计算脚本默认也使用这组参数。
- 两个池使用相同 LP fee 和 tickSpacing，后续文档、前端、测试和人工复核更简单。
- 第一阶段项目已经有 Hook fee，LP fee 不宜再设得太高，否则用户交易成本会更难接受。
- 当前不建议一开始上动态 LP fee，因为解释、测试、前端展示和审计复杂度都会上升。

## 什么时候不该用 3000 / 60

如果后续出现这些情况，就应该暂停默认选择，重新评估：

- 外部 review 认为总交易成本太高。
- 前端报价显示用户实际成本难以接受。
- 主网 fork dry-run 发现流动性范围或价格移动不适合。
- 计划让专业做市方集中管理流动性，并提出不同 tickSpacing。
- 决定支持更多项目官方池，例如 WETH 池。
- 决定启用动态 LP fee。

当前没有这些前提，所以先推荐默认值。

## 不推荐的选择

| 选择 | 为什么不推荐 |
| --- | --- |
| `POOL_FEE=10000`，也就是 1% | 再叠加 Hook fee 后，SUN 约 3%，MOON 约 6%，交易成本更高 |
| `POOL_FEE=0` | LP 没有手续费收入，早期流动性吸引力更弱 |
| 两个池用不同 tickSpacing | 增加解释、测试和前端配置复杂度 |
| 动态 LP fee | 第一阶段太复杂，后续再评估 |

## 对 poolId 的影响

`fee` 和 `tickSpacing` 是 `PoolKey` 的一部分。

这意味着：

```text
同样的 SUN、USDC、Hook 地址
只要 fee 或 tickSpacing 改了
poolId 就会变
```

所以不能先算 poolId，再随便改 fee 或 tickSpacing。

正确顺序是：

1. 先确认 `POOL_FEE`。
2. 再确认 `tickSpacing`。
3. 再用脚本计算 `poolId`。
4. 再做白名单草案。

## owner 已确认的草案值

owner 已确认：

```text
SUN/USDC:
  LP fee = 0.3%
  tickSpacing = 60

MOON/USDC:
  LP fee = 0.3%
  tickSpacing = 60
```

确认后，下一步仍然不是广播。

正式参数模板里的这 4 项状态已从：

```text
待用户确认
```

更新为：

```text
owner 已确认草案值
```

## 当前停止点

完成本文档后，仍然：

```text
不部署主网
不广播交易
不接真实资金
不索要私钥
```

下一步可以做“正式参数填表版”，但只填公开参数和草案状态。
