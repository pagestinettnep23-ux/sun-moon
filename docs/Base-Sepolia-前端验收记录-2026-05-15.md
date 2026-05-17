# Base Sepolia 前端验收记录 - 2026-05-15

本记录只涉及 `frontend/index.html` 的 Base Sepolia 只读页面验收。不部署合约，不广播交易，不使用私钥，不连接 Base 主网。

## 1. 验收范围

```text
frontend/index.html
```

验收目标：

- 页面顶部明确显示 `Base Sepolia 测试网`。
- RPC 指向 `https://sepolia.base.org`。
- 页面只读，不走钱包切链、授权、mint、burn、swap 或 `eth_sendTransaction`。
- SUN 当前价格从 `SunCurve.getSunPrice()` 读取，不把 `SUN 初始 1U` 硬编码成当前价格。
- 三类价格分开展示：
  - SUN curve price
  - moon curve mint price
  - AMM price
- 桌面和手机视口无明显文字重叠或误导性交易入口。

## 2. 发现并修复的问题

### 2.1 只读模式不应调用 `eth_accounts`

初次浏览器验收时，页面能打开，但链上曲线数据仍显示默认值。原因是只读模式下仍先向公共 Base Sepolia RPC 调用 `eth_accounts`。

修复：

```text
READ_ONLY_MODE=true 时，直接使用测试钱包：
0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
```

这样页面可以稳定读取测试钱包余额，不依赖浏览器钱包。

### 2.2 缺少 AMM 池价计算函数

余额修复后，测试钱包余额已经显示，但曲线和 AMM 指标仍未刷新。原因是页面调用了 `ammUsdcPerMoonFromSlot0(slot0Raw)`，但该函数未定义，导致刷新流程中断。

修复：

```text
新增 ammUsdcPerMoonFromSlot0(slot0Raw)
从 StateView.getSlot0(poolId) 返回的 sqrtPriceX96 推导 MOON/USDC AMM 池价
```

## 3. 最终浏览器验收结果

浏览器复验后，页面读数如下：

```text
asset-usdt=18.4 usdc
asset-sun=0.19 sun
asset-moon=0.2841 moon
chain-button=read only
wallet-button=refresh

sun-price-live=$1.0405
sun-burn-live=$1.0197
sun-mint-live=$1.0618
sun-reserve-metric=0.5 usdc
sun-price-metric=$1.0405
sun-supply-metric=0.481 sun

moon-price-live=$1.008
moon-burn-live=$0.2372
moon-mint-live=$0.2497
moon-reserve-metric=0.285 sun
moon-price-sun-metric=0.24 sun
moon-price-usdt-metric=$0.249729

all inputs disabled=true
submit buttons=read only / disabled=true
hasFailure=false
```

以上数值与 `docs/Base-Sepolia-前端读取对齐清单.md` 中的链上读取结果一致。

## 4. 只读安全检查

```text
输入框：disabled
提交按钮：read only + disabled
页面实际刷新路径：eth_call
页面未触发私钥输入
页面未触发交易广播
```

源码中虽然仍保留历史交易辅助函数，但当前 `READ_ONLY_MODE=true`，且 `sendTx()` 直接抛出 `Base Sepolia readonly mode`。页面上的输入框和提交按钮也被禁用。

## 5. 截图检查

已用 headless Chrome 检查：

```text
desktop=frontend-audit/verified-desktop.png
mobile=frontend-audit/verified-mobile.png
```

桌面视口：

- 顶部显示 `Base Sepolia 测试网`。
- 余额、SUN 曲线、MOON 曲线、AMM 价格均显示。
- 交易区域显示 `read only`。

手机视口：

- 顶部信息可读。
- SUN 区块无明显重叠。
- 操作区仍显示只读。

## 6. 当前停止点

前端只读验收已通过。下一步建议不是部署主网，也不是打开交易按钮，而是继续做只读可视化增强：

```text
Hook 状态可视化
Adapter 状态可视化
Position NFT 22355 可视化
最近两笔测试网交易链接
```
