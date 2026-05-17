# SUN + MOON 双币机制设计文档
## Final v3.0.1 - 中文版

> 2026-05-16 主网前决策更新：SUN/MOON 都保持自由转账，不再通过 token 转账层禁止市场自行创建 AMM 池。项目支持的 v4 Hook 池为 `SUN/USDC` 和 `MOON/USDC`：`SUN/USDC` swap 收 `2% USDC`，`MOON/USDC` swap 收 `5% USDC`。第三方自行创建的池不代表协议价格，也不保证触发项目费用和 SUN 曲线回灌。

## 1. 核心原则

SUN + MOON 是一个双币飞轮系统：

- `SUN` 是基础储备代币，用 `USDT` 铸造，也可以销毁换回 `USDT`。SUN 的曲线价格通过手续费和储备账本设计，目标是只涨不跌。
- `MOON` 是稀缺代币，用 `SUN` 铸造，也可以销毁换回 `SUN`。MOON 使用和 SATO 一样的指数曲线模型。
- 无预挖、无 owner、无暂停、无升级、无管理员权限。部署完成后，关键参数不能再改。
- MOON 不刻意设置 Mint 停止条件。到开放时间后，Mint 路径一直存在，和 SATO 一样由曲线价格自然运行。
- MOON 和 SATO 的不同点只有：解决漂移问题、增加 5% 税费、预留可选时间锁、可自定义代币名称 / 数量 / `K` / `S`、单笔 Mint 上限从 SATO 的 `5 ETH` 改为 `10,000 USDT` 口径。

---

## 2. 代币参数

| 项目 | SUN | MOON |
|---|---|---|
| 角色 | 基础储备代币 | 稀缺飞轮代币 |
| 铸造资产 | USDT | SUN |
| 销毁取回资产 | USDT | SUN |
| 曲线类型 | 线性储备均价曲线 | 指数饱和曲线 |
| 价格规则 | 通过手续费数学保证只涨不跌 | 随 SUN 价格和 `sunReserve` 上升 |
| 供应上限 | 无硬上限 | 渐近目标 `K`，部署时设置 |
| Mint 可用性 | 一直可用 | 时间锁结束后持续可用，和 SATO 一样 |
| 单笔 Mint 上限 | `10,000 USDT` | 等值 `10,000 USDT` 的 SUN |
| 单笔 Burn 上限 | 无 | 无 |
| 启动方式 | 部署后立即可用 | 可选时间锁，默认示例为 7 天，也可设置为 0 |
| AMM | 自由转账；项目支持 `SUN/USDC` v4 Hook 池收 `2% USDC` | 自由转账；项目支持 `MOON/USDC` v4 Hook 池收 `5% USDC` |

---

## 3. 系统流向

```text
USDT
  -> SunCurveHook
  -> SUN
      -> MoonCurveHook
      -> MOON

MOON 曲线操作税费：
  3% SUN -> SunCurveHook.burnAndRetain()
  2% SUN -> 协议预算钱包

MOON AMM 交易税费：
  3% 手续费资产 -> 换成 USDT -> SunCurveHook.injectUSDT()
  2% 手续费资产 -> 协议预算钱包

SUN/USDC v4 Hook 交易税费：
  1.5% USDC -> SunCurveHook.injectUSDT()
  0.5% USDC -> 协议预算钱包
```

不提供 `USDT` 一键买 `MOON` 的路径。用户必须先获得 `SUN`，再用 `SUN` 铸造 `MOON`。

---

## 4. SUN 曲线

### 4.1 核心价格公式

```text
SUN_price = curveReserve / totalSunSupply
```

`curveReserve` 使用 USDT 的原生精度。`totalSunSupply` 使用 18 位精度。

初始状态下，第一笔 Mint 按净投入计算，`1 USDT = 1 SUN`。第一笔之后，由于 1.5% 手续费留在曲线储备中，曲线价格会高于 1。

### 4.2 SUN Mint：USDT -> SUN

```text
require(usdtIn <= MAX_MINT_USDT)

feeToCurve    = usdtIn * 150 / 10000   // 1.5%，留在曲线中
feeToProtocol = usdtIn * 50  / 10000   // 0.5%，给协议预算
usdtNet       = usdtIn - feeToCurve - feeToProtocol
reserveAdd    = usdtIn - feeToProtocol // 99.5%，进入曲线储备

reserveBefore = curveReserve
curveReserve += reserveAdd

if totalSunSupply == 0:
    sunOut = normalizeUSDTTo18(usdtNet)
else:
    sunOut = totalSunSupply * usdtNet / reserveBefore

totalSunSupply += sunOut
SunToken.mint(user, sunOut)
```

