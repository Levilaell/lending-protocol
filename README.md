# Lending Protocol

A decentralized lending protocol built in Solidity, inspired by Aave. Users deposit collateral to borrow against it, while liquidators maintain protocol solvency by liquidating undercollateralized positions.

## Overview

The protocol operates on a two-token model: a collateral token (e.g. ETH) and a borrow token (e.g. USDC). Users deposit collateral, borrow up to 75% of its value, repay their debt, and can be liquidated if their position becomes insolvent.

## Architecture

```
LendingProtocol.sol   — core protocol logic
MockOracle.sol        — price feed for testing (simulates Chainlink)
```

### Key Parameters

| Parameter         | Value | Description                      |
| ----------------- | ----- | -------------------------------- |
| LTV               | 75%   | Maximum loan-to-value ratio      |
| Liquidation Bonus | 10%   | Profit incentive for liquidators |

### Position Tracking

Each user has an independent position tracked via a struct:

```solidity
struct Position {
    uint collateral;  // amount of collateral deposited
    uint debt;        // amount of borrow token owed
}

mapping(address => Position) public positions;
```

## Core Functions

### `deposit(uint amount)`

Deposits collateral token into the protocol. Requires prior `approve` on the collateral token.

```
User → transferFrom → Contract
collateral token locked, position.collateral increases
```

### `borrow(uint amount)`

Borrows against deposited collateral. The maximum borrow is constrained by LTV:

```
maxBorrow = (collateral * price / 1e18) * LTV / 100
available = maxBorrow - existing debt
```

```
Contract → transfer → User
borrow token sent to user, position.debt increases
```

### `repay(uint amount)`

Repays an outstanding debt. Amount cannot exceed current debt balance.

```
User → transferFrom → Contract
borrow token returned, position.debt decreases
```

### `liquidate(address borrower, uint debtToPay)`

Allows anyone to liquidate an insolvent position. A position is insolvent when:

```
debt > (collateral * price / 1e18) * LTV / 100
```

The liquidator pays the borrower's debt and receives collateral at a 10% discount:

```
collateralSeized = (debtToPay * 1e18 / price) * 110 / 100

Liquidator → pays USDC → Contract
Contract   → sends ETH (+ 10% bonus) → Liquidator
```

## Liquidation Example

```
Alice deposits:  1 ETH ($2,000)
Alice borrows:   $1,400 USDC (LTV: 70%)

ETH drops to $1,600:
  Current LTV: $1,400 / $1,600 = 87.5% → insolvent

Bob liquidates $1,400:
  Bob pays:     $1,400 USDC
  Bob receives: 0.9625 ETH ($1,540) — $140 profit
  Alice keeps:  0.0375 ETH ($60)
  Alice owes:   $0
```

## Price Oracle

The protocol uses an `IOracle` interface, decoupling it from any specific implementation:

```solidity
interface IOracle {
    function getPrice() external view returns (uint);
}
```

In production, this can be swapped for a Chainlink price feed without changing the protocol logic. For testing, `MockOracle.sol` allows manual price setting to simulate market conditions and trigger liquidations.

## Security Considerations

- **CEI Pattern**: All state changes occur before external calls to prevent reentrancy
- **LTV buffer**: The gap between LTV (75%) and liquidation threshold (~83%) provides margin for the liquidation bonus
- **Pending improvements**: SafeERC20 for unchecked transfer protection, precision optimization (multiply before divide), named imports

## Tech Stack

- Solidity `^0.8.13`
- [Foundry](https://book.getfoundry.sh/) — build, test, deploy
- [OpenZeppelin](https://openzeppelin.com/contracts/) — IERC20

## Getting Started

```bash
git clone <repo>
cd lending-protocol
forge install
forge build
forge test -vv
```

## Deployments

| Network | Contract        | Address                                      |
| ------- | --------------- | -------------------------------------------- |
| Sepolia | LendingProtocol | `0xc190c646745e90678cc3eb55290c476c5dbee678` |
| Sepolia | MockOracle      | `0xa2af75d2d6b6ca7296272720b155b1d4b94116ef` |

## License

MIT
