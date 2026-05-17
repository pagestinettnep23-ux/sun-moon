# SUN + MOON Mechanism Design
## Final v3.0.1 - 精简修订版

> 2026-05-16 mainnet-prep decision update: SUN and MOON remain freely transferable ERC-20 tokens. The protocol no longer tries to forbid market-created AMM pools at the token layer. The project-supported v4 Hook pools are `SUN/USDC` with a 2% USDC swap fee and `MOON/USDC` with a 5% USDC swap fee. Third-party pools are market-created paths; they do not represent protocol prices and do not guarantee protocol fee injection.

## 1. Design Principles

SUN + MOON is a two-token flywheel system:

- `SUN` is the reserve-backed base Token. It is minted with `USDT`, burned back to `USDT`, and its Curve price is designed to be non-decreasing.
- `MOON` is the scarce Token. It is minted with `SUN`, burned back to `SUN`, and follows an exponential saturation Curve.
- No premine, no owner, no pause, no upgrade, and no admin control after deployment setup.
- All critical parameters are set at deployment and cannot be changed afterward.
- `MOON` follows the SATO Curve model: after Launch Time, Mint remains callable and the contract does not define any stop condition.
- MOON differs from SATO only in these places: single-ledger drift fix, 5% Fee, optional Launch Time lock, configurable Token metadata / `K` / `S`, and a `10,000 USDT` per-Mint cap instead of SATO's `5 ETH` cap.

---

## 2. Token Parameters

| Item | SUN | MOON |
|---|---|---|
| Role | Base Reserve Token | Scarce Flywheel Token |
| Mint Asset | USDT | SUN |
| Burn Asset | USDT | SUN |
| Curve Type | Linear reserve-average Curve | Exponential saturation Curve |
| Price Rule | Non-decreasing by fee math | Rises with SUN price and `sunReserve` |
| Supply Cap | No hard cap | Asymptotic target `K`, set at deployment |
| Mint Availability | Always available | Same SATO-style continuous Curve after Launch Time |
| Per-Mint Limit | `10,000 USDT` | SUN with USDT value <= `10,000 USDT` |
| Per-Burn Limit | None | None |
| Launch | Active immediately | Optional Launch Time; default example is 7 days (`604,800 seconds`) |
| AMM | Free-transfer token; project-supported `SUN/USDC` v4 Hook pool charges 2% USDC | Free-transfer token; project-supported `MOON/USDC` v4 Hook pool charges 5% USDC |

---

## 3. System Flow

```text
USDT
  -> SunCurveHook
  -> SUN
      -> MoonCurveHook
      -> MOON

MOON Curve Fee:
  3% SUN -> SunCurveHook.burnAndRetain()
  2% SUN -> PROTOCOL_BUDGET

MOON AMM Fee:
  3% fee asset -> swap to USDT -> SunCurveHook.injectUSDT()
  2% fee asset -> PROTOCOL_BUDGET

SUN/USDC v4 Hook Fee:
  1.5% USDC -> SunCurveHook.injectUSDT()
  0.5% USDC -> PROTOCOL_BUDGET
```

There is no direct `USDT-to-MOON` path. The user must acquire SUN first, then use SUN to Mint MOON after `LAUNCH_TIME`.

---

## 4. SunCurveHook

### 4.1 Core Price

```text
SUN_price = curveReserve / totalSunSupply
```

`curveReserve` is stored in the native decimals of USDT. `totalSunSupply` uses 18 decimals.

When `totalSunSupply == 0`, the first Mint quotes net USDT at `1 USDT = 1 SUN`, normalized to SUN 18 decimals. After the first Mint, retained Curve Fee makes the stored Curve price higher than 1.

### 4.2 SUN Mint: USDT -> SUN

Use fee residual math to avoid rounding dust:

```text
require(usdtIn <= MAX_MINT_USDT)

feeToCurve    = usdtIn * 150 / 10000   // 1.5%
feeToProtocol = usdtIn * 50  / 10000   // 0.5%
usdtNet       = usdtIn - feeToCurve - feeToProtocol
reserveAdd    = usdtIn - feeToProtocol // 99.5%, because Protocol Fee leaves the Hook

reserveBefore = curveReserve
curveReserve += reserveAdd

if totalSunSupply == 0:
    sunOut = normalizeUSDTTo18(usdtNet)
else:
    sunOut = totalSunSupply * usdtNet / reserveBefore

totalSunSupply += sunOut
SunToken.mint(user, sunOut)
```