`MAX_MINT_USDT` 是单笔 `10,000 USDT`，需要按目标链 USDT 精度设置。

SUN 买入后价格上涨证明：

```text
newPrice / oldPrice = (1 + 0.995x) / (1 + 0.98x) > 1
x = usdtIn / reserveBefore
```

### 4.3 SUN Burn：SUN -> USDT

```text
usdtGross     = curveReserve * sunIn / totalSunSupply
feeToCurve    = usdtGross * 150 / 10000
feeToProtocol = usdtGross * 50  / 10000
usdtOut       = usdtGross - feeToCurve - feeToProtocol

curveReserve   -= (usdtOut + feeToProtocol)
totalSunSupply -= sunIn
SunToken.burn(user, sunIn)
USDT.transfer(user, usdtOut)
USDT.transfer(PROTOCOL_BUDGET, feeToProtocol)
```

注意：`feeToCurve` 留在 `curveReserve`，`feeToProtocol` 必须从 `curveReserve` 中转出。

SUN 卖出后价格上涨证明：

```text
newPrice / oldPrice = (1 - 0.985r) / (1 - r) > 1
r = sunIn / totalSunSupply
```

### 4.4 外部推高 SUN 价格

```solidity
function burnAndRetain(uint256 sunAmount) external onlyMoonCurve nonReentrant {
    // MoonCurveHook 先把 sunAmount 转给 SunCurveHook
    totalSunSupply -= sunAmount;
    SunToken.burn(address(this), sunAmount);
    // curveReserve 不变，totalSunSupply 减少，所以 SUN 价格上涨
}

function injectUSDT(uint256 usdtAmount) external onlyMoonAMM nonReentrant {
    USDT.transferFrom(msg.sender, address(this), usdtAmount);
    curveReserve += usdtAmount;
    // totalSunSupply 不变，curveReserve 增加，所以 SUN 价格上涨
}
```

### 4.5 SUN/MOON AMM 策略

```text
SUN_TRANSFER_POLICY = free-transfer
MOON_TRANSFER_POLICY = free-transfer
MARKET_AMM_CREATION = not controlled by protocol

项目支持的 v4 Hook 池：
  SUN/USDC：swap 收 2% USDC
  MOON/USDC：swap 收 5% USDC
```

第三方 AMM 池可以存在，因为 SUN 和 MOON 都自由转账。除非使用项目支持的 Hook 配置，否则这些池不属于协议支持路径，市场价格不能替代 `SunCurve` 或 `MoonCurve` 的协议价格。

---

## 5. MOON 曲线

### 5.1 部署参数

```solidity
string  public name;
string  public symbol;
uint256 public immutable K;                 // MOON 渐近供应目标
uint256 public immutable S;                 // 曲线尺度参数
uint256 constant FEE_SUN_CURVE_BPS = 300;  // 3%
uint256 constant FEE_PROTOCOL_BPS  = 200;  // 2%
uint256 public immutable LAUNCH_TIME;      // 可选时间锁
uint256 public immutable MAX_MINT_USDT_EQUIV;
```

`name`、`symbol`、`K`、`S` 都是项目参数，部署前自己决定。示例：

```text
name   = "MOON"
symbol = "MOON"
K      = 5,000,000 MOON
S      = 1,200,000 SUN
```

`MAX_MINT_USDT_EQUIV` 是单笔 `10,000 USDT`，按目标链 USDT 精度设置。它对应 SATO 的单笔 `5 ETH` 上限，只是换成 U 本位。

### 5.2 MOON 曲线公式

```text
q(b) = K * (1 - exp(-b / S))
p(b) = (S / K) * exp(b / S)

如果 K = 5,000,000，S = 1,200,000：
p(b) = 0.24 * exp(b / 1,200,000)

Burn amount 个 MOON 可取回的 SUN：
deltaB = S * ln((K - q + amount) / (K - q))
```

`b` 是 `sunReserve`。`q(b)` 每次都从 `sunReserve` 现算，不再存第二套供应账本，这就是解决 SATO 漂移问题的核心。

示例数据：假设 `SUN = 1 USDT`，`K = 5,000,000`，`S = 1,200,000`。

