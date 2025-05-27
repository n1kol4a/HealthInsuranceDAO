// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/InsuranceToken.sol";
import "../src/DevVault.sol";
import "../src/HealthInsuranceDAO.sol";
import "../src/InsuranceGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DevFeeTest is Test {
    HealthInsuranceDAO public dao;
    DevVault public devVault;
    InsuranceToken public token;
    MyGovernor public governor;

    address public deployer;
    address public user = makeAddr("user");

    function setUp() public {
        deployer = address(this);
        vm.deal(user, 10 ether);

        token = new InsuranceToken(deployer);
        devVault = new DevVault();
        governor = new MyGovernor(IVotes(address(token)));
        dao = new HealthInsuranceDAO(deployer, address(governor), address(token), devVault);

        token.transferOwnership(address(dao));
    }

    function testDevVaultReceives5PercentFee() public {
        vm.startPrank(user);
        uint256 amountSent = 0.01 ether;

        // Expect devVault to have 5% after addFunds()
        uint256 expectedFee = (amountSent * 5) / 100;
        uint256 expectedRemaining = amountSent - expectedFee;

        dao.addFunds{value: amountSent}();

        assertEq(address(devVault).balance, expectedFee, "DevVault did not receive correct fee");
        assertEq(dao.contributions(user), expectedRemaining, "User contribution incorrect");
        vm.stopPrank();
    }

    function testWithdrawFailsIfNotEnoughBalance() public {
        uint256 withdrawAmount = 1 ether;

        vm.expectRevert(DevVault.DevVault__NotEnoughFunds.selector);
        devVault.withdraw(payable(user), withdrawAmount);
    }
}
