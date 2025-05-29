// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/InsuranceToken.sol";
import "../src/DevVault.sol";
import "../src/HealthInsuranceDAO.sol";
import "../src/InsuranceGovernor.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        console.log("Deploying from:", msg.sender);
        // 1. Deploy InsuranceToken
        InsuranceToken token = new InsuranceToken(deployer);
        console2.log("InsuranceToken deployed at:", address(token));
        require(token.owner() == deployer, "Token ownership mismatch");

        // 2. Deploy DevVault
        DevVault devVault = new DevVault();
        console2.log("DevVault deployed at:", address(devVault));

        // 3. Deploy MyGovernor
        MyGovernor governor = new MyGovernor(IVotes(address(token)));
        console2.log("MyGovernor deployed at:", address(governor));

        // 4. Deploy HealthInsuranceDAO
        HealthInsuranceDAO dao = new HealthInsuranceDAO(deployer, address(governor), address(token), devVault);
        console2.log("HealthInsuranceDAO deployed at:", address(dao));

        // 5. Transfer token ownership to DAO
        token.transferOwnership(address(dao));
        console2.log("Token ownership transferred to DAO.");
        require(token.owner() == address(dao), "DAO is not the owner of the token!");
        console2.log("Ownership confirmed: DAO is the owner of the token.");

        vm.stopBroadcast();
    }
}
