// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract MyGovernor is Governor, GovernorCountingSimple, GovernorVotes {
    constructor(IVotes _token) Governor("MyGovernor") GovernorVotes(_token) {}

    function votingDelay() public pure override returns (uint256) {
        return 1; // ~ 12 seconds
    }

    function votingPeriod() public pure override returns (uint256) {
        return 5; // ~ 1 minute
    }

    function quorum(uint256 /* blockNumber */ ) public pure override returns (uint256) {
        return 10 * 10 ** 18; // 10 tokens as quorum
    }
}
