# TipToken (ERC20-T)

A custom ERC20 token with tipping functionality that allows authorized addresses to mint new tokens as tips.

## Features

- Standard ERC20 functionality (transfer, approve, transferFrom)
- EIP-2612 permit support for gasless approvals
- Tipping system where authorized addresses can mint tokens to recipients
- Owner-controlled tip allowances

## Setup

1. Install dependencies:
```bash
forge install
```

2. Create a `.env` file based on `.env.example`:
```bash
cp .env.example .env
```

3. Add your private key and RPC URLs to `.env`

## Deployment

### Deploy to Local Network (Anvil)

1. Start a local node:
```bash
anvil
```

2. Deploy (in another terminal):
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast
```

### Deploy to Sepolia Testnet

```bash
source .env
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

### Deploy to Mainnet

```bash
source .env
forge script script/Deploy.s.sol:DeployScript --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## Contract Interaction

### Set Tip Allowances (Owner only)

```bash
cast send <TOKEN_ADDRESS> \
  "updateTipAllowances(address[],uint256[])" \
  "[0xAddress1,0xAddress2]" "[1000000000000000000000,500000000000000000000]" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### Tip Tokens (Authorized tippers only)

```bash
cast send <TOKEN_ADDRESS> \
  "tip(address,uint256)" \
  <RECIPIENT_ADDRESS> 1000000000000000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### Check Balances

```bash
cast call <TOKEN_ADDRESS> "balanceOf(address)" <ADDRESS> --rpc-url $RPC_URL
```

### Check Tip Allowance

```bash
cast call <TOKEN_ADDRESS> "tipAllowance(address)" <ADDRESS> --rpc-url $RPC_URL
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## License

MIT
