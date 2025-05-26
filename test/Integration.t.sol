//SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/InsuranceToken.sol";
import "../src/DevVault.sol";
import "../src/HealthInsuranceDAO.sol";
import "../src/InsuranceGovernor.sol";
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";

contract FixedClaimFlowTest is Test {
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

    function testTokenOwnership() public {
        assertEq(token.owner(), address(dao), "DAO should be token owner");
    }
    //in order for this test to work in InsuranceGovernor.sol quorum function should be set to:
    //   function quorum(uint256 /* blockNumber */ ) public pure override returns (uint256) {
    //    return 10 * 10 ** 18; // 100 tokens as quorum
    //}

    function testFullClaimFlow() public {
        // User subscribes and gets tokens + delegates
        vm.prank(user);
        dao.addFunds{value: 0.03 ether}(); // STANDARD package

        // Move forward to register snapshot
        vm.roll(block.number + 1);
        vm.prank(user);
        token.delegate(user);
        vm.roll(block.number + 1);

        // User submits a claim
        vm.prank(user);
        uint256 claimId = dao.submitClaim(0.01 ether, "Hospital treatment");

        // Prepare proposal calldata
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(dao);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("executeClaim(uint256)", claimId);

        // Propose
        vm.prank(user);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Approve claim for user");

        // Go to voting start
        vm.roll(block.number + governor.votingDelay() + 1);

        // Vote
        vm.prank(user);
        governor.castVote(proposalId, 1);

        // Go past voting period
        vm.roll(block.number + governor.votingPeriod() + 1);
        vm.warp(block.timestamp + 7 days); // advance timestamp just in case

        // Check proposal state
        uint256 state = uint256(governor.state(proposalId));
        emit log_named_uint("Proposal state", state);
        emit log_named_uint("User votes", governor.getVotes(user, block.number - 1));
        emit log_named_uint("Quorum", governor.quorum(block.number - 1));

        // Now execute
        vm.prank(user);
        governor.execute(targets, values, calldatas, keccak256(bytes("Approve claim for user")));

        // Check executed
        (address claimant,, string memory desc, bool executed) = dao.claims(claimId);
        assertTrue(executed);
        assertEq(claimant, user);
        assertEq(desc, "Hospital treatment");
    }

    function testCantWithdrawMoreThanDaoBalance() public {
        // User subscribes and gets tokens + delegates
        vm.prank(user);
        dao.addFunds{value: 0.03 ether}(); // STANDARD package

        // Move forward to register snapshot
        vm.roll(block.number + 1);
        vm.prank(user);
        token.delegate(user);
        vm.roll(block.number + 1);

        // User submits a claim
        vm.prank(user);
        uint256 claimId = dao.submitClaim(0.1 ether, "Hospital treatment");

        // Prepare proposal calldata
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(dao);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("executeClaim(uint256)", claimId);

        // Propose
        vm.prank(user);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Approve claim for user");

        // Go to voting start
        vm.roll(block.number + governor.votingDelay() + 1);

        // Vote
        vm.prank(user);
        governor.castVote(proposalId, 1);

        // Go past voting period
        vm.roll(block.number + governor.votingPeriod() + 1);
        vm.warp(block.timestamp + 7 days); // advance timestamp just in case

        // Check proposal state
        uint256 state = uint256(governor.state(proposalId));
        emit log_named_uint("Proposal state", state);
        emit log_named_uint("User votes", governor.getVotes(user, block.number - 1));
        emit log_named_uint("Quorum", governor.quorum(block.number - 1));

        // Now execute
        vm.prank(user);
        vm.expectRevert(HealthInsuranceDAO.HealthInsuranceDAO__TxFail.selector);
        governor.execute(targets, values, calldatas, keccak256(bytes("Approve claim for user")));
    }

    function testClaimantReceivesEthAfterExecute() public {
        // User subscribes
        vm.prank(user);
        dao.addFunds{value: 0.05 ether}(); // PREMIUM package

        // Snapshot and delegate
        vm.roll(block.number + 1);
        vm.prank(user);
        token.delegate(user);
        vm.roll(block.number + 1);

        // Submit claim
        uint256 claimAmount = 0.01 ether;
        vm.prank(user);
        uint256 claimId = dao.submitClaim(claimAmount, "Emergency surgery");

        // Prepare proposal calldata
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(dao);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("executeClaim(uint256)", claimId);

        // Propose
        vm.prank(user);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Approve claim");

        // Voting
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(user);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        vm.warp(block.timestamp + 1 days); // Ensure execution time is valid

        // Get user balance before execution
        uint256 balanceBefore = user.balance;

        // Execute
        vm.prank(user);
        governor.execute(targets, values, calldatas, keccak256(bytes("Approve claim")));

        // Get user balance after execution
        uint256 balanceAfter = user.balance;

        // Assert user received the correct amount
        assertEq(balanceAfter - balanceBefore, claimAmount, "User did not receive correct claim amount");

        // Extra assert for internal state
        (,,, bool executed) = dao.claims(claimId);
        assertTrue(executed, "Claim should be marked as executed");
    }
}
