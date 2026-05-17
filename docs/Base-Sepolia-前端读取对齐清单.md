# Base Sepolia 前端读取对齐清单

本文档给前端窗口使用。当前只对齐 Base Sepolia 测试网读取，不做 Base 主网，不接真实资金，不要求私钥。

## 1. 当前结论

- 小额 `MOON/USDC` 加流动性和 `0.1 USDC -> MOON` swap 已在 Base Sepolia 广播成功。
- 两笔交易 receipt 均为 `status=1`。
- 前端现在可以读取测试网真实合约状态，但页面必须明确标注为 `Base Sepolia 测试网`。
- 不要把 `SUN 初始 1U` 当作当前链上价格硬编码。当前价格必须读取 `SunCurve.getSunPrice()`。
- 前端展示时要区分三种价格：
  - `SUN 曲线价格`：来自 `SunCurve.getSunPrice()`。
  - `MOON 曲线 mint 价格`：来自 `MoonCurve.getMintPriceInSUN()` 和 `MoonCurve.getMintPriceInUSDT()`。
  - `MOON/USDC AMM 池价格`：来自 Uniswap v4 `StateView.getSlot0(poolId)`，不是曲线 mint 价格。

## 2. 网络

```text
network=Base Sepolia
chainId=84532
rpc=https://sepolia.base.org
explorer=https://sepolia.basescan.org
```

## 3. 合约地址

```text
USDC=0x036CbD53842c5426634e7929541eC2318f3dCF7e
SUN_TOKEN=0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
SUN_CURVE=0x00F49621977e5219093A988879F07936F2155c07
MOON_TOKEN=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
MOON_CURVE=0x7f4296686917Be97E826DC790c367d93585A32c3
HOOK=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
SWAP_ADAPTER=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
PROTOCOL_BUDGET=0x277ba3Cf597CdAaF958C301db3cF6a631F793039

POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
STATE_VIEW=0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
POSITION_MANAGER=0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80
UNIVERSAL_ROUTER=0x492E6456D9528771018DeB9E87ef7750EF184104
QUOTER=0x4A6513c898fe1B2d0E78d3b0e0A4a151589B1cBa
PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
```

## 4. MOON/USDC 池

```text
poolId=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
currency0=USDC
currency1=MOON
fee=3000
tickSpacing=60
hook=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

广播后只读复核：

```text
slot0.sqrtPriceX96=78912161789762476440367309875066997
slot0.tick=276244
slot0.protocolFee=0
slot0.lpFee=3000
poolLiquidity=33796876514319
ammPriceApprox=1 MOON ~= 1.008034 USDC
allowedMoonPool=true
hookPaused=false
```

## 5. 广播结果

```text
LIQUIDITY_TX=0x99c69749bbd9199ac7476f8d0175d2f3a651b81d97a97a607e13ca2b5168517b
LIQUIDITY_STATUS=1
LIQUIDITY_BLOCK=41534780
LIQUIDITY_GAS_USED=442218

SWAP_TX=0x61744130044a25395399db900c542872fe8c887057025a8d6b86bc0c71aeebaa
SWAP_STATUS=1
SWAP_BLOCK=41534781
SWAP_GAS_USED=232863

