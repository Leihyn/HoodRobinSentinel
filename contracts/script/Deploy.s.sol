// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {MandateManager} from "../src/MandateManager.sol";

/// @notice Deploys the registry and the settlement contract to Robinhood Chain.
///
///         The two point at each other and both hold the reference immutably: the
///         registry will only accept writes from the manager, and the manager only
///         knows one registry. Neither can be deployed after the other without a
///         setter, and a setter is exactly what a reputation registry should not
///         have, because whoever holds it can rewrite history.
///
///         So the manager's address is computed before it exists, from the
///         deployer's next nonce, and the registry is constructed against that.
///         The script asserts the prediction held before it reports success.
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        console.log("deployer :", deployer);
        console.log("chainid  :", block.chainid);
        console.log("balance  :", deployer.balance);

        vm.startBroadcast(pk);

        // The registry is created at the current nonce, the manager at the next.
        address predictedManager = vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 1);

        AgentRegistry registry = new AgentRegistry(predictedManager);
        MandateManager manager = new MandateManager(address(registry));

        vm.stopBroadcast();

        require(address(manager) == predictedManager, "nonce prediction failed; nothing is wired");
        require(registry.settlement() == address(manager), "registry points elsewhere");
        require(address(manager.registry()) == address(registry), "manager points elsewhere");

        console.log("AgentRegistry :", address(registry));
        console.log("MandateManager:", address(manager));
    }
}
