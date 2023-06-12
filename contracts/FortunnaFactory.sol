// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import "./FortunnaLib.sol";

contract FortunnaFactory is AccessControl {
    using FortunnaLib for bytes32;
    using Clones for address;

    struct PoolInformation {
        uint256 chainId;
        string poolPrototypeName;
        address[] tokens;
    }

    struct PoolParameters {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 minLockUpRewardsPeriod;
        uint256 earlyWithdrawalFeeBasePoints;
        uint256 depositWitdrawFeeBasePoints;
        uint256[] stakingTokensIndicies;
    }

    struct RewardInfo {
        // Bit mask, where if the Nth bit is up then 
        // in Nth reward info first element is an address - otherwise: index
        bytes32 mask; 
        
        uint256[] rewardTokensIndicies;
        address[] externalRewardTokens;

        // initial total rewards amounts per index or address; 
        // array of pairs <index or address, initial reward amount>
        bytes32[2][] initialRewardAmounts;

        // array of pairs <index of staking token, deposit amount>
        uint256[2][] initialDepositAmounts; 
    }

    struct PaymentInfo {
        address paymentToken;
        uint256 cost;
    }

    uint256 public constant BASE_POINTS_MAX = 10000;
    bytes32 public constant ALLOWED_REWARD_TOKEN_ROLE = keccak256("ALLOWED_TOKEN_ROLE");
    bytes32 public constant ALLOWED_STAKING_TOKEN_ROLE = keccak256("ALLOWED_TOKEN_ROLE");
    bytes32 public constant ALLOWED_EXTERNAL_TOKEN_ROLE = keccak256("ALLOWED_TOKEN_ROLE");

    mapping(bytes32 => address) public getPoolPrototype;

    function setPoolPrototype(
        string calldata poolPrototypeName,
        address poolPrototype
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        getPoolPrototype[keccak256(bytes(poolPrototypeName))] = poolPrototype;
    }

    function createPool(

    ) external payable returns (address) {

    }
}
