# Advantage Asymmetry Frontend

This directory contains the web interface for the Advantage Asymmetry technical demo.

## Architecture

The canonical smart-contract implementation lives at the repository root:

- ../contracts/AdvantageAsymmetryCampaign.sol
- ../test/
- ../foundry.toml

The root Foundry project is the source of truth for contract development, testing, and deployment.

This frontend directory contains the Scaffold-ETH 2 / Next.js interface used to interact with the deployed contract.

## Frontend Stack

- Next.js
- React
- TypeScript
- Scaffold-ETH 2
- RainbowKit
- Wagmi
- Viem

## Contract Integration

The frontend connects to the deployed Advantage Asymmetry contract through packages/nextjs/contracts/externalContracts.ts.

The intended demo network is Ethereum Sepolia.

## Development

Install frontend dependencies with yarn install.

Start the frontend with yarn start.

Smart-contract compilation, testing, and deployment should be performed from the repository root using Foundry, not from this directory.

## License

This frontend incorporates Scaffold-ETH 2 components distributed under the MIT License. See LICENCE.