Price monotonicity:

```text
newPrice / oldPrice = (1 + 0.995x) / (1 + 0.98x) > 1
where x = usdtIn / reserveBefore
```

`MAX_MINT_USDT` is `10,000 USDT` in the target chain's USDT decimals.

### 4.3 SUN Burn: SUN -> USDT

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

`feeToCurve` remains in `curveReserve`; `feeToProtocol` must leave `curveReserve`.

Price monotonicity:

```text
newPrice / oldPrice = (1 - 0.985r) / (1 - r) > 1
where r = sunIn / totalSunSupply
```

### 4.4 External SUN Price Injection

```solidity
function burnAndRetain(uint256 sunAmount) external onlyMoonCurve nonReentrant {
    // MoonCurveHook must transfer sunAmount to SunCurveHook before this call.
    totalSunSupply -= sunAmount;
    SunToken.burn(address(this), sunAmount);
    // curveReserve is unchanged, so SUN price rises.
}

function injectUSDT(uint256 usdtAmount) external onlyMoonAMM nonReentrant {
    USDT.transferFrom(msg.sender, address(this), usdtAmount);
    curveReserve += usdtAmount;
    // totalSunSupply is unchanged, so SUN price rises.
}
```

### 4.5 SUN/MOON AMM Policy

```text
SUN_TRANSFER_POLICY = free-transfer
MOON_TRANSFER_POLICY = free-transfer
MARKET_AMM_CREATION = not controlled by protocol

Project-supported v4 Hook pools:
  SUN/USDC: 2% USDC swap fee
  MOON/USDC: 5% USDC swap fee
```

Third-party AMM pools can exist because SUN and MOON are freely transferable. Those pools are not protocol-supported paths unless they use the project-supported Hook configuration. Their market prices must not replace `SunCurve` or `MoonCurve` protocol prices.

---

## 5. MoonCurveHook

### 5.1 Deployment Parameters

```solidity
string  public name;
string  public symbol;
uint256 public immutable K;                 // asymptotic MOON supply target
uint256 public immutable S;                 // Curve scale parameter
uint256 constant FEE_SUN_CURVE_BPS = 300;  // 3%
uint256 constant FEE_PROTOCOL_BPS  = 200;  // 2%
uint256 public immutable LAUNCH_TIME;      // optional; deploy timestamp + delay
uint256 public immutable MAX_MINT_USDT_EQUIV;
```

Token `name`, `symbol`, `K`, and `S` are project parameters. The examples below use:

```text
name   = "MOON"
symbol = "MOON"
K      = 5,000,000 MOON
S      = 1,200,000 SUN
```

This keeps the Curve math SATO-compatible while allowing the final Token name, amount, and scale to be chosen before deployment.

`MAX_MINT_USDT_EQUIV` is `10,000 USDT` in the target chain's USDT decimals. It replaces SATO's `5 ETH` per-Mint cap.

### 5.2 MOON Curve

```text
q(b) = K * (1 - exp(-b / S))
p(b) = (S / K) * exp(b / S)
     = 0.24 * exp(b / 1,200,000)  // example only: K = 5,000,000 and S = 1,200,000

Burn return for amount MOON:
deltaB = S * ln((K - q + amount) / (K - q))
```

`b` is `sunReserve`. `q(b)` is calculated from `sunReserve` each time. Do not store a second supply ledger.

Example data points when `SUN = 1 USDT`, `K = 5,000,000`, and `S = 1,200,000`:

| `sunReserve` | MOON Supply `q(b)` | Mint Price in SUN | Mint Price in USDT | Multiple |
|---:|---:|---:|---:|---:|
| 0 | 0 | 0.2400 | 0.2400 | 1.0x |
| 1,200,000 | 3,160,603 | 0.6524 | 0.6524 | 2.7x |
| 2,400,000 | 4,323,324 | 1.7734 | 1.7734 | 7.4x |
| 3,600,000 | 4,751,065 | 4.8205 | 4.8205 | 20.1x |
| 4,800,000 | 4,908,422 | 13.1036 | 13.1036 | 54.6x |
| 6,000,000 | 4,966,310 | 35.6192 | 35.6192 | 148.4x |
| 8,000,000 | 4,993,637 | 188.5853 | 188.5853 | 785.8x |
| 12,000,000 | 4,999,773 | 5,286.3518 | 5,286.3518 | 22,026.5x |

