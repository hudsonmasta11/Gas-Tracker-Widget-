# ⛽ Gas Tracker Widget

📊 A comprehensive smart contract for tracking and analyzing gas consumption patterns on the Stacks blockchain - teaching EVM gas insights through practical implementation.

## 🚀 Overview

The Gas Tracker Widget is a Clarity smart contract that provides detailed insights into transaction costs and gas consumption patterns. It helps developers and users understand gas optimization, track efficiency metrics, and make informed decisions about transaction timing and function usage.

## ✨ Features

### 📈 Transaction Tracking
- **Real-time monitoring** of function calls and their associated costs
- **Historical data** storage for trend analysis
- **User-specific statistics** including efficiency scores

### 💰 Gas Price Analytics
- **Base fee tracking** with priority fee calculations
- **Network congestion** monitoring and alerts
- **Price prediction** based on historical patterns

### 🎯 Efficiency Metrics
- **Personal efficiency scores** compared to network averages
- **Function-specific** gas consumption analytics
- **Daily statistics** aggregation for trend identification

### 🔍 Predictive Analysis
- **Gas cost prediction** for specific functions
- **Confidence intervals** based on historical data
- **Network congestion** level assessment

## 🛠️ Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd gas-tracker-widget
   ```

2. **Install Clarinet:**
   ```bash
   npm install -g @hirosystems/clarinet-cli
   ```

3. **Initialize the project:**
   ```bash
   clarinet check
   ```

## 📖 Usage

### 🔵 Core Functions

#### Track Transaction
Record a new transaction with its gas consumption:
```clarity
(contract-call? .gas-tracker-widget track-transaction "transfer" u1000 u950)
```

#### Update Gas Prices
Record current network gas prices:
```clarity
(contract-call? .gas-tracker-widget update-gas-price u50 u10 u75)
```

#### Set Efficiency Goal
Set a personal gas efficiency target:
```clarity
(contract-call? .gas-tracker-widget set-efficiency-goal u800)
```

### 📊 Analytics Functions

#### Get User Statistics
```clarity
(contract-call? .gas-tracker-widget get-user-stats 'SP1234567890...)
```

#### Predict Gas Costs
```clarity
(contract-call? .gas-tracker-widget predict-gas-cost "transfer")
```

#### Compare Efficiency
```clarity
(contract-call? .gas-tracker-widget compare-user-efficiency 'SP1234567890...)
```

#### Get Network Congestion
```clarity
(contract-call? .gas-tracker-widget get-network-congestion-level)
```

## 📋 Data Structures

### 👤 User Stats
```clarity
{
  transactions: uint,
  gas-consumed: uint,
  avg-gas-per-tx: uint,
  last-interaction: uint,
  efficiency-score: uint
}
```

### 📝 Transaction History
```clarity
{
  sender: principal,
  function-name: string,
  gas-estimate: uint,
  actual-cost: uint,
  timestamp: uint,
  block-height: uint
}
```

### 💹 Gas Price History
```clarity
{
  base-fee: uint,
  priority-fee: uint,
  timestamp: uint,
  network-congestion: uint
}
```

## 🎮 Example Workflow

1. **🚀 Initialize tracking** by calling `track-transaction` for your functions
2. **📊 Monitor patterns** using `get-user-stats` to see your efficiency
3. **🎯 Set goals** with `set-efficiency-goal` to improve performance
4. **🔮 Predict costs** using `predict-gas-cost` before expensive operations
5. **📈 Analyze trends** with `get-gas-trend` for strategic timing

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 📊 Key Metrics Explained

- **⚡ Efficiency Score**: Ratio of target gas to actual average gas usage
- **🌡️ Network Congestion**: Scale of 0-100 indicating network busy-ness  
- **📈 Percentile Ranking**: Your efficiency compared to all users
- **🎯 Confidence Level**: Reliability of gas predictions based on data samples

## 🔒 Security Features

- **👑 Owner-only controls** for contract management
- **✅ Input validation** on all parameters
- **🛡️ Error handling** with descriptive error codes
- **🔐 Access control** for sensitive operations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🙋‍♂️ Support

Having issues? Check out the documentation or open an issue on GitHub.

---

*Built with ❤️ for the Stacks ecosystem*
