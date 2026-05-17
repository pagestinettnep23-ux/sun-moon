# Base Sepolia 前端只读状态卡验收 - 2026-05-15

本记录只涉及 `frontend/index.html` 的只读展示增强。不部署合约，不广播交易，不使用私钥，不连接 Base 主网。

## 改动范围

```text
frontend/index.html
```

新增 4 个只读状态区块：

- `Hook status`
- `Adapter status`
- `Position NFT`
- `Test txs`

页面继续保持 `READ_ONLY_MODE=true`。交易输入框仍然 `disabled`，提交按钮仍然显示 `read only`，`sendTx()` 仍直接抛出 `Base Sepolia readonly mode`。

## 前端读取项

Hook 状态卡读取：

```text
owner()
protocolBudget()
swapAdapter()
paused()
allowedMoonPools(poolId)
```

Adapter 状态卡读取：

```text
authorizedHook()
paused()
```

Position NFT 状态卡读取：

```text
ownerOf(22355)
balanceOf(0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986)
```

交易链接展示：

```text
liquidity=0x99c69749bbd9199ac7476f8d0175d2f3a651b81d97a97a607e13ca2b5168517b
swap=0x61744130044a25395399db900c542872fe8c887057025a8d6b86bc0c71aeebaa
```

## Base Sepolia 链上复核

使用 `cast call` 对页面新增读取项逐项复核：

```text
Hook.owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
Hook.protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
Hook.swapAdapter=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
Hook.paused=false
Hook.allowedMoonPools(poolId)=true

Adapter.authorizedHook=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
Adapter.paused=false

PositionManager.ownerOf(22355)=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
PositionManager.balanceOf(test wallet)=1

SunCurve.getSunPrice=1040540
MoonCurve.getMintPriceInUSDT=249729
Test wallet USDC balance=18400000
```

结论：

```text
Hook status=healthy
Adapter status=healthy
Position NFT=owned
MOON/USDC pool allowlisted=yes
Hook paused=no
Adapter paused=no
```

## 静态检查

已检查：

```text
script syntax=ok
required ids=present
required selectors=present
BaseScan tx links=present
local static preview=http 200
```

本轮浏览器自动化受本机工具环境限制：内置浏览器连接超时，Chrome CDP 端口未能保持可用。因此本轮最终采用源码静态检查 + Base Sepolia 链上读取复核。前端窗口可直接刷新 `frontend/index.html` 目视确认 4 个新增状态卡片。

## 当前停止点

前端已经能把价格读取、Hook 状态、Adapter 状态、Position NFT 和两笔测试网交易放在同一只读页面里。下一步仍不是主网，也不是打开交易按钮；建议进入测试网复盘文档收尾，整理一份“Base Sepolia 小额演练总结 + 主网前风险清单”。
