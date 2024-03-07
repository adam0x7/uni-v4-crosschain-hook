# Uniswap V4 🤝 Across Protocol Hook
![Hook Art](/hook_art.webp)
This is cross-chain hook designed to facilitate asset transfers / swaps from Ethereum L1 to any ETH L2, leveraging the Across Protocol for efficient and secure bridging. The process integrates smart contract operations with off-chain logic managed by a frontend application, ensuring a seamless user experience for cross-chain transactions.


## Process Overview

The transfer and swap process involves several key steps, from the initial user action in the frontend application to the final receipt of the desired token on L2. Here's how it works:

### 1. **User Selection and Transfer Initiation**

- **User Interaction**: The user accesses a frontend application, where they select the chain and the specific token they wish to swap for on the L2.
- **Transfer Trigger**: The user initiates the transfer process through the frontend interface.

### 2. **Automatic Swap to WETH on L1**

- **Token Swap**: The user's selected token is automatically swapped for Wrapped Ethereum (WETH) on L1 using and the `afterSwap` hook bridges WETH to the desired L2 network.

### 3. **Airdrop to User**
- **Relayers**: Across protocol relayers facilitate the transfer and airdrop WETH to the user's address on L2.

### 4. **Token Swap on L2**
- **Token Swap**: The user's WETH is automatically swapped for the desired token on L2 using the `afterSwap` hook.





