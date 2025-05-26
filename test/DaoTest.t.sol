//SPDX-License-Identifier:MIT

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {InsuranceToken} from "../src/InsuranceToken.sol";
import {DevVault} from "../src/DevVault.sol";
import {HealthInsuranceDAO} from "../src/HealthInsuranceDAO.sol";
import {MyGovernor} from "../src/InsuranceGovernor.sol";

contract DaoTest is Test {
    InsuranceToken token;
    DevVault vault;
    HealthInsuranceDAO dao;
    MyGovernor governor;
    address user = makeAddr("user");

    function setUp() public {
        token = new InsuranceToken(user);
        vault = new DevVault();
        governor = new MyGovernor(token);
        dao = new HealthInsuranceDAO(address(governor), msg.sender, address(token), vault);

        token.delegate(user);
        vm.prank(user);
        token.transferOwnership(address(dao));
        vm.deal(user, 1 ether);
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
