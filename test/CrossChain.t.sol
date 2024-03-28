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

    PoolKey eth_poolKey;
    PoolId eth_poolId;

    PoolKey op_poolKey;
    PoolId op_poolId;

    address public relayer;



function setUp() public {
    // Ethereum 
    vm.selectFork(ethFork);
    deployFreshManagerAndRouters();
    (Currency eth_currency0, Currency eth_currency1) = deployMintAndApprove2Currencies();

    token0 = MockERC20(Currency.unwrap(eth_currency0));
    token1 = MockERC20(Currency.unwrap(eth_currency1));

    uint160 flag = uint160(Hooks.AFTER_SWAP_FLAG); // flag is used for hook bytecode

    (address eth_hookAddress, bytes32 salt) = HookMiner.find(address(this), flag, type(CrossChainHook).creationCode, abi.encode(address(manager)));

    crossChainHook = new CrossChainHook{salt: salt}(IPoolManager(address(manager)), V3SpokePoolInterface(address(0)), address(0));
    require(address(crossChainHook) == eth_hookAddress, "CrossChainHookTest: hook address mismatch");

    (eth_poolKey, eth_poolId) = initPool(eth_currency0,
                                                         eth_currency1, 
                                                         IHooks(address(crossChainHook)), 
                                                         3000, 60, SQRT_RATIO_1_1, ZERO_BYTES);

    modifyLiquidityRouter.modifyLiquidity(eth_poolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether), ZERO_BYTES);

    // Optimism 
    vm.selectFork(opFork);
    relayer = vm.addr(1); 
    vm.deal(relayer, 10 ether);
    deployFreshManagerAndRouters();
    (Currency op_currency0, Currency op_currency1) = deployMintAndApprove2Currencies();
    MockERC20 op_token0 = MockERC20(Currency.unwrap(op_currency0));
    MockERC20 op_token1 = MockERC20(Currency.unwrap(op_currency1));

    (op_poolKey, op_poolId) = initPool(op_currency0,
                                                      op_currency1,
                                                      IHooks(address(0)), // No hook for L2 in
                                                      3000,
                                                      SQRT_RATIO_1_2,
                                                      ZERO_BYTES);

    modifyLiquidityRouter.modifyLiquidity(op_poolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether), ZERO_BYTES);
}

    function testSwapAndBridge() public {
        uint256 swapAmount = 1 ether;

        vm.selectFork(ethFork);
        vm.expectEmit(eth_spoke_pool);
        emit V3SpokePoolInterface.V3FundsDeposited();
        swap(eth_poolKey, true, swapAmount, "");

        vm.selectFork(opFork);
        vm.startPrank(relayer);
        payable(address(this)).transfer(swapAmount);
        vm.stopPrank();

        assertEq(address(this).balance, swapAmount);

    }
}