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
import {V3SpokePoolInterface} from "lib/contracts-v2/contracts/interfaces/V3SpokePoolInterface.sol";

contract CrossChainHookTest is Test, Deployers { 
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    CrossChainHook crossChainHook;
    string eth_fork = vm.envString("ETH_RPC"); 

    address eth_spoke_pool = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;

    string op_fork = vm.envString("OP_RPC");
    uint256 ethFork = vm.createFork(eth_fork);
    uint256 opFork = vm.createFork(op_fork);


    function setUp() public { 
        //deploy uniswap pool w/ hook
        //deploy spoke pools on respective chains
        vm.selectFork(ethFork);
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();
        
        uint160 flag = uint160(Hooks.AFTER_SWAP_FLAG); // flag is used for hook bytecode

        (address hookAddress, bytes32 salt) = HookMiner.find(address(this), flag, type(CrossChainHook).creationCode , abi.encode(address(manager)));

        crossChainHook = new CrossChainHook{salt: salt}(IPoolManager(address(manager)), V3SpokePoolInterface(address(0)), address(0));
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
    }

    function testForkIdDifferent() public { 
        bool isDifferent = ethFork != opFork;
        assertEq(isDifferent, true);
    }

    function testSwapAndBridge() public {
    // Step 1: Setup and Initialization
    Deployers deployers = new Deployers();
    deployers.initializeManagerRoutersAndPoolsWithLiq(IHooks(address(crossChainHook)));
    (Currency currency0, Currency currency1) = deployers.deployMintAndApprove2Currencies();

    // Assuming `currency0` is the token you're swapping from, and `currency1` is what you're swapping to
    address user = address(this); // Test account
    uint256 amountToken0 = 1e18; // Example amount to swap

    // Step 2: Perform a Swap
    // This swap should trigger the CrossChainHook's afterSwap function
    deployers.swap(deployers.key, true, int256(amountToken0), abi.encode(address(currency1)));

    // Step 3: Verify L1 Deposit Event
    // Use Foundry's expectEmit to check for the V3FundsDeposited event
    // This step assumes you have a way to listen for or simulate the event emission in your test environment

    // Step 4: Simulate or Verify L2 Deposit
    // Depending on your testing capabilities, simulate the L2 deposit or verify it if your setup allows observation of L2 state/events
}
}