| `sunReserve` | MOON 供应量 `q(b)` | Mint 价格（SUN） | Mint 价格（USDT） | 倍数 |
|---:|---:|---:|---:|---:|
| 0 | 0 | 0.2400 | 0.2400 | 1.0x |
| 1,200,000 | 3,160,603 | 0.6524 | 0.6524 | 2.7x |
| 2,400,000 | 4,323,324 | 1.7734 | 1.7734 | 7.4x |
| 3,600,000 | 4,751,065 | 4.8205 | 4.8205 | 20.1x |
| 4,800,000 | 4,908,422 | 13.1036 | 13.1036 | 54.6x |
| 6,000,000 | 4,966,310 | 35.6192 | 35.6192 | 148.4x |
| 8,000,000 | 4,993,637 | 188.5853 | 188.5853 | 785.8x |
| 12,000,000 | 4,999,773 | 5,286.3518 | 5,286.3518 | 22,026.5x |

### 5.3 MOON Mint：SUN -> MOON

检查：

```text
block.timestamp >= LAUNCH_TIME
usdtEquiv = mulDiv(sunIn, SunCurveHook.getSunPrice(), 1e18)
usdtEquiv <= MAX_MINT_USDT_EQUIV
```

MOON 不设置储备阈值，不设置人为关闭 Mint 的条件。

流程：

```text
SunToken.transferFrom(user, address(this), sunIn)

feeToSunCurve = sunIn * 300 / 10000
feeToProtocol = sunIn * 200 / 10000
sunNet        = sunIn - feeToSunCurve - feeToProtocol

moonOut = Curve.totalMinted(sunReserve + sunNet)
        - Curve.totalMinted(sunReserve)

sunReserve += sunNet

SunToken.transfer(SUN_CURVE, feeToSunCurve)
SunCurveHook.burnAndRetain(feeToSunCurve)
SunToken.transfer(PROTOCOL_BUDGET, feeToProtocol)
MoonToken.mint(user, moonOut)
```

MOON 的单笔上限按完整 `sunIn` 计算，而不是按扣除 5% 税费后的 `sunNet` 计算。

### 5.4 MOON Burn：MOON -> SUN

MOON Burn 没有时间锁、没有数量上限、没有地址限制。

```text
currentFair = Curve.totalMinted(sunReserve)
sunGross    = Curve.burnFor(currentFair, moonIn)

feeToSunCurve = sunGross * 300 / 10000
feeToProtocol = sunGross * 200 / 10000
sunOut        = sunGross - feeToSunCurve - feeToProtocol

sunReserve -= sunGross

MoonToken.burn(user, moonIn)
SunToken.transfer(SUN_CURVE, feeToSunCurve)
SunCurveHook.burnAndRetain(feeToSunCurve)
SunToken.transfer(PROTOCOL_BUDGET, feeToProtocol)
SunToken.transfer(user, sunOut)
```

关键不变量：

```text
MoonCurveHook 持有的 SUN 余额 == sunReserve
```

因此 MOON Burn 必须从 `sunReserve` 扣除完整的 `sunGross`。其中 3% 先从 `MoonCurveHook` 转到 `SunCurveHook`，再由 `SunCurveHook` 销毁。

### 5.5 和 SATO 一样持续 Mint

MOON 不刻意关闭 Mint。`LAUNCH_TIME` 到达后，Mint 路径一直存在，继续按 SATO 同款指数曲线运行。

当曲线价格高于市场价格时，用户可能更愿意去市场买，而不是从曲线 Mint。这只是市场行为，不是合约停止规则。

---

## 6. 税费和飞轮

| 操作 | 总税费 | 进入 SUN 曲线 | 协议预算 |
|---|---:|---:|---:|
| SUN Mint | 2% | 1.5% USDT 留存 | 0.5% USDT |
| SUN Burn | 2% | 1.5% USDT 留存 | 0.5% USDT |
| MOON Mint | 5% | 3% SUN 通过 `burnAndRetain` | 2% SUN |
| MOON Burn | 5% | 3% SUN 通过 `burnAndRetain` | 2% SUN |
| MOON AMM 交易 | 5% | 3% 换成 USDT 后 `injectUSDT` | 2% 原手续费资产 |

飞轮逻辑：

