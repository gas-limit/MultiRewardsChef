# MultiRewardsChef

This repository offers a suite of smart contracts designed to facilitate multi-token reward distribution across various DeFi scenarios. Developed using Foundry, these contracts are open-source and intended as a public good to benefit the broader blockchain community.

---

## Disclaimer

**Important**: These contracts have not undergone formal security audits. They are provided "as-is" without any warranties or guarantees. The author assumes no responsibility for any issues, losses, or damages arising from the use of this code. Users are advised to conduct their own thorough testing and audits before deploying these contracts in a production environment.

---

## Contracts Overview

1. **StandaloneRewarder**: Enables direct token staking and rewards without external dependencies.
2. **MasterChefRewarder**: Integrates with MasterChef to provide multi-token rewards for liquidity providers.
3. **ChefIncentivesRewarder**: Extends ChefIncentivesController, rewarding users holding aTokens or LP tokens.

Each directory includes a README.md file with detailed information on the contract's purpose, implementation instructions, and usage examples.

---

## Getting Started

Ensure Foundry is installed. If not, follow the instructions at [Foundry's official site](https://getfoundry.sh).

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/gas-limit/MultiRewardsChef.git
   cd MultiRewardsChef
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

### Build the Project

Compile the contracts:
```bash
forge build
```

### Run Tests

Execute the test suite:
```bash
forge test
```

---

## Contribution

Contributions are welcome. To contribute:

1. Fork the repository.
2. Create a new branch:
   ```bash
   git checkout -b feature-name
   ```
3. Commit your changes:
   ```bash
   git commit -m "Description of changes"
   ```
4. Push the branch:
   ```bash
   git push origin feature-name
   ```
5. Open a pull request.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Acknowledgment

This project is released as a public good to support and enhance the DeFi ecosystem. For questions or support, please open an issue on GitHub. 