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
    }
    mapping(address => Insuree) public insurees;

    mapping(address => Package) public userPackage;
    mapping(address => uint256) public lastPaidAt;
    mapping(address => uint256) public yearlyClaims;
    mapping(address => uint256) public yearlyResetTimestamp;

    mapping(address => uint256) public contributions;

    event FundsAdded(address indexed user, uint256 amount, Package packageType);
    event ClaimSubmitted(address indexed user, uint256 claimId, uint256 amount);
    event ClaimExecuted(uint256 indexed claimId, address to, uint256 amount);

    struct Claim {
        address claimant;
        uint256 amount;
        string description;
        bool executed;
    }

    mapping(uint256 => Claim) public claims;
    uint256 public claimCounter;

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

        if (lastPaidAt[msg.sender] != 0 && block.timestamp < lastPaidAt[msg.sender] + 30 days) {
            revert HealthInsuranceDAO__AlreadyPaidThisMonth();
        }

        uint256 fee = (msg.value * 5) / 100;
        uint256 remaining = msg.value - fee;

        (bool success,) = payable(devVault).call{value: fee}("");
        if (!success) revert HealthInsuranceDAO__TxFail();

        contributions[msg.sender] += remaining;
        lastPaidAt[msg.sender] = block.timestamp;
        userPackage[msg.sender] = selectedPackage;
        
        if (insurees[msg.sender].firstPaymentTimestamp == 0) {
        insurees[msg.sender] = Insuree({
            user: msg.sender,
            packageType: selectedPackage,
             firstPaymentTimestamp: block.timestamp,
             isActive: true,
             remainingCoverage: getMaxClaimable(msg.sender)
        });
        } else {
        insurees[msg.sender].packageType = selectedPackage;
        insurees[msg.sender].isActive = true;
        }


        emit FundsAdded(msg.sender, remaining, selectedPackage);

        uint256 amountToMint = 10 ether;
        insuranceToken.mint(msg.sender, amountToMint);
        insuranceToken.delegate(msg.sender); //delegate votes to self for governance
    }

    function submitClaim(uint256 amount, string calldata description) external returns (uint256 claimId) {
        if (userPackage[msg.sender] == Package.None) revert HealthInsuranceDAO__NotSubscribed();

        if (block.timestamp > yearlyResetTimestamp[msg.sender] + 365 days) {
            yearlyClaims[msg.sender] = 0;
            yearlyResetTimestamp[msg.sender] = block.timestamp;
            insurees[msg.sender].remainingCoverage = getMaxClaimable(msg.sender);
        }

        uint256 maxClaimable = getMaxClaimable(msg.sender);

        if (yearlyClaims[msg.sender] + amount > maxClaimable) {
            revert HealthInsuranceDAO__ClaimLimitExceeded();
        }

        yearlyClaims[msg.sender] += amount;
        insurees[msg.sender].remainingCoverage -= amount;


        claimId = claimCounter++;
        claims[claimId] = Claim({claimant: msg.sender, amount: amount, description: description, executed: false});
        emit ClaimSubmitted(msg.sender, claimId, amount);
    }

    function getMaxClaimable(address user) public view returns (uint256) {
        if (userPackage[user] == Package.Basic) return 0.01 ether * 12 * 5;
        if (userPackage[user] == Package.Standard) return 0.03 ether * 12 * 5;
        if (userPackage[user] == Package.Premium) return 0.05 ether * 12 * 5;
        return 0;
    }

    function executeClaim(uint256 claimId) external onlyOwner {
        Claim storage c = claims[claimId];
        if (c.executed) {
            revert HealthInsuranceDAO__AlreadyExecuted();
        }

        c.executed = true;
        emit ClaimExecuted(claimId, c.claimant, c.amount);

        (bool success,) = payable(c.claimant).call{value: c.amount}("");
        if (!success) revert HealthInsuranceDAO__TxFail();
    }

    receive() external payable {
        revert("Use addFunds");
    }

    function getInsureeInfo(address user) external view returns (
         address insureeAddress,
         Package packageType,
         uint256 firstPaymentTimestamp,
         bool isActive,
         uint256 remainingCoverage
     ) {
         Insuree memory i = insurees[user];
        return (
         i.user,
         i.packageType,
         i.firstPaymentTimestamp,
         i.isActive,
         i.remainingCoverage
      );
    }

}
