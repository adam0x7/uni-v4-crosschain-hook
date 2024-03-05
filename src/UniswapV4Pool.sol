// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolInitializeTest} from "v4-core/test/PoolInitializeTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV4Pool {
    PoolInitializeTest public initializeRouter;
    PoolModifyLiquidityTest public lpRouter;
    PoolSwapTest public swapRouter;

    constructor(
        address _initializeRouter,
        address _lpRouter,
        address _swapRouter
    ) {
        initializeRouter = PoolInitializeTest(_initializeRouter);
        lpRouter = PoolModifyLiquidityTest(_lpRouter);
        swapRouter = PoolSwapTest(_swapRouter);
    }

    function initializePool(
        address token0,
        address token1,
        uint24 swapFee,
        int24 tickSpacing,
        address hook,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) external {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hook)
        });

        initializeRouter.initialize(poolKey, sqrtPriceX96, hookData);
    }

    function addLiquidity(
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        int256 liquidity,
        bytes calldata hookData
    ) external {
        lpRouter.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams({tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: liquidity}),
            hookData
        );
    }

    function swap(
        PoolKey memory key,
        int256 amountSpecified,
        bool zeroForOne,
        bytes memory hookData
    ) internal {
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1
        });

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            withdrawTokens: true,
            settleUsingTransfer: true,
            currencyAlreadySent: false
        });

        swapRouter.swap(key, params, testSettings, hookData);
    }
}