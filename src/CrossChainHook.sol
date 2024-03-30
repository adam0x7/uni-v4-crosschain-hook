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

    V3SpokePoolInterface public spokePoolV3;
    address public wethAddress;

    constructor(
        IPoolManager _poolManager, 
        V3SpokePoolInterface _spokePoolV3,
        address _wethAddress
    )
        BaseHook(_poolManager)
    {
        spokePoolV3 = _spokePoolV3;
        wethAddress = _wethAddress;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
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

        // Assuming you have these values available or calculated earlier in your function
        uint256 destinationChainId = 10; // For example, for Optimism
        uint32 quoteTimestamp = uint32(block.timestamp); // Simplified example, adjust as needed
        uint32 fillDeadline = quoteTimestamp + 1 hours; // Example deadline, adjust as needed
        uint32 exclusivityDeadline = quoteTimestamp + 15 minutes; // Example deadline, adjust as needed

        // Approve the V3 SpokePool to spend WETH
        IERC20(wethAddress).approve(address(spokePoolV3), amountWETH);

        // Call depositV3 on the V3 SpokePool
        spokePoolV3.depositV3(
            sender, // depositor
            sender, // recipient on the destination chain
            wethAddress, // inputToken (WETH)
            wethAddress, // outputToken (WETH, assuming no change)
            amountWETH, // inputAmount
            amountWETH, // outputAmount, assuming no fees for simplicity
            destinationChainId,
            address(0),
            quoteTimestamp,
            fillDeadline,
            exclusivityDeadline,
            data // forwarding data to the recipient
        );

        return CrossChainHook.afterSwap.selector;
    }
}