POSITION_TOKEN_ID=22355
POSITION_OWNER=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
POSITION_MANAGER_BALANCE_OF_ACTOR=1
```

## 6. 当前曲线和余额快照

代币精度：

```text
USDC decimals=6
SUN decimals=18
MOON decimals=18
```

SUN 曲线：

```text
SunCurve.getSunPrice() raw=1040540
SunCurve.getSunPrice() display=1.040540 USDC/SUN
SunCurve.curveReserve=500500
SunCurve.curveReserve display=0.500500 USDC
SUN.totalSupply=481000000000000000
SUN.totalSupply display=0.481 SUN
SunCurve.moonCurve=0x7f4296686917Be97E826DC790c367d93585A32c3
SunCurve.moonAMM=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
```

MOON 曲线：

```text
MoonCurve.getMintPriceInSUN raw=240000057000006768
MoonCurve.getMintPriceInSUN display=0.240000057000006768 SUN/MOON
MoonCurve.getMintPriceInUSDT raw=249729
MoonCurve.getMintPriceInUSDT display=0.249729 USDC/MOON
MoonCurve.sunReserve=285000000000000000
MoonCurve.sunReserve display=0.285 SUN
MoonCurve.timeUntilLaunch=0
MOON.totalSupply=1187499858980000000
MOON.totalSupply display=1.18749985898 MOON
```

测试钱包余额：

```text
TEST_WALLET=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
USDC.balanceOf(TEST_WALLET)=18400000
USDC display=18.4 USDC
SUN.balanceOf(TEST_WALLET)=190000000000000000
SUN display=0.19 SUN
MOON.balanceOf(TEST_WALLET)=284123473562317985
MOON display=0.284123473562317985 MOON
PROTOCOL_BUDGET_USDC=20004500
PROTOCOL_BUDGET_USDC display=20.0045 USDC
```

## 7. Hook 和 Adapter 读取

```text
Hook.owner=0x6E22b2e6fFAA30Fe75B71d53d1eC469b4e97A986
Hook.protocolBudget=0x277ba3Cf597CdAaF958C301db3cF6a631F793039
Hook.swapAdapter=0x50f232d1B40D9EF523cc53f958f8C80766aF35a7
Hook.allowedMoonPools(poolId)=true
Hook.paused=false
Hook.expectedHookMask=204
Hook.encodeHookData(3000)=0x0000000000000000000000000000000000000000000000000000000000000bb8

Adapter.authorizedHook=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
Adapter.paused=false
```

## 8. 前端环境变量建议

```text
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
NEXT_PUBLIC_USDC_ADDRESS=0x036CbD53842c5426634e7929541eC2318f3dCF7e
NEXT_PUBLIC_SUN_TOKEN_ADDRESS=0xDa5a62F1c2c54AB79c974eE41b9a5B83Dd307e41
NEXT_PUBLIC_SUN_CURVE_ADDRESS=0x00F49621977e5219093A988879F07936F2155c07
NEXT_PUBLIC_MOON_TOKEN_ADDRESS=0x6E7FF34C7a7a518981BF6324e5FCC6599FcBC59D
NEXT_PUBLIC_MOON_CURVE_ADDRESS=0x7f4296686917Be97E826DC790c367d93585A32c3
NEXT_PUBLIC_HOOK_ADDRESS=0xF612828Ba9dE01CF16Fae2D8EE187B0cA59100Cc
NEXT_PUBLIC_STATE_VIEW_ADDRESS=0x571291b572ed32ce6751a2Cb2486EbEe8DEfB9B4
NEXT_PUBLIC_POSITION_MANAGER_ADDRESS=0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80
NEXT_PUBLIC_MOON_USDC_POOL_ID=0xfbb4ccec5e3fda3a97b9e2619e9e90588ad5e444bdb3d488e921a3192c42dd55
NEXT_PUBLIC_TINY_POSITION_TOKEN_ID=22355
```

## 9. 前端显示规则

- 页面顶部必须显示 `Base Sepolia 测试网`。
- 不要显示为主网资产，不要出现收益承诺、投资建议或真实资金入口。
- 当前只建议做读取页面，不做加流动性、swap、管理员配置按钮。
- 价格展示必须带来源：
  - `SUN 曲线价`
  - `MOON 曲线 mint 价`
  - `MOON/USDC AMM 池价`
- `SUN 初始 1U` 可以作为产品说明或历史参考，但当前测试网价格必须从 `SunCurve.getSunPrice()` 读取。
- 如果读取失败，显示“测试网数据读取失败”，不要自动切到主网或其他 RPC。

## 10. 最小 ABI 读取项

前端第一轮只需要以下只读函数：

```text
ERC20:
decimals()
totalSupply()
balanceOf(address)

SunCurve:
getSunPrice()
curveReserve()
moonCurve()
moonAMM()

MoonCurve:
getMintPriceInSUN()
getMintPriceInUSDT()
sunReserve()
timeUntilLaunch()

Hook:
owner()
protocolBudget()
swapAdapter()
allowedMoonPools(bytes32)
paused()
expectedHookMask()

Adapter:
authorizedHook()
paused()

StateView:
getSlot0(bytes32)
getLiquidity(bytes32)

PositionManager:
ownerOf(uint256)
balanceOf(address)
```
