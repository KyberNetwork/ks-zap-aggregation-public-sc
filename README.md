# KS Zap Aggregation (public)

Public contracts of the KyberSwap zap flow. A zap moves liquidity into, out of or between
positions of an AMM or vault, as one call of an order of the allowance hub. The repository holds
the callee that runs the zap, the adapters of each source and the public interfaces of the adapters
and helpers. The helpers are implemented in a separate private repository.

## Contents

| Path | Contents |
| --- | --- |
| `src/AHV2ProxyCallee.sol` | Callee that calls or delegatecalls a list of callees in order |
| `src/adapters/<source>/` | One zap adapter per source: Aerodrome CL, Algebra V1.9, Algebra Integral V1.2, ALM vault (Steer, Gamma), BrownFi V3, Curve, EtherFi Liquid vault, Pancake Infinity, Solidly V2, Uniswap V2, V3 and V4 |
| `src/adapters/fee/ZapFeeAdapter.sol` | Transfers fees to their recipients, within the maximum fee rate the owner allows per recipient |
| `src/adapters/swap/ZapSwapAdapter.sol` | Swaps token balances through a swap target; a native input is sent as call value |
| `src/adapters/refund/ZapRefundAdapter.sol` | Last step of a composition: transfers each listed balance, less 1 wei, to the recipient |
| `src/base/ZapHelperCaller.sol` | Base of the adapters that delegatecall the pool swap of a helper |
| `src/base/CallbackDispatcher.sol` | Base of the adapters that receive callbacks from a source |
| `src/interfaces/adapters/` | Public interfaces of the adapters and of the helpers |

The repository also holds the leverage, lending and flash loan adapters under
`src/adapters/leverage/`, `src/adapters/lending/` and `src/adapters/flashloan/`, `KSSafeAccountHub`
in `src/KSSafeAccountHub.sol`, and vendored interfaces under `src/vendors/`. `FlashLoanAdapter` is
a callee of `AHV2ProxyCallee` that takes a flash loan and, in the callback, delegatecalls the
receiver that the owner signs. The receiver of a leverage order is `ZapLeverageAdapter`. The
leverage adapter swaps the loan and calls `KSSafeAccountHub`, which makes the Safe Account
delegatecall `ZapLeverageAdapter.modifyLeverage`.

## How the pieces fit

The allowance hub settles the order of the owner and calls `AHV2ProxyCallee` once. The proxy
callee verifies a signature of an account holding `SIGNER_ROLE` over the owner data and the solver
data, then runs the callees named in the owner data in order, by call or by delegatecall. A
delegatecalled adapter acts on the balances of the proxy. The owner data of each adapter carries the
limits the owner signed, and the solver data carries the values the solver chose, which the adapter
checks against those limits. Every composition ends with `ZapRefundAdapter`; a token balance below
its minimum stays in the proxy.

## Development

The default profile compiles with solc.

```sh
forge build
forge fmt
```

The `solar` profile compiles with Solar and is used during development.

```sh
FOUNDRY_PROFILE=solar forge build
```
