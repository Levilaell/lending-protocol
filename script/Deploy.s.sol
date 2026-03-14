// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LendingProtocol} from "../src/LendingProtocol.sol";
import {MockOracle} from "../src/MockOracle.sol";

contract DeployLending is Script {
    address constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MockOracle oracle = new MockOracle();
        oracle.setPrice(2000e18);
        new LendingProtocol(WETH, USDC, address(oracle));
        vm.stopBroadcast();
    }
}