```text
MOON 使用量增加
  -> 更多 SUN 被销毁，或更多 USDT 注入 SUN 曲线
  -> SUN 价格上涨
  -> MOON 的曲线价格按 USDT 计价同步上涨
  -> MOON 的 Mint 成本和 Burn 赎回价值都随 SUN 价格上升
  -> MOON 更难铸造
  -> 二级市场价格获得更高曲线支撑，稀缺性更强
```

说明：MOON 的曲线价格以 SUN 计价，再乘以 SUN 的 USDT 价格。因此在 MOON 曲线状态不变时，只要 SUN 价格上涨，MOON 的 Mint 价格和 Burn 价格按 USDT 计价都会上涨。AMM 二级市场价格不是合约强制上涨，但会受到曲线 Mint/Burn 价格和套利行为影响。

---

## 7. 价格查询

```solidity
function getSunPrice() external view returns (uint256) {
    return mulDiv(curveReserve, 1e18, totalSunSupply);
}

function getMoonMintPriceInUSDT() external view returns (uint256) {
    return mulDiv(MoonCurve.getMintPriceInSUN(), getSunPrice(), 1e18);
}

function getMoonBurnPriceInUSDT() external view returns (uint256) {
    return mulDiv(MoonCurve.getBurnPriceInSUN(), getSunPrice(), 1e18);
}

function timeUntilMoonLaunch() external view returns (uint256) {
    return block.timestamp >= LAUNCH_TIME ? 0 : LAUNCH_TIME - block.timestamp;
}
```

价格查询只能读取链上曲线账本，不能用 AMM 价格来反推曲线价格。

---

## 8. 启动和用户路径

### 8.1 启动

```text
SUN：部署后立即可用。
MOON Mint：到 LAUNCH_TIME 后可用。
如果不需要时间锁，部署时把 delay 设置为 0。
MOON Burn：只要用户持有 MOON，随时可执行。
```

### 8.2 用户路径

```text
买 SUN：
  USDT -> SunCurveHook.mint() -> SUN
  单笔最大 10,000 USDT

卖 SUN：
  SUN -> SunCurveHook.burn() -> USDT

Mint MOON：
  SUN -> MoonCurveHook.mint() -> MOON
  单笔 sunIn 的 USDT 等值不能超过 10,000 USDT

Burn MOON：
  MOON -> MoonCurveHook.burn() -> SUN

MOON 退出到 USDT：
  先 MOON -> Burn 成 SUN
  再 SUN -> Burn 成 USDT
```

不提供一键 `USDT -> MOON` 的前端或合约函数。

---

## 9. 合约列表

| 合约 | 类型 | 作用 |
|---|---|---|
| `SunToken` | ERC-20 | SUN 代币，minter 锁定给 `SunCurveHook` |
| `MoonToken` | ERC-20 | MOON 代币，minter 锁定给 `MoonCurveHook` |
| `SunCurveHook` | V4 Hook | SUN Mint/Burn、USDT 储备、`burnAndRetain`、`injectUSDT`、SUN AMM 全局加池解锁 |
| `MoonCurveHook` | V4 Hook | MOON Mint/Burn、SUN 储备、指数曲线、`LAUNCH_TIME` |
| `MoonAMMHook` | V4 Hook | MOON AMM 税费拦截、换 USDT、原子注入 |
| `PriceOracle` | View 合约 | 查询曲线价格和启动倒计时 |

### 部署参数示例

```javascript
const MOON_NAME = "MOON";
const MOON_SYMBOL = "MOON";
const MOON_K = parseEther("5000000");
const MOON_S = parseEther("1200000");
const MOON_LAUNCH_DELAY = 604800; // 不用时间锁时设为 0
const MAX_MINT_USDT =
  USDT_DECIMALS === 6
    ? parseUnits("10000", 6)
    : parseUnits("10000", 18);

const sunToken = await deploy("SunToken");
const moonToken = await deploy("MoonToken", [
  MOON_NAME,
  MOON_SYMBOL
]);

const sunHook = await deploy("SunCurveHook", [
  sunToken.address,
  USDT_ADDRESS,
  PROTOCOL_BUDGET,
  MAX_MINT_USDT
]);

const moonHook = await deploy("MoonCurveHook", [
  moonToken.address,
  sunToken.address,
  sunHook.address,
  PROTOCOL_BUDGET,
  MOON_K,
  MOON_S,
  MOON_LAUNCH_DELAY,
  MAX_MINT_USDT
]);

const moonAmmHook = await deploy("MoonAMMHook", [
  sunHook.address,
  PROTOCOL_BUDGET
]);

const priceOracle = await deploy("PriceOracle", [
  sunHook.address,
  moonHook.address,
  moonAmmHook.address
]);

await sunToken.setMinter(sunHook.address);
await moonToken.setMinter(moonHook.address);
```

