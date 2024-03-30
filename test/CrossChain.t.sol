// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Hooks} from "lib/v4-core/src/libraries/Hooks.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {CrossChainHook} from "src/CrossChainHook.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {V3SpokePoolInterface} from "lib/contracts-v2/contracts/interfaces/V3SpokePoolInterface.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract CrossChainHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    CrossChainHook public crossChainHook;
    string private ethFork = vm.envString("ETH_RPC");
    string private opFork = vm.envString("OP_RPC");

    address public ethSpokePool = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;


    uint256 private ethForkId;
    uint256 private opForkId;

    PoolKey private ethPoolKey;
    PoolId private ethPoolId;

    PoolKey private opPoolKey;
    PoolId private opPoolId;

    address public relayer;

    MockERC20 private token0;
    MockERC20 private token1;

    function setUp() public {
        // Ethereum
        ethForkId = vm.createFork(ethFork);
        vm.selectFork(ethForkId);
        deployFreshManagerAndRouters();
        (Currency ethCurrency0, Currency ethCurrency1) = deployMintAndApprove2Currencies();

        token0 = MockERC20(Currency.unwrap(ethCurrency0));
        token1 = MockERC20(Currency.unwrap(ethCurrency1));

        uint160 flag = uint160(Hooks.AFTER_SWAP_FLAG);
        (address ethHookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flag,
            type(CrossChainHook).creationCode,
            abi.encode(address(manager))
        );

        crossChainHook = new CrossChainHook{salt: salt}(
            IPoolManager(address(manager)),
            V3SpokePoolInterface(address(0)),
            address(0)
        );
        require(address(crossChainHook) == ethHookAddress, "CrossChainHookTest: hook address mismatch");

        (ethPoolKey, ethPoolId) = initPool(
            ethCurrency0,
            ethCurrency1,
            IHooks(address(crossChainHook)),
            3000,
            SQRT_RATIO_1_1,
            ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(ethPoolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether), ZERO_BYTES);

        // Optimism
        opForkId = vm.createFork(opFork);
        vm.selectFork(opForkId);
        // relayer = vm.addr(1);
        // vm.deal(relayer, 10 ether);
        deployFreshManagerAndRouters();
        (Currency opCurrency0, Currency opCurrency1) = deployMintAndApprove2Currencies();
        MockERC20 opToken0 = MockERC20(Currency.unwrap(opCurrency0));
        MockERC20 opToken1 = MockERC20(Currency.unwrap(opCurrency1));

        (opPoolKey, opPoolId) = initPool(
            opCurrency0,
            opCurrency1,
            IHooks(address(0)),
            3000,
            SQRT_RATIO_1_2,
            ZERO_BYTES
        );

        modifyLiquidityRouter.modifyLiquidity(opPoolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether), ZERO_BYTES);
    }

    function testSwapAndBridge() public {
        int256 swapAmount = 1 ether;

        vm.selectFork(ethForkId);
        vm.expectEmit(ethSpokePool);
        emit V3FundsDeposited(
            address(token0),
            address(token1),
            uint256(swapAmount),
            uint256(swapAmount),
            uint256(opForkId),
            uint32(0),
            uint32(block.timestamp),
            uint32(block.timestamp + 1 hours),
            uint32(block.timestamp + 15 minutes),
            address(this),
            address(this),
            address(0),
            ""
        );
        swap(ethPoolKey, true, swapAmount, "");

        vm.selectFork(opForkId);
        assertEq(address(this).balance, swapAmount);
    }
}