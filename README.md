# BitVault Protocol: Bitcoin-Backed Stablecoin System

**Layer**: Stacks (Bitcoin Layer 2)  
**Contract Type**: Collateralized Debt Position (CDP) Manager

## Overview

A non-custodial DeFi primitive enabling Bitcoin holders to mint stablecoins while maintaining custody of their collateral. Implements risk management mechanisms compliant with Bitcoin's security model through Stacks L2.

### Key Features

- BTC-collateralized stablecoin issuance
- Dynamic collateral ratio enforcement
- Decentralized liquidation engine
- Time-decayed price oracle system
- Anti-fragility mechanisms against market manipulation

## Technical Specifications

### System Parameters

| Parameter              | Value             | Description                     |
| ---------------------- | ----------------- | ------------------------------- |
| `MIN-COLLATERAL-RATIO` | 150%              | Minimum collateralization ratio |
| `LIQUIDATION-RATIO`    | 120%              | Liquidation threshold           |
| `MIN-DEPOSIT`          | 0.01 BTC          | Minimum collateral deposit      |
| `MAX-DEPOSIT`          | 10,000 BTC        | Maximum position size           |
| `PRICE-VALIDITY`       | 144 blocks (~24h) | Oracle data expiration          |

### Error Codes

| Code  | Constant                      | Description                       |
| ----- | ----------------------------- | --------------------------------- |
| u1000 | `ERR-NOT-AUTHORIZED`          | Unauthorized access attempt       |
| u1001 | `ERR-INSUFFICIENT-COLLATERAL` | Collateral below required ratio   |
| u1002 | `ERR-BELOW-MINIMUM`           | Operation below minimum threshold |
| u1003 | `ERR-INVALID-AMOUNT`          | Invalid numeric input             |
| u1004 | `ERR-POSITION-NOT-FOUND`      | Non-existent user position        |

## Core Functionality

### 1. Collateral Management

- **Deposit Mechanism**:  
  `deposit-collateral(uint)`

  - Requires minimum 0.01 BTC deposit
  - Enforces 10,000 BTC ceiling per position
  - Updates position health in real-time

- **Withdrawal Protocol**:  
  `withdraw-collateral(uint)`
  - Prohibits withdrawals below 150% collateral ratio
  - Requires full debt repayment before full withdrawal

### 2. Stablecoin Operations

- **Minting Process**:  
  `mint-stablecoin(uint)`

  - Verifies price feed freshness
  - Calculates collateral value using:  
    `(BTC Amount × BTC Price) / Debt ≥ 1.5`
  - Updates global debt ledger

- **Repayment System**:  
  `repay-stablecoin(uint)`
  - Allows partial/full debt repayment
  - Burns repaid stablecoins from supply
  - Recalculates collateral ratio post-repayment

### 3. Liquidation Engine

- **Trigger Conditions**:  
  `liquidate-position(principal)`

  - Position health < 120% collateral ratio
  - Stale price data validation
  - Open liquidation to any network participant

- **Liquidation Process**:
  1. Permanent record in liquidation history
  2. Complete debt cancellation
  3. Collateral forfeiture
  4. Global supply adjustment

### 4. Oracle Integration

- **Price Updates**:  
  `set-price(uint)` (Oracle-only)

  - Enforced maximum price ceiling
  - Block-height timestamping
  - Authorization-limited access

- **Oracle Management**:  
  `set-price-oracle(principal)` (Owner-only)
  - Multi-sig capable principal
  - Prevention of duplicate assignments

## Security Architecture

### Risk Mitigation

1. **Over-Collateralization**  
   Minimum 150% collateral ratio maintained through:

   - Real-time position health checks
   - Withdrawal pre-approval system

2. **Oracle Safeguards**

   - Price validity window (144 blocks)
   - Maximum price ceiling ($1B/BTC)
   - Multi-layer authorization

3. **Anti-Manipulation**

   - Deposit size constraints
   - Time-locked position updates
   - Liquidation incentive structure

4. **Fail-Safe Mechanisms**
   - Zero-tolerance for stale prices
   - Position freeze on liquidation
   - Debt ceiling enforcement

## Usage Examples

### Basic Workflow

1. **Collateral Deposit**

   ```clarity
   (deposit-collateral u5000000)  ;; 0.05 BTC
   ```

2. **Stablecoin Minting**

   ```clarity
   (mint-stablecoin u200000)  ;; $200 USD equivalent
   ```

3. **Debt Repayment**

   ```clarity
   (repay-stablecoin u50000)  ;; Partial repayment
   ```

4. **Collateral Withdrawal**
   ```clarity
   (withdraw-collateral u1000000)  ;; 0.01 BTC
   ```

### Liquidation Flow

```clarity
;; 1. Check position health
(get-collateral-ratio 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR)

;; 2. Execute liquidation
(liquidate-position 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR)
```
