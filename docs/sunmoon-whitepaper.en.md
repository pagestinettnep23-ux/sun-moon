# sun / moon

_mathematics gives the rule. philosophy gives the shape._

sun / moon is a two-token curve system. sun is the reserve. moon is the scarcity.
one stores value through usdc reserve. the other measures scarcity through sun.

the protocol is built with uniswap v4 hooks and is designed to run on base.
its supported sun/usdc and moon/usdc paths are base v4 hook pools.

there is no premine, no operator mint, no pause, no upgrade, no discretionary
curve control. after deployment binding, minters are locked to the curve
contracts and the system runs by fixed rules.

code is the law. math is the nature.

## § the pair

sun is minted with usdc and burned back to usdc. its curve price is:

```text
sun price = curve reserve / sun supply
```

each mint and each burn leaves a small part inside the reserve. reserve and
supply move together, but not symmetrically. the residue is the quiet force.
it is why the sun curve price is designed to be non-decreasing.

moon is minted with sun and burned back to sun. its curve is exponential:

```text
moon supply      = K * (1 - exp(-sun reserve / S))
moon price in sun = (S / K) * exp(sun reserve / S)
moon price in usdc = moon price in sun * sun price
```

moon has no direct usdc mint path. the path is always:

```text
usdc -> sun -> moon
moon -> sun -> usdc
```

## § issuance

sun has no premine and no fixed maximum supply. it is issued only when usdc
enters the sun curve, and it is destroyed when redeemed back to usdc.

```text
sun issuance = curve-minted sun - burned sun
sun fixed cap = none
single sun mint cap = 10,000 usdc
```

moon has no premine. its curve target is fixed at deployment.

```text
moon curve target K = 5,000,000 moon
moon issuance = curve-minted moon - burned moon
single moon mint cap = 10,000 usdc worth of sun
```

K is an asymptotic target. the curve approaches it through math; no operator can
mint around it.

## § opposition

mint and burn are opposites. buy and sell are opposites.

the protocol does not choose one side. it lets both sides exist under the same
math. expansion adds reserve. contraction removes supply. both leave a trace
inside the system.

this is the first principle: opposition does not break the model. it feeds it.

## § balance

sun balances protocol reserve against circulating supply.

moon balances scarce supply against sun reserve.

the two curves are separate, but they are not isolated. moon is priced in sun;
sun is priced in usdc. when sun becomes stronger, moon's curve basis becomes
stronger too.

there is no oracle mood, no admin quote, no manual market defense. the quote is
read from contract storage.

## § the flywheel

moon activity pushes value back into sun.

```text
moon mint / burn / supported trade
  -> fee returns to the sun curve
  -> sun is burned or usdc is injected
  -> sun price basis rises
  -> moon curve price rises in usdc terms
  -> moon becomes harder to mint
  -> scarcity strengthens
  -> activity returns to the system
```

this is the flywheel. not a promise of market price. not a ponzi equation. a
cycle of reserve, burn, scarcity, and repricing.

## § fees

sun mint and burn charge 2%.

```text
1.5% stays in the sun curve
0.5% goes to the protocol budget
```

moon mint and burn charge 5%.

```text
3% returns to the sun curve through burnAndRetain
2% goes to the protocol budget
```

supported sun/usdc and moon/usdc v4 pools may route fees back into the same sun
curve. third-party pools can exist, but they are market paths, not protocol
prices.

## § limits

sun mint has a per-transaction cap of 10,000 usdc.

moon mint has a per-transaction cap equal to 10,000 usdc worth of sun.

burns have no protocol-side size cap. moon mint can be time-gated at launch, but
after launch the curve remains open. it does not need a human to start, stop, or
graduate it.

## § no operator

the protocol is meant to have no active operator after setup.

```text
no owner mint
no reserve withdrawal
no pause switch
no upgrade switch
no manual price setting
no arbitrary curve rewrite
```

mathematics is the engine. philosophy is the direction.

code is law. math is nature.
