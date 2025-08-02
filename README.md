# PointsHook

PointsHook is a Uniswap v4 hook that rewards users with ERC1155 "points" tokens for swapping ETH for a specific ERC20 token in a pool with this hook attached. This project demonstrates advanced Uniswap v4 hook development, ERC1155 minting, and comprehensive testing using Foundry.

## How It Works

- **PointsHook** is attached to a Uniswap v4 pool.
- When a user swaps ETH for a token (ETH → TOKEN) in a pool with this hook, the hook mints ERC1155 points to the user.
- The number of points minted is proportional to the ETH spent (`points = ethAmount / 5`).
- Points are minted as ERC1155 tokens, with the poolId as the token id.
- Points are only minted for ETH → TOKEN swaps, and only if the user address is provided in the swap's hookData.

## Features

- Uniswap v4 hook integration
- ERC1155 points minting
- Permissioned hook logic (only afterSwap enabled)
- Comprehensive test suite

## Test Coverage

The project includes 8 comprehensive tests (see [`test/PointsHook.t.sol`](test/PointsHook.t.sol)):

- **test_swap_token_for_eth_no_points:**  
  Swapping TOKEN → ETH does not mint points.

- **test_swap_eth_for_token_no_hookdata:**  
  ETH → TOKEN swap with empty hookData does not mint points.

- **test_swap_eth_for_token_zero_address:**  
  ETH → TOKEN swap with hookData as address(0) does not mint points.

- **test_swap_eth_for_token_too_small:**  
  ETH → TOKEN swap with too little ETH (less than 5 wei) does not mint points.

- **test_malformed_hookdata_no_points:**  
  Malformed hookData (random bytes) does not revert and does not mint points.

- **test_multiple_swaps_accumulate_points:**  
  Multiple ETH → TOKEN swaps by the same user accumulate points correctly.

- **test_points_minted_to_correct_user:**  
  Points are minted to the correct user address as specified in hookData.

- **test_points_minted_event_emitted:**  
  The `PointsMinted` event is emitted with correct parameters on a successful mint.

## Setup

1. **Install [Foundry](https://book.getfoundry.sh/getting-started/installation):**
   ```sh
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone the repository and initialize submodules:**
   ```sh
   git clone <repo-url>
   cd points-hook
   git submodule update --init --recursive
   ```

3. **Install dependencies:**
   ```sh
   forge install
   ```

## Running Tests

To run the full test suite:

```sh
forge test
```

All 8 tests should pass, confirming correct PointsHook behavior.

## Project Structure

- `src/PointsHook.sol` — The PointsHook contract
- `test/PointsHook.t.sol` — Comprehensive test suite
- `foundry.toml` — Foundry configuration

## License

MIT
