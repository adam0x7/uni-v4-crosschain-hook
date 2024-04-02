// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseHook} from "lib/v4-periphery/contracts/BaseHook.sol";
import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "lib/v4-core/src/types/PoolId.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "lib/v4-core/src/types/BalanceDelta.sol";
import {V3SpokePoolInterface} from "lib/contracts-v2/contracts/interfaces/V3SpokePoolInterface.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Currency} from "lib/v4-core/src/types/Currency.sol";

contract CrossChainHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;
    uint256 destinationChainId; 


    V3SpokePoolInterface public spokePoolV3;
    address public wethAddress;

    constructor(
        IPoolManager _poolManager, 
        V3SpokePoolInterface _spokePoolV3,
        address _wethAddress,
        uint256 _destinationChainId
    )
        BaseHook(_poolManager)
    {
        spokePoolV3 = _spokePoolV3;
        wethAddress = _wethAddress;
        destinationChainId = _destinationChainId;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            noOp: false,
            accessLock: false
        });
    }

function afterSwap(
    address sender,
    PoolKey calldata poolKey,
    IPoolManager.SwapParams calldata swapParams,
    BalanceDelta balanceDelta,
    bytes calldata data
) external override poolManagerOnly returns (bytes4) {
    require(Currency.unwrap(poolKey.currency1) == wethAddress, "Swapped token is not WETH");
    int128 amountWETHInt = balanceDelta.amount1();
    require(amountWETHInt >= 0, "Negative WETH balance change not allowed");
    uint128 amountWETHUnsigned = uint128(amountWETHInt);
    uint256 amountWETH = uint256(amountWETHUnsigned);

    _depositToSpokePool(amountWETH, data);

    return CrossChainHook.afterSwap.selector;
}

function _depositToSpokePool(uint256 amountWETH, bytes calldata data) internal {
    uint32 quoteTimestamp = uint32(block.timestamp);
    uint32 fillDeadline = quoteTimestamp + 1 hours;
    uint32 exclusivityDeadline = quoteTimestamp + 15 minutes;

    IERC20(wethAddress).approve(address(spokePoolV3), amountWETH);

    spokePoolV3.depositV3(
        msg.sender,
        msg.sender,
        wethAddress,
        wethAddress,
        amountWETH,
        amountWETH,
        destinationChainId,
        address(0),
        quoteTimestamp,
        fillDeadline,
        exclusivityDeadline,
        data
    );
}
}