### 5.3 MOON Mint: SUN -> MOON

Checks:

```text
block.timestamp >= LAUNCH_TIME
usdtEquiv = mulDiv(sunIn, SunCurveHook.getSunPrice(), 1e18)
usdtEquiv <= MAX_MINT_USDT_EQUIV
```

There is no reserve-threshold check and no artificial Mint closing condition.

Flow:

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

The Mint limit is based on full `sunIn`, before the 5% Fee is deducted.

### 5.4 MOON Burn: MOON -> SUN

MOON Burn has no time lock, no amount cap, and no address allowlist.

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

Important invariant:

```text
MoonCurveHook SUN balance == sunReserve
```

Therefore MOON Burn must deduct the full `sunGross`. The 3% sent to `burnAndRetain` is still paid out of `MoonCurveHook` reserve before it is burned by `SunCurveHook`.

### 5.5 SATO-Style Continuous Mint

MOON does not intentionally close Mint. After `LAUNCH_TIME`, the Mint path remains open and follows the same SATO-style exponential Curve.

Market behavior may reduce Mint demand when:

```text
MOON Curve Mint price in USDT > MOON AMM market price
```

At that point, users may prefer buying MOON in the market instead of minting from the Curve. This is market behavior only, not a contract rule.

---

## 6. Fee System and Flywheel

| Action | Total Fee | To SUN Curve | To Protocol Budget |
|---|---:|---:|---:|
| SUN Mint | 2% | 1.5% USDT retained | 0.5% USDT |
| SUN Burn | 2% | 1.5% USDT retained | 0.5% USDT |
| MOON Mint | 5% | 3% SUN via `burnAndRetain` | 2% SUN |
| MOON Burn | 5% | 3% SUN via `burnAndRetain` | 2% SUN |
| SUN/USDC v4 Hook Trade | 2% | 1.5% USDC via `injectUSDT` | 0.5% USDC |
| MOON/USDC v4 Hook Trade | 5% | 3% USDC via `injectUSDT` | 2% USDC |

Flywheel:

```text
MOON usage increases
  -> more SUN is burned or more USDT is injected
  -> SUN price rises
  -> MOON Curve price rises in USDT terms
  -> MOON Mint cost and Burn redemption value both rise with SUN price
  -> MOON becomes harder to mint
  -> market price gets stronger Curve support, and scarcity strengthens
```

Note: MOON Curve prices are denominated in SUN and then converted through the SUN price in USDT. If the MOON Curve state is unchanged, a higher SUN price raises both MOON Mint and Burn prices in USDT terms. The AMM market price is not forced upward by the contract, but it is influenced by Curve quotes and arbitrage.

---

## 7. Price Oracle

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

The Oracle reads on-chain Storage only. It must not read an AMM price to calculate Curve prices.

---

## 8. Launch and User Paths

### 8.1 Launch

```text
SUN: active immediately after deployment.
MOON Mint: active after LAUNCH_TIME.
If no timelock is needed, set launch delay to 0 at deployment.
MOON Burn: always available if the user already holds MOON.
```

### 8.2 User Paths

```text
Buy SUN:
  USDT -> SunCurveHook.mint() -> SUN

Sell SUN:
  SUN -> SunCurveHook.burn() -> USDT

Mint MOON:
  SUN -> MoonCurveHook.mint() -> MOON
  Requires LAUNCH_TIME if the optional timelock is enabled.
  Per Mint, sunIn must be worth <= 10,000 USDT.

Burn MOON:
  MOON -> MoonCurveHook.burn() -> SUN

Exit MOON to USDT:
  MOON -> Burn to SUN
  then SUN -> Burn to USDT in a separate user action.
```

No frontend or contract should expose a direct USDT-to-MOON Mint function.

---

## 9. Contract Set

| Contract | Type | Purpose |
|---|---|---|
| `SunToken` | ERC-20 | SUN Token, minter locked to `SunCurveHook` |
| `MoonToken` | ERC-20 | MOON Token, minter locked to `MoonCurveHook` |
| `SunCurveHook` | Curve Contract | SUN Mint/Burn, USDT Reserve, `burnAndRetain`, `injectUSDT` |
| `MoonCurveHook` | V4 Hook | MOON Mint/Burn, SUN Reserve, exponential Curve, `LAUNCH_TIME` |
| `SunMoonUsdcFeeHook` | V4 Hook | SUN/USDC 2% USDC fee and MOON/USDC 5% USDC fee, atomic injection |
| `PriceOracle` | View Contract | Curve prices, market helpers, launch countdown |

