// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

/// @title Canonical Fortunna Yield Farming pools lib
/// @author Fortunna Team
/// @notice A lib holding default errors, helpers functions and constants.
library FortunnaLib {

    struct CustomPoolParameters {
        address nonfungiblePositionManager;
    }

    /// @dev A struct to hold pools scalar deploy parameters.
    struct PoolParameters {
        // An index of pool prototype in the factory list of prototypes.
        uint256 protoPoolIdx;
        // Start of the pool reward distribution period.
        uint256 startTimestamp;
        // End of the pool reward distribution period.
        uint256 endTimestamp;
        // Minimal amount for user to be able to deposit to the pool.
        uint256 minStakeAmount;
        // Maximal amount for user to be able to deposit to the pool.
        uint256 maxStakeAmount;
        // A time duration in seconds for a user to wait until they could receiver their rewards.
        uint256 minLockUpRewardsPeriod;
        // A fee amount in base points to be charged from user if they would attempt to receiver their rewards.
        uint256 earlyWithdrawalFeeBasePoints;
        // A fee amount in base points to be charged from user if they would attempt to perform deposit/withdraw.
        uint256 depositWithdrawFeeBasePoints;
        // A percent from total reward provided being distributed to stakers.
        uint256 totalRewardBasePointsPerDistribution;
        // A bit mask to indicate whether the token in `utilizingTokens` is staking token.
        bytes32 stakingTokensMask;
        // A bit mask to indicate whether the token in `utilizingTokens` is reward token.
        bytes32 rewardTokensMask;
        CustomPoolParameters custom;
    }

    /// @dev A struct to hold pools vector deploy parameters.
    struct PoolParametersArrays {
        // An array of tokens to be used as either reward or staking tokens.
        address[] utilizingTokens;
        // Array of pairs <index of reward token, initial total reward amount>
        uint256[2][] initialRewardAmounts;
        // An array of pairs <index of staking token, deposit amount>
        uint256[2][] initialDepositAmounts;
    }

    /// @dev A struct to hold a pay info for pool deployment.
    struct PaymentInfo {
        // A token address to be accepted as payment.
        address paymentToken;
        // A payment amount for pool deploy.
        uint256 cost;
    }

    /// @notice A role hash to mark addresses to be held as reward tokens.
    bytes32 public constant ALLOWED_REWARD_TOKEN_ROLE =
        keccak256("ALLOWED_REWARD_TOKEN_ROLE");

    /// @notice A role hash to mark addresses to be held as staking tokens.
    bytes32 public constant ALLOWED_STAKING_TOKEN_ROLE =
        keccak256("ALLOWED_STAKING_TOKEN_ROLE");

    /// @notice A role hash to mark addresses to be held as external reward tokens from another protocols.
    bytes32 public constant ALLOWED_EXTERNAL_TOKEN_ROLE =
        keccak256("ALLOWED_EXTERNAL_TOKEN_ROLE");

    /// @notice A role hash to mark addresses to be held as banned users.
    bytes32 public constant BANNED_ROLE = keccak256("BANNED_ROLE");

    /// @notice A role hash to mark addresses to be held as payment for pool deploy tokens.
    bytes32 public constant ALLOWED_PAYMENT_TOKEN_ROLE =
        keccak256("ALLOWED_PAYMENT_TOKEN_ROLE");

    /// @notice A role hash to indicate who can mint and burn the `FortunnaToken`'s.
    bytes32 public constant LP_MINTER_BURNER_ROLE =
        keccak256("LP_MINTER_BURNER_ROLE");

    /// @notice A role hash to indicate who can mint and burn the `FortunnaToken`'s.
    bytes32 public constant POOL_REWARDS_PROVIDER =
        keccak256("POOL_REWARDS_PROVIDER");

    /// @notice A max of base points. (ex. Like 100 in percents)
    uint256 public constant BASE_POINTS_MAX = 10000;

    /// @notice A given precision for math operations;
    uint256 public constant PRECISION = 1e10;

    /// @notice A dead address for floor tokens to be minted
    address public constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;
}
