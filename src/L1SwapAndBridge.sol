// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import "@across/contracts/interfaces/SpokePoolInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract L1SwapAndBridgeHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    SpokePoolInterface public spokePool;
    address public wethAddress;

    constructor(
        IPoolManager _poolManager, 
        SpokePoolInterface _spokePool,
        address _wethAddress
    )
        BaseHook(_poolManager)
    {
        spokePool = _spokePool;
        wethAddress = _wethAddress;
    }

    function afterSwap(
        address sender,
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta calldata balanceDelta,
        bytes calldata data
    ) external override poolManagerOnly returns (bytes4) {
        // Ensure the swapped token is WETH
        require(poolKey.token1 == wethAddress, "Swapped token is not WETH");

        // Calculate the amount of WETH obtained from the swap
        uint256 amountWETH = uint256(balanceDelta.token1Delta);

        // Approve the SpokePool to take the WETH
        IERC20(wethAddress).safeApprove(address(spokePool), amountWETH);

        // Deposit WETH into Across SpokePool for bridging to Optimism
        spokePool.deposit(
            sender,
            wethAddress, // WETH as the token to bridge
            amountWETH,
            10, // destinationChainId for Optimism
            0, // relayerFeePct, to be determined
            block.timestamp, // quoteTimestamp
            data, // additional data if needed
            1 // maxCount, set according to Across Protocol requirements
        );

        return IHooks.afterSwap.selector;
    }
}