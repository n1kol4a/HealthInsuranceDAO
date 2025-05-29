# HealthInsuranceDAO

A modular, DAO-governed smart contract system for blockchain-based health coverage. Built with Foundry and OpenZeppelin Contracts.

## 📁 Contracts Overview

### `HealthInsuranceDAO.sol`
- Core contract for:
  - User registration via ETH payments
  - Membership tier selection
  - Claim submission and tracking
  - Fund routing to developer vault
- Defines coverage packages (Basic, Standard, Premium)
- Stores per-user payment history and coverage data

### `InsuranceToken.sol`
- ERC20 token with `ERC20Votes`, `ERC20Permit`, and `Ownable`
- Used for DAO governance
- Supports minting and delegation

### `MyGovernor.sol`
- Governance contract using OpenZeppelin Governor
- Quorum: 10 tokens
- Voting delay: 1 block (~12s)
- Voting period: 5 blocks (~1 min)

### `DevVault.sol`
- Ownable vault for collecting dev fees (5% of user payments)
- Manual withdrawals by owner

---

## 🔧 Tech Stack

- **Foundry** (Forge, Anvil)
- **Solidity 0.8.27**
- **OpenZeppelin Contracts v5**
- **Sepolia testnet**

---

## ⚙️ Deployment

1. Clone the repo:
```bash
git clone https://github.com/n1kol4a/HealthInsuranceDAO
cd HealthInsuranceDAO
