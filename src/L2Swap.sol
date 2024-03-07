// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {BaseHook} from "lib/v4-periphery/contracts/BaseHook.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "lib/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "lib/v4-core/src/types/BalanceDelta.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HookEnabledSwapRouter} from "lib/v4-periphery/test/utils/HookEnabledSwapRouter.sol"; 
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Currency} from "lib/v4-core/src/types/Currency.sol";
import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";

contract L2Hook is BaseHook {
    HookEnabledSwapRouter public uniswapRouter;
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    constructor(IPoolManager _poolManager, HookEnabledSwapRouter _uniswapRouter)
        BaseHook(_poolManager) {
        uniswapRouter = _uniswapRouter;
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
        
        address desiredToken = abi.decode(data, (address));

        // Ensure that the token to swap (token1) is approved for the Uniswap Router
        IERC20 tokenToSwap = IERC20(Currency.unwrap(poolKey.currency1));
        tokenToSwap.approve(address(uniswapRouter), uint256(swapParams.amountSpecified));

        HookEnabledSwapRouter.TestSettings memory testSettings = HookEnabledSwapRouter.TestSettings(false, false);
        // Perform the swap on Uniswap
        uniswapRouter.swap(
            poolKey,
            swapParams,
            testSettings,
            data
        );

        // Reset approval to zero to follow the check-effects-interactions pattern
        tokenToSwap.approve(address(uniswapRouter), 0);

        return L2Hook.afterSwap.selector;
    }
}