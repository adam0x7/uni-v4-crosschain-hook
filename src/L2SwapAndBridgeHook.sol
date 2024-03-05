// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "path/to/UniswapV4RouterInterface.sol"; // Define or import Uniswap V4 Router Interface

contract L2SwapHook is BaseHook {
    UniswapV4RouterInterface public uniswapRouter;

    constructor(IPoolManager _poolManager, UniswapV4RouterInterface _uniswapRouter)
        BaseHook(_poolManager) {
        uniswapRouter = _uniswapRouter;
    }

    function afterSwap(
        address sender,
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta calldata balanceDelta,
        bytes calldata data
    ) external override poolManagerOnly returns (bytes4) {
        // Perform swap to desired token on L2 using Uniswap V4 Router
        address desiredToken = abi.decode(data, (address));
        IERC20(poolKey.token1).approve(address(uniswapRouter), swapParams.amountSpecified);
        uniswapRouter.swapExactTokensForTokens(
            swapParams.amountSpecified,
            0, // amountOutMin, to be determined
            [poolKey.token1, desiredToken], // path
            sender,
            block.timestamp + 15 minutes // deadline
        );
        return IHooks.afterSwap.selector;
    }
}