---

## 10. 安全检查

- 使用 `SafeERC20`、`nonReentrant` 和 `mulDiv`。
- 税费计算先算手续费，再用 `net = amount - feeA - feeB`，减少精度问题。
- SUN Mint 必须拒绝 `usdtIn > 10,000 USDT`。
- MOON Mint 必须拒绝 SUN 等值超过 `10,000 USDT` 的输入。
- `MAX_MINT_USDT` 必须匹配目标链 USDT 精度。
- `mint()` 和 Hook swap 路径都必须检查 `LAUNCH_TIME`。
- SUN 和 MOON 都应禁止同一区块 `Mint -> Burn` 闭环。
- `SunCurveHook.getSunPrice()` 只能读曲线账本，不能读 AMM 价格。
- 支持的 v4 USDC 费用 Hook 必须在同一笔交易里完成收 USDC 和 `injectUSDT()`。
- `burnAndRetain()` 只能由 `MoonCurveHook` 调用。
- `injectUSDT()` 只能由授权费用 Hook 调用。
- MOON 不设置硬性的 Mint 储备阈值。
- 不提供直接 `USDT -> MOON` 的 Mint 函数。
- SUN 和 MOON 必须保持自由转账，除非后续决策明确改变。
- 前端必须区分协议价格、项目支持池价格和第三方 AMM 市场价格。
- 第三方池不得被描述为协议支持路径，除非它使用项目批准的 Hook 配置。

---

## 11. 链差异

| 项目 | Ethereum 主网 | BNB Chain |
|---|---|---|
| Hook 框架 | Uniswap v4 | PancakeSwap v4 适配 |
| USDT 精度 | 6 | 18 |
| `MAX_MINT_USDT` | `10_000 * 1e6` | `10_000 * 1e18` |
| USDT 地址 | `0xdAC17F...1ec7` | `0x55d398...7955` |
| 主要区别 | Gas 更高，以太坊叙事更强 | Gas 更低，散户使用门槛更低 |

经济逻辑相同，部署时需要适配合约接口、地址和 USDT 精度。

---

## 12. 风险说明

- SUN 只涨不跌依赖精确的储备账本和税费计算。
- 合约不可升级，重大 bug 只能重新部署并迁移。
- MOON 的 Mint 需求取决于市场价格、流动性和用户信心。
- “只涨不跌”和飞轮升值叙事可能带来法律合规风险，上线前需要法律审查。

---

## 13. 和 SATO 的对比

| 项目 | SATO | SUN + MOON |
|---|---|---|
| 代币模型 | 单币 | 双币飞轮 |
| 储备资产 | ETH | SUN，背后由 USDT 储备支撑 |
| Mint 可用性 | 持续曲线 | 时间锁后持续曲线 |
| 漂移问题 | 双账本有漂移风险 | 单账本 `sunReserve`，每次现算 |
| 税费作用 | 手续费独立沉淀 | 税费直接推高 SUN 价格 |
| 启动保护 | 早期随机乘数 | 可选 `LAUNCH_TIME` |
| 单笔 Mint 上限 | 最大 `5 ETH` | SUN 最大 `10,000 USDT`；MOON 最大等值 `10,000 USDT` 的 SUN |
| Mint 规则 | SATO 原曲线 | SATO 原曲线 + 5% 税费 + 可选时间锁 |
| 管理权限 | 不可变 | 部署设置后不可变 |

---

## 14. 最终总结

`SUN`：USDT 储备基础代币，2% 税费，单笔 Mint 上限 `10,000 USDT`，Burn 无上限，部署后立即可用，曲线价格设计为只涨不跌。SUN 保持自由转账；项目支持的 `SUN/USDC` v4 Hook 池 swap 收 `2% USDC`。

`MOON`：SUN 储备稀缺代币，`name`、`symbol`、`K`、`S` 可配置，5% 税费，可选时间锁，单笔 Mint 上限为等值 `10,000 USDT` 的 SUN，保持 SATO 同款持续 Mint 曲线，不刻意设置关闭条件。MOON 保持自由转账；项目支持的 `MOON/USDC` v4 Hook 池 swap 收 `5% USDC`。

用户必须先 Mint 或买入 SUN，再用 SUN Mint MOON。