### Deployment Values

```javascript
const MOON_NAME = "MOON";
const MOON_SYMBOL = "MOON";
const MOON_K = parseEther("5000000");
const MOON_S = parseEther("1200000");
const MOON_LAUNCH_DELAY = 604800; // set to 0 if the timelock is not used
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

## 10. Security Checklist

- Use `SafeERC20`, `nonReentrant`, and `mulDiv` for precision-sensitive math.
- Fee math should calculate fees first, then use `net = amount - feeA - feeB`.
- SUN Mint must reject `usdtIn > 10,000 USDT`.
- MOON Mint must reject `sunIn` when its SUN Curve value exceeds `10,000 USDT`.
- `MAX_MINT_USDT` must match target-chain USDT decimals.
- `mint()` and Hook swap paths must both enforce `LAUNCH_TIME`.
- Same-block `Mint -> Burn` should be blocked for both SUN and MOON.
- `SunCurveHook.getSunPrice()` must read only Curve Storage, not AMM prices.
- The supported v4 USDC fee Hook must call `injectUSDT()` atomically after collecting USDC fees.
- `burnAndRetain()` can only be called by `MoonCurveHook`.
- `injectUSDT()` can only be called by the authorized fee Hook.
- No hard MOON Mint reserve threshold.
- No direct `USDT-to-MOON` Mint function.
- SUN and MOON must remain freely transferable unless a later decision explicitly changes this.
- The frontend must distinguish protocol prices from third-party AMM market prices.
- Third-party pools must not be described as protocol-supported paths unless they use the approved Hook configuration.

---

## 11. Chain Notes

| Item | Ethereum Mainnet | BNB Chain |
|---|---|---|
| Hook Framework | Uniswap v4 | PancakeSwap v4 adaptation |
| USDT Decimals | 6 | 18 |
| `MAX_MINT_USDT` | `10_000 * 1e6` | `10_000 * 1e18` |
| USDT Address | `0xdAC17F...1ec7` | `0x55d398...7955` |
| Main Difference | Higher gas, stronger ETH-native narrative | Lower gas, faster retail usage |

The economic logic is the same. Contract interfaces and token decimals must be adapted per chain.

---

## 12. Risks

- The non-decreasing SUN price depends on exact Reserve accounting and Fee math.
- Contracts are immutable; any critical bug requires redeployment and migration.
- MOON Mint demand depends on market price, liquidity, and user confidence.
- Claims such as non-decreasing price or flywheel appreciation may create legal or regulatory risk. Legal review is required before launch.

---

## 13. SATO Comparison

| Item | SATO | SUN + MOON |
|---|---|---|
| Token Model | Single Token | Two-Token flywheel |
| Reserve Asset | ETH | SUN backed by USDT Reserve |
| Mint Availability | Continuous Curve | Continuous Curve after optional Launch Time |
| Drift Issue | Dual-ledger drift risk | Single-ledger `sunReserve` |
| Fee Effect | Isolated fee accrual | Fees directly raise SUN price |
| Launch Protection | Early random multiplier | Optional `LAUNCH_TIME` for MOON Mint |
| Mint Limit | Max `5 ETH` per Mint | SUN max `10,000 USDT`; MOON max SUN worth `10,000 USDT` |
| Mint Rules | Continuous SATO Curve | Continuous SATO Curve plus 5% Fee and optional Launch Time |
| Admin Control | Immutable | Immutable after setup |

---

## Final Summary

`SUN`: USDT-backed base Token, 2% Fee, per-Mint cap `10,000 USDT`, no Burn limit, active immediately, Curve price designed to be non-decreasing. SUN remains freely transferable; the project-supported `SUN/USDC` v4 Hook pool charges 2% USDC on swaps.

`MOON`: SUN-backed scarce Token, configurable `name`, `symbol`, `K`, and `S`, 5% Fee, optional Launch Time, per-Mint cap equal to `10,000 USDT` worth of SUN, SATO-style continuous Mint. MOON remains freely transferable; the project-supported `MOON/USDC` v4 Hook pool charges 5% USDC on swaps.

Users must Mint or buy SUN first, then use SUN to Mint MOON.
