# StacksLend - Bitcoin-Secured Decentralized Lending Protocol

[![Clarity](https://img.shields.io/badge/Clarity-3.0-blue)](https://clarity-lang.org/)
[![Stacks](https://img.shields.io/badge/Stacks-Layer%202-orange)](https://stacks.co/)
[![License](https://img.shields.io/badge/License-ISC-green)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-Vitest-brightgreen)](https://vitest.dev/)

> A sophisticated decentralized lending protocol that brings Bitcoin's unparalleled security to programmable lending markets through Stacks Layer 2 technology.

## 🌟 Overview

StacksLend revolutionizes decentralized finance by enabling users to participate in collateralized lending with the full security guarantees of Bitcoin's proof-of-work consensus while leveraging the smart contract capabilities of Clarity. The protocol allows users to deposit STX tokens as collateral and borrow against them in a trustless, decentralized manner.

### Key Features

- **🔒 Bitcoin Security**: Inherits Bitcoin's battle-tested security through Stacks consensus
- **💰 Collateralized Lending**: Over-collateralized lending with dynamic risk management
- **⚡ Real-time Liquidations**: Automated liquidation system protecting protocol solvency
- **📊 Health Monitoring**: Comprehensive position health tracking and analytics
- **🎯 Risk Parameters**: Sophisticated risk management with configurable parameters
- **🔧 Governance**: Owner-controlled parameter updates for protocol optimization

## 🏗️ Protocol Architecture

### Core Components

1. **Collateral Management**: Secure STX token deposits with position tracking
2. **Lending Engine**: Interest-bearing loans with compound interest calculations
3. **Liquidation System**: Automated position liquidation for undercollateralized loans
4. **Risk Management**: Dynamic health ratios and configurable risk parameters
5. **Analytics Dashboard**: Real-time protocol metrics and position monitoring

### Security Model

- **Minimum Collateral Ratio**: 150% (configurable)
- **Liquidation Threshold**: 125% (configurable)
- **Maximum Protocol Fee**: 10.00%
- **Interest Rate Cap**: 20.00% annually
- **Emergency Controls**: Circuit breaker functionality

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development environment
- [Node.js](https://nodejs.org/) (v16 or higher)
- [Stacks Wallet](https://www.hiro.so/wallet) for interaction

### Installation

```bash
# Clone the repository
git clone https://github.com/barth-cmd/stacks-lend.git
cd stacks-lend

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
npm test

# Format code
clarinet fmt --in-place
```

### Development

```bash
# Start Clarinet console
clarinet console

# Run specific test with coverage
npm run test:report

# Watch mode for development
npm run test:watch
```

## 📋 Usage Guide

### For Lenders (Collateral Providers)

#### 1. Deposit Collateral

```clarity
;; Deposit 1000 STX as collateral
(contract-call? .stacks-lend deposit-collateral u1000)
```

#### 2. Borrow Against Collateral

```clarity
;; Borrow 500 STX (assuming sufficient collateral)
(contract-call? .stacks-lend borrow-tokens u500)
```

#### 3. Repay Debt

```clarity
;; Repay 100 STX of outstanding debt
(contract-call? .stacks-lend repay-debt u100)
```

#### 4. Withdraw Excess Collateral

```clarity
;; Withdraw 200 STX collateral (if health ratio allows)
(contract-call? .stacks-lend withdraw-collateral u200)
```

### For Liquidators

#### Liquidate Unhealthy Positions

```clarity
;; Liquidate a position below liquidation threshold
(contract-call? .stacks-lend liquidate-position 'SP2...')
```

### Read-Only Functions

#### Check Position Health

```clarity
;; Get detailed position health information
(contract-call? .stacks-lend check-position-health 'SP2...')
```

#### Get Protocol Statistics

```clarity
;; Retrieve comprehensive protocol metrics
(contract-call? .stacks-lend get-protocol-statistics)
```

#### Calculate Borrowing Capacity

```clarity
;; Calculate maximum borrow amount for collateral
(contract-call? .stacks-lend calculate-max-borrow-amount u1000)
```

## 🔧 Protocol Parameters

### Risk Management

| Parameter | Default Value | Range | Description |
|-----------|---------------|-------|-------------|
| Minimum Collateral Ratio | 150% | 110% - 500% | Required health ratio for borrowing |
| Liquidation Threshold | 125% | 110% - MCR | Health ratio triggering liquidation |
| Protocol Fee | 1.00% | 0% - 10% | Fee on loan repayments |
| Base Interest Rate | 5.00% | 0% - 20% | Annual interest rate for borrowing |

### Liquidation Mechanics

- **Liquidation Penalty**: 5% of collateral value
- **Liquidator Reward**: 2.5% of collateral (50% of penalty)
- **Protocol Reward**: 2.5% of collateral (50% of penalty)
- **Self-Liquidation**: Prohibited for security

## 📊 Protocol Analytics

### Position Metrics

- Collateral deposited
- Amount borrowed
- Accrued interest
- Health score
- Liquidation risk assessment

### Global Statistics

- Total collateral locked
- Total tokens borrowed
- Protocol utilization rate
- Active positions count
- Protocol revenue

## 🔐 Security Features

### Access Controls

- **Protocol Owner**: Administrative functions restricted to deployer
- **Parameter Bounds**: All parameters validated against safe ranges
- **Emergency Pause**: Circuit breaker for critical situations

### Risk Mitigation

- **Over-collateralization**: Minimum 150% collateral ratio
- **Interest Accrual**: Compound interest prevents debt degradation
- **Liquidation Incentives**: Economic incentives for position maintenance
- **Health Monitoring**: Real-time position health tracking

## 🧪 Testing

The protocol includes comprehensive test coverage:

```bash
# Run all tests
npm test

# Run tests with coverage report
npm run test:report

# Watch mode for development
npm run test:watch
```

### Test Categories

- ✅ Collateral deposit/withdrawal
- ✅ Borrowing and repayment
- ✅ Interest calculation accuracy
- ✅ Liquidation mechanics
- ✅ Parameter validation
- ✅ Access control enforcement

## 🚨 Risk Considerations

### For Users

- **Liquidation Risk**: Positions may be liquidated if health ratio falls below threshold
- **Interest Accrual**: Outstanding debt grows over time with compound interest
- **Market Volatility**: STX price fluctuations affect collateral value
- **Smart Contract Risk**: Protocol subject to code vulnerabilities

### For Liquidators

- **MEV Competition**: Multiple liquidators may compete for profitable liquidations
- **Gas Costs**: Transaction fees may impact liquidation profitability
- **Slippage**: Rapid market movements may affect expected returns

## 🔮 Future Enhancements

### Planned Features

- [ ] Multi-asset collateral support
- [ ] Dynamic interest rates based on utilization
- [ ] Flash loan functionality
- [ ] Cross-chain bridge integration
- [ ] Governance token distribution
- [ ] Insurance fund mechanism

### Optimization Areas

- [ ] Gas optimization for batch operations
- [ ] Advanced liquidation algorithms
- [ ] MEV protection mechanisms
- [ ] Emergency oracle integration

## 🤝 Contributing

We welcome contributions to improve StacksLend! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Write tests** for your changes
4. **Run the test suite**: `npm test`
5. **Format your code**: `clarinet fmt --in-place`
6. **Submit a pull request**

### Development Guidelines

- Follow Clarity best practices
- Maintain comprehensive test coverage
- Document all public functions
- Use descriptive variable names
- Include inline comments for complex logic

## 📄 License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Documentation**: [Stacks Docs](https://docs.stacks.co/)
- **Clarity Language**: [Clarity Reference](https://docs.stacks.co/clarity/)
- **Stacks Blockchain**: [Stacks.co](https://stacks.co/)
- **Clarinet**: [Development Tools](https://github.com/hirosystems/clarinet)
