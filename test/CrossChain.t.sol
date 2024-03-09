// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";

/* 




*/


contract CrossChainHookTest is Test, Deployers{ 

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
        uint160 flag = 




        vm.selectFork(polyFork);
    }

    function testForkIdDifferent() public { 
        bool isDifferent = ethFork != polyFork;
        assertEq(isDifferent, true);
    }
}