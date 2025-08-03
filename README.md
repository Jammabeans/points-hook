# PointsHook

PointsHook is a Uniswap v4 hook that rewards users with ERC1155 "points" tokens for swapping ETH for a specific ERC20 token in a pool with this hook attached. This project demonstrates advanced Uniswap v4 hook development, ERC1155 minting, and comprehensive testing using Foundry.

## How It Works

- **PointsHook** is attached to a Uniswap v4 pool.
- When a user swaps ETH for a token (ETH → TOKEN) in a pool with this hook, the hook mints ERC1155 points to the user.
- The number of points minted is proportional to the ETH spent (`points = ethAmount / 5`).
- Points are minted as ERC1155 tokens, with the poolId as the token id.
- Points are only minted for ETH → TOKEN swaps, and only if the user address is provided in the swap's hookData.

## Reward Settings

The contract owner can adjust all reward parameters at any time:

- **Base Points Percent:** The percentage of ETH spent that is awarded as base points for every eligible swap. Set via `setBasePointsPercent(uint256 newPercent)`. Default is 20%.
- **Bonus Threshold:** The minimum ETH amount required in a swap to receive a bonus. Set via `setBonusThreshold(uint256 newThreshold)`.
- **Bonus Percent:** The percentage bonus applied to swaps above the threshold. Set via `setBonusPercent(uint256 newPercent)`.

These settings can be updated by the owner, and changes take effect immediately for subsequent swaps.

## Features

- Uniswap v4 hook integration
- ERC1155 points minting
- Permissioned hook logic (only afterSwap enabled)
- Comprehensive test suite
- Owner can adjust base points percent, bonus threshold, and bonus percent at any time

## Test Coverage

The project includes 11 comprehensive tests (see [`test/PointsHook.t.sol`](test/PointsHook.t.sol)):

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

- **test_owner_can_update_bonus_threshold:**
  Owner can update the bonus threshold and swaps reflect the new setting.

- **test_owner_can_update_bonus_percent:**
  Owner can update the bonus percent and swaps reflect the new setting.

- **test_owner_can_update_base_points_percent:**
  Owner can update the base points percent and swaps reflect the new setting.

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

All 11 tests should pass, confirming correct PointsHook behavior.

## Project Structure

- `src/PointsHook.sol` — The PointsHook contract
- `test/PointsHook.t.sol` — Comprehensive test suite
- `foundry.toml` — Foundry configuration

## License

MIT
