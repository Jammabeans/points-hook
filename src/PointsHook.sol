// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
 
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
 
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
 
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
 
import {Hooks} from "v4-core/libraries/Hooks.sol";
 
contract PointsHook is BaseHook, ERC1155, Ownable {
    uint256 BONUS_THRESHOLD = 0.0025 ether; // users will get bonus points for swaps over 0.0025 ETH more then the normal points calculation
    // This is 10% bonus points for swaps over the threshold
    uint256 BONUS_PERCENT = 10;
    uint256 BASE_POINTS_PERCENT = 20;

    event PointsMinted(address indexed user, uint256 indexed poolId, uint256 points);
    event BonusThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event BonusPercentUpdated(uint256 oldPercent, uint256 newPercent);
    event BasePointsPercentUpdated(uint256 oldPercent, uint256 newPercent);

    constructor(
        IPoolManager _manager
    ) BaseHook(_manager) Ownable(msg.sender) {}

    /// @notice Owner can update the bonus threshold (in wei)
    function setBonusThreshold(uint256 newThreshold) external onlyOwner {
        uint256 old = BONUS_THRESHOLD;
        BONUS_THRESHOLD = newThreshold;
        emit BonusThresholdUpdated(old, newThreshold);
    }

    /// @notice Owner can update the bonus percent (in %)
    function setBonusPercent(uint256 newPercent) external onlyOwner {
        uint256 old = BONUS_PERCENT;
        BONUS_PERCENT = newPercent;
        emit BonusPercentUpdated(old, newPercent);
    }

    /// @notice View the current bonus threshold
    function getBonusThreshold() external view returns (uint256) {
        return BONUS_THRESHOLD;
    }

    /// @notice View the current bonus percent
    function getBonusPercent() external view returns (uint256) {
        return BONUS_PERCENT;
    }

     
	    /// @notice Owner can update the base points percent (in %)
	    function setBasePointsPercent(uint256 newPercent) external onlyOwner {
	        uint256 old = BASE_POINTS_PERCENT;
	        BASE_POINTS_PERCENT = newPercent;
	        emit BasePointsPercentUpdated(old, newPercent);
	    }
	
	    /// @notice View the current base points percent
	    function getBasePointsPercent() external view returns (uint256) {
	        return BASE_POINTS_PERCENT;
	    }
	     
	// Set up hook permissions to return `true`
	// for the two hook functions we are using
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }
 
    // Implement the ERC1155 `uri` function
    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }
 
	// Stub implementation of `afterSwap`
	function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // If this is not an ETH-TOKEN pool with this hook attached, ignore
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);
    
        // We only mint points if user is buying TOKEN with ETH
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);    
               
    
        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
       

        uint256 pointsForSwap = (ethSpendAmount * BASE_POINTS_PERCENT) / 100;

        // Bonus 10% points if over threshold
        if (ethSpendAmount >= BONUS_THRESHOLD) {
            uint256 bonusPoints = (pointsForSwap * BONUS_PERCENT) / 100;
            pointsForSwap += bonusPoints;
        }
    
        // Mint the points
        _assignPoints(key.toId(), hookData, pointsForSwap);
    
        return (this.afterSwap.selector, 0);
    }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 points
    ) internal {
        // Must have at least 20 bytes to decode address
        if (hookData.length < 20) return;

        address user;
        assembly {
            user := calldataload(hookData.offset)
            // mask to get the lower 20 bytes (address size)
            user := and(user, 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
        }
    
        // If there is hookData but not in the format we're expecting and user address is zero
        // nobody gets any points
        if (user == address(0)) return;
        // If points is zero, no need to mint
        // This is a no-op, but we can save gas by not calling _mint
        if (points == 0) return;
    
        // Mint points to the user
        uint256 poolIdUint = uint256(PoolId.unwrap(poolId));
        _mint(user, poolIdUint, points, "");
        emit PointsMinted(user, poolIdUint, points);
    }
}