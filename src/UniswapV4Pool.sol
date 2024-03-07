// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {PoolInitializeTest} from "lib/v4-core/src/test/PoolInitializeTest.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "lib/v4-core/src/types/Currency.sol";

contract V4Pool {
    using CurrencyLibrary for Currency;

    PoolInitializeTest initializeRouter = PoolInitializeTest(address(0x02));

    function init(
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

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hook)
        });
        initializeRouter.initialize(pool, sqrtPriceX96, hookData);
    }
}
