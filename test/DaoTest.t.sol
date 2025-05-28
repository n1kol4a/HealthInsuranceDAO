//SPDX-License-Identifier:MIT

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {InsuranceToken} from "../src/InsuranceToken.sol";
import {DevVault} from "../src/DevVault.sol";
import {HealthInsuranceDAO} from "../src/HealthInsuranceDAO.sol";
import {MyGovernor} from "../src/InsuranceGovernor.sol";
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DaoTest is Test {
    HealthInsuranceDAO public dao;
    DevVault public devVault;
    InsuranceToken public token;
    MyGovernor public governor;

    address public deployer;
    address public user = address(1);

    function setUp() public {
        deployer = address(this);
        vm.deal(user, 10 ether);

        token = new InsuranceToken(deployer);
        devVault = new DevVault();
        governor = new MyGovernor(IVotes(address(token)));
        dao = new HealthInsuranceDAO(deployer, address(governor), address(token), devVault);

        vm.prank(deployer);
        token.transferOwnership(address(dao));
    }

    function testAddFundsMintsTokens() public {
        vm.prank(user);
        dao.addFunds{value: 0.01 ether}();
        uint256 tokenBlanceOfUser = token.balanceOf(user);
        uint256 expectedTokenBalance = 10 ether;
        assertEq(tokenBlanceOfUser, expectedTokenBalance);
    }

    function testAddFundsSendsEthToVault() public {
        vm.prank(user);
        dao.addFunds{value: 0.01 ether}();
    }
}
