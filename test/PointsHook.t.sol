// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import {Test} from "forge-std/Test.sol";
 
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
 
import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
 
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
 
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
 
import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";
 
import "forge-std/console.sol";
import {PointsHook} from "../src/PointsHook.sol";
 
contract TestPointsHook is Test, Deployers, ERC1155TokenReceiver {
	MockERC20 token; // our token to use in the ETH-TOKEN pool
 
	// Native tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));
	Currency tokenCurrency;
 
	PointsHook hook;
 
	function setUp() public {
        // Step 1 + 2
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();
    
        // Deploy our TOKEN contract
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency = Currency.wrap(address(token));
    
        // Mint a bunch of TOKEN to ourselves and to address(1)
        token.mint(address(this), 1000 ether);
        token.mint(address(1), 1000 ether);
    
        // Deploy hook to an address that has the proper flags set
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo("PointsHook.sol", abi.encode(manager), address(flags));
    
        // Deploy our hook
        hook = PointsHook(address(flags));
    
        // Approve our TOKEN for spending on the swap router and modify liquidity router
        // These variables are coming from the `Deployers` contract
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);
    
        // Initialize a pool
        (key, ) = initPool(
            ethCurrency, // Currency 0 = ETH
            tokenCurrency, // Currency 1 = TOKEN
            hook, // Hook Contract
            3000, // Swap Fees
            SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
        );
    
        // Add some liquidity to the pool
        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);
    
        uint256 ethToAdd = 3 ether;
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            SQRT_PRICE_1_1,
            sqrtPriceAtTickUpper,
            ethToAdd
        );
        uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
            sqrtPriceAtTickLower,
            SQRT_PRICE_1_1,
            liquidityDelta
        );
    
        modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }
    // Test: TOKEN->ETH swap should NOT mint points
    function test_swap_token_for_eth_no_points() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

        // Set user address in hook data
        bytes memory hookData = abi.encode(address(this));

        // Approve ETH to the router (simulate receiving ETH)
        // Swap TOKEN for ETH (zeroForOne = false)
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: false,
                amountSpecified: int256(1 ether), // Exact output for input swap
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint);
        assertEq(pointsBalanceAfterSwap, pointsBalanceOriginal, "No points should be minted for TOKEN->ETH swap");
    }

    // Test: ETH->TOKEN swap with empty hookData should NOT mint points
    function test_swap_eth_for_token_no_hookdata() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

        // Empty hookData
        bytes memory hookData = "";

        swapRouter.swap{value: 0.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint);
        assertEq(pointsBalanceAfterSwap, pointsBalanceOriginal, "No points should be minted if hookData is empty");
    }

    // Test: ETH->TOKEN swap with hookData as address(0) should NOT mint points
    function test_swap_eth_for_token_zero_address() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

        // hookData is address(0)
        bytes memory hookData = abi.encode(address(0));

        swapRouter.swap{value: 0.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint);
        assertEq(pointsBalanceAfterSwap, pointsBalanceOriginal, "No points should be minted if hookData is address(0)");
    }

    // Test: ETH->TOKEN swap with amount too small to mint points
    function test_swap_eth_for_token_too_small() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

        // Set user address in hook data
        bytes memory hookData = abi.encode(address(this));

        // Swap a very small amount of ETH (less than 5 wei, so pointsForSwap = 0)
        swapRouter.swap{value: 3}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(3),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint);
        assertEq(pointsBalanceAfterSwap, pointsBalanceOriginal, "No points should be minted for tiny ETH swap");
    }

    // Test: Multiple swaps by the same user accumulate points
    function test_multiple_swaps_accumulate_points() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        bytes memory hookData = abi.encode(address(this));
        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

        // First swap
        swapRouter.swap{value: 0.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        // Second swap
        swapRouter.swap{value: 0.002 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.002 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        uint256 pointsBalanceAfter = hook.balanceOf(address(this), poolIdUint);
        // 0.001/5 + 0.002/5 = 0.0006 ether = 6 * 10**14
        assertEq(pointsBalanceAfter - pointsBalanceOriginal, 6 * 10 ** 14, "Points should accumulate over multiple swaps");
    }

    function test_bonus_points_single_large_swap() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        bytes memory hookData = abi.encode(address(this));
        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);
        console.log("Initial points balance:", pointsBalanceOriginal);

        // Swap amount exactly at or above the threshold (10 ETH)
        uint256 ethSwapAmount = 0.003 ether;

        // Perform swap
        swapRouter.swap{value: ethSwapAmount}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(ethSwapAmount),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );

        uint256 pointsAfter = hook.balanceOf(address(this), poolIdUint);
        console.log("Points after large swap:", pointsAfter);

        // Base points = 20% of ETH spent
        uint256 basePoints = ethSwapAmount / 5;

        // Bonus points = 10% of base points
        uint256 bonusPoints = (basePoints * 10) / 100;
        console.log("Base points:", basePoints);
        console.log("Bonus points:", bonusPoints);  

        uint256 expectedPoints = basePoints + bonusPoints;

        assertEq(
            pointsAfter ,
            expectedPoints,
            "Points after large swap should include 10% bonus"
        );
    }

    // Test: Swaps by different users mint points to correct address
    function test_points_minted_to_correct_user() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        address user1 = address(this);
        address user2 = address(0xBEEF);
        bytes memory hookData1 = abi.encode(user1);
        bytes memory hookData2 = abi.encode(user2);

        // Swap for user1
        swapRouter.swap{value: 0.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData1
        );
        // Swap for user2
        vm.deal(user2, 1 ether); // Give user2 some ETH
        vm.prank(user2);
        swapRouter.swap{value: 0.002 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.002 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData2
        );
        // Check balances
        assertEq(hook.balanceOf(user1, poolIdUint), 2 * 10 ** 14, "User1 should have points for their swap");
        assertEq(hook.balanceOf(user2, poolIdUint), 4 * 10 ** 14, "User2 should have points for their swap");
    }

    // Test: PointsMinted event is emitted with correct parameters
    function test_points_minted_event_emitted() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        bytes memory hookData = abi.encode(address(this));
        vm.expectEmit(true, true, false, true);
        emit PointsHook.PointsMinted(address(this), poolIdUint, 2 * 10 ** 14);
        swapRouter.swap{value: 0.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
    }

    // Test: Malformed hookData does not revert and does not mint points
    function test_malformed_hookdata_no_points() public {
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

        // Malformed hookData (random bytes, not an address)
        bytes memory hookData = hex"deadbeef";
        swapRouter.swap{value: 0.001 ether}(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            hookData
        );
        uint256 pointsBalanceAfter = hook.balanceOf(address(this), poolIdUint);
        assertEq(pointsBalanceAfter, pointsBalanceOriginal, "Malformed hookData should not mint points");
    }


