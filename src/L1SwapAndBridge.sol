// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {BaseHook} from "lib/v4-periphery/contracts/BaseHook.sol";
import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "lib/v4-core/src/types/PoolId.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "lib/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "lib/v4-core/src/types/BalanceDelta.sol";
import {SpokePoolInterface} from "lib/contracts-v2/contracts/interfaces/SpokePoolInterface.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Currency} from "lib/v4-core/src/types/Currency.sol";

contract CrossChainHook is BaseHook {
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

        IERC20(wethAddress).approve(address(spokePool), amountWETH);

        spokePool.deposit(
            sender,
            wethAddress,
            amountWETH,
            10, // destinationChainId, just testing for optimism
            0, // relayerFeePct
            uint32(block.timestamp), 
            data,
            1 
        );

        return CrossChainHook.afterSwap.selector;
    }
}