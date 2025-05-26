//SPDX-License-Identifier:MIT

pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DevVault is Ownable {
    error DevVault__NotTheOwner();
    error DevVault__AmountCantBeZero();
    error DevVault__NotEnoughFunds();
    error DevVault__TxFail();

    constructor() Ownable(msg.sender) {}
    receive() external payable {}

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        if (msg.sender != owner()) {
            revert DevVault__NotTheOwner();
        }
        if (amount == 0) {
            revert DevVault__AmountCantBeZero();
        }

        if (address(this).balance < amount) {
            revert DevVault__NotEnoughFunds();
        }
        (bool success,) = to.call{value: amount}("");
        if (!success) revert DevVault__TxFail();
    }
}