// Test: Owner can update bonus threshold and it affects swap behavior
function test_owner_can_update_bonus_threshold() public {
    uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
    bytes memory hookData = abi.encode(address(this));

    // Set a new threshold higher than the swap amount
    hook.setBonusThreshold(0.01 ether);

    // Swap below new threshold, should get no bonus
    uint256 ethSwapAmount = 0.003 ether;
    uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

    swapRouter.swap{value: ethSwapAmount}(
        key,
        SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(ethSwapAmount),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }),
        PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        }),
        hookData
    );

    uint256 pointsAfter = hook.balanceOf(address(this), poolIdUint);
    uint256 expectedPoints = ethSwapAmount / 5; // No bonus
    assertEq(pointsAfter - pointsBalanceOriginal, expectedPoints, "No bonus should be applied below new threshold");

    // Now set threshold below swap amount
    hook.setBonusThreshold(0.001 ether);

    // Swap again, should get bonus
    pointsBalanceOriginal = pointsAfter;
    swapRouter.swap{value: ethSwapAmount}(
        key,
        SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(ethSwapAmount),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }),
        PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        }),
        hookData
    );
    pointsAfter = hook.balanceOf(address(this), poolIdUint);
    uint256 basePoints = ethSwapAmount / 5;
    uint256 bonusPoints = (basePoints * hook.getBonusPercent()) / 100;
    expectedPoints = basePoints + bonusPoints;
    assertEq(pointsAfter - pointsBalanceOriginal, expectedPoints, "Bonus should be applied above new threshold");
}

// Test: Owner can update bonus percent and it affects bonus calculation
function test_owner_can_update_bonus_percent() public {
    uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
    bytes memory hookData = abi.encode(address(this));

    // Set threshold low so bonus always applies
    hook.setBonusThreshold(0.001 ether);

    // Set bonus percent to 50%
    hook.setBonusPercent(50);

    uint256 ethSwapAmount = 0.003 ether;
    uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

    swapRouter.swap{value: ethSwapAmount}(
        key,
        SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(ethSwapAmount),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }),
        PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        }),
        hookData
    );

    uint256 pointsAfter = hook.balanceOf(address(this), poolIdUint);
    uint256 basePoints = ethSwapAmount / 5;
    uint256 bonusPoints = (basePoints * 50) / 100;
    uint256 expectedPoints = basePoints + bonusPoints;
    assertEq(pointsAfter - pointsBalanceOriginal, expectedPoints, "Bonus percent should be updated and applied correctly");
}
    
// Test: Owner can update base points percent and it affects points calculation
function test_owner_can_update_base_points_percent() public {
    uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
    bytes memory hookData = abi.encode(address(this));

    // Set threshold low so bonus always applies
    hook.setBonusThreshold(0.001 ether);

    // Set base points percent to 50%
    hook.setBasePointsPercent(50);

    uint256 ethSwapAmount = 0.003 ether;
    uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

    swapRouter.swap{value: ethSwapAmount}(
        key,
        SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(ethSwapAmount),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }),
        PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        }),
        hookData
    );

    uint256 pointsAfter = hook.balanceOf(address(this), poolIdUint);
    uint256 basePoints = (ethSwapAmount * 50) / 100;
    uint256 bonusPoints = (basePoints * hook.getBonusPercent()) / 100;
    uint256 expectedPoints = basePoints + bonusPoints;
    assertEq(pointsAfter - pointsBalanceOriginal, expectedPoints, "Base points percent should be updated and applied correctly");
}
}