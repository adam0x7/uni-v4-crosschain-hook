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
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

contract CrossChainHookTest is Test, Deployers { 
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    CrossChainHook crossChainHook;
    string eth_fork = vm.envString("ETH_RPC"); 
    string poly_fork = vm.envString("POLY_RPC");
    uint256 ethFork = vm.createFork(eth_fork);
    uint256 polyFork = vm.createFork(poly_fork);


    function setUp() public { 
        //deploy uniswap pool w/ hook
        //deploy spoke pools on respective chains
        vm.selectFork(ethFork);
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();
        uint160 flag = uint160(Hooks.AFTER_SWAP_FLAG); // flag is used for hook bytecode
        (address hookAddress, bytes32 salt) = HookMiner.find(address(this), flag, type(CrossChainHook).creationCode , abi.encode(address(manager)));

        

        crossChainHook = new CrossChainHook{salt: salt}(IPoolManager(address(manager)), SpokePoolInterface(address(0)), address(0));
        require(address(crossChainHook) == hookAddress, "CrossChainHookTest: hook address mismatch");

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(crossChainHook)));
        PoolId poolId = key.toId();
        initializeRouter.initialize(key, SQRT_RATIO_1_1, ZERO_BYTES);

        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-120, 120, 10 ether), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether),
            ZERO_BYTES
        );




        vm.selectFork(polyFork);
    }

    function testForkIdDifferent() public { 
        bool isDifferent = ethFork != polyFork;
        assertEq(isDifferent, true);
    }
}