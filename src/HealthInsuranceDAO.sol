// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {InsuranceToken} from "./InsuranceToken.sol";
import {DevVault} from "./DevVault.sol";

contract HealthInsuranceDAO is Ownable, ReentrancyGuard {
    error HealthInsuranceDAO__TxFail();
    error HealthInsuranceDAO__MustSendEth();
    error HealthInsuranceDAO__InvalidPackageAmount();
    error HealthInsuranceDAO__AlreadyPaidThisMonth();
    error HealthInsuranceDAO__NotSubscribed();
    error HealthInsuranceDAO__ClaimLimitExceeded();
    error HealthInsuranceDAO__AlreadyExecuted();

    InsuranceToken public insuranceToken;
    DevVault public devVault;
    address public governor;

    enum Package {
        None,
        Basic,
        Standard,
        Premium
    }

    struct Insuree {
        address user;
        Package packageType;
        uint256 firstPaymentTimestamp;
        bool isActive;
        uint256 remainingCoverage;
        uint256 lastPaidAt;
        uint256 yearlyClaims;
        uint256 yearlyResetTimestamp;
    }

    struct Claim {
        address claimant;
        uint256 amount;
        string description;
        bool executed;
    }

    mapping(address => Insuree) public insurees;
    mapping(address => uint256) public contributions;
    mapping(uint256 => Claim) public claims;
    uint256 public claimCounter;

    event FundsAdded(address indexed user, uint256 amount, Package packageType);
    event ClaimSubmitted(address indexed user, uint256 claimId, uint256 amount);
    event ClaimExecuted(uint256 indexed claimId, address to, uint256 amount);

    constructor(address _initialOwner, address _governor, address _token, DevVault _devVault) Ownable(_initialOwner) {
        insuranceToken = InsuranceToken(_token);
        governor = _governor;
        devVault = _devVault;
    }

    function addFunds() external payable nonReentrant {
    if (msg.value == 0) revert HealthInsuranceDAO__MustSendEth();

    Package selectedPackage;
    if (msg.value == 0.01 ether) selectedPackage = Package.Basic;
    else if (msg.value == 0.03 ether) selectedPackage = Package.Standard;
    else if (msg.value == 0.05 ether) selectedPackage = Package.Premium;
    else revert HealthInsuranceDAO__InvalidPackageAmount();

    Insuree storage insuree = insurees[msg.sender];
    if (insuree.lastPaidAt != 0 && block.timestamp < insuree.lastPaidAt + 30 days) {
        revert HealthInsuranceDAO__AlreadyPaidThisMonth();
    }

    uint256 fee = (msg.value * 5) / 100;
    uint256 remaining = msg.value - fee;

    (bool success,) = payable(devVault).call{value: fee}("");
    if (!success) revert HealthInsuranceDAO__TxFail();

    contributions[msg.sender] += remaining;
    insuree.lastPaidAt = block.timestamp;
    insuree.packageType = selectedPackage;
    insuree.isActive = true;

    if (insuree.firstPaymentTimestamp == 0) {
        insuree.user = msg.sender;
        insuree.firstPaymentTimestamp = block.timestamp;
        insuree.remainingCoverage = getMaxClaimable(msg.sender);

        // Mint tokens only on first payment
        uint256 amountToMint = 10 * 10 ** 18;
        insuranceToken.mint(msg.sender, amountToMint);
    }
    emit FundsAdded(msg.sender, remaining, selectedPackage);
}


    function submitClaim(uint256 amount, string calldata description) external returns (uint256 claimId) {
        Insuree storage insuree = insurees[msg.sender];
        if (insuree.packageType == Package.None) revert HealthInsuranceDAO__NotSubscribed();

        if (block.timestamp > insuree.yearlyResetTimestamp + 365 days) {
            insuree.yearlyClaims = 0;
            insuree.yearlyResetTimestamp = block.timestamp;
            insuree.remainingCoverage = getMaxClaimable(msg.sender);
        }

        uint256 maxClaimable = getMaxClaimable(msg.sender);
        if (insuree.yearlyClaims + amount > maxClaimable) {
            revert HealthInsuranceDAO__ClaimLimitExceeded();
        }

        insuree.yearlyClaims += amount;
        insuree.remainingCoverage -= amount;

        claimId = claimCounter++;
        claims[claimId] = Claim({claimant: msg.sender, amount: amount, description: description, executed: false});

        emit ClaimSubmitted(msg.sender, claimId, amount);
    }

    function getMaxClaimable(address user) public view returns (uint256) {
        Package pkg = insurees[user].packageType;
        if (pkg == Package.Basic) return 0.01 ether * 12 * 5;
        if (pkg == Package.Standard) return 0.03 ether * 12 * 5;
        if (pkg == Package.Premium) return 0.05 ether * 12 * 5;
        return 0;
    }

    function executeClaim(uint256 claimId) external {
        Claim storage c = claims[claimId];
        if (c.executed) revert HealthInsuranceDAO__AlreadyExecuted();

        c.executed = true;
        emit ClaimExecuted(claimId, c.claimant, c.amount);

        (bool success,) = payable(c.claimant).call{value: c.amount}("");
        if (!success) revert HealthInsuranceDAO__TxFail();
    }

    receive() external payable {
        revert("Use addFunds");
    }
}
