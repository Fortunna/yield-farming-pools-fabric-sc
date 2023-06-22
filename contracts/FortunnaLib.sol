// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Canonical Fortunna Yield Farming pools lib
/// @author Fortunna Team
/// @notice A lib holding default errors, helpers functions and constants.
library FortunnaLib {
    /// @dev An error to be reverted if an `account` would be
    /// banned.
    /// @param account A banned user.
    error Banned(address account);

    /// @dev An error to be reverted if an unknown prototype name would be used to deploy
    /// a pool or other utility smart-contract.
    /// @param prototypeIndex An index of prototype smart-contract.
    error UnknownPrototypeIndex(uint256 prototypeIndex);

    /// @dev An error to be reverted if the pool deployer didn't payed enough for it.
    /// @param amount An actual amount the deployer sent.
    error NotEnoughtPayment(uint256 amount);

    /// @dev An error to be reverted if some data structures `length` is not defined correctly.
    /// @param length An actual length of the data structure.
    /// @param comment Some comment as to what kind of a data structure has been addressed to.
    error InvalidLength(uint256 length, string comment);

    /// @dev An error to be reverted if in some two addresses arrays the elements aren't unique.
    /// @param someAddress An address which is equal in both arrays.
    error NotUniqueAddresses(address someAddress);

    /// @dev An error to be reverted if the contract is being deployed at a wrong chain.
    /// @param chainId An actual chain ID.
    error ForeignChainId(uint256 chainId);

    /// @dev An error to be reverted if some Euclidean interval hasn't been defined correctly.
    /// @param start A start of the interval.
    /// @param finish An end of the interval.
    /// @param comment Some comment as to what kind of an interval this is.
    error IncorrectInterval(uint256 start, uint256 finish, string comment);

    /// @dev An error to be reverted if some base points were defined out of their boundaries.
    /// @param basePoints An actual base points amount.
    /// @param comment Some comment as to what kind of a base points this is.
    error IncorrectBasePoints(uint256 basePoints, string comment);

    /// @dev An error to be reverted if an `enity` is already exists in some address set.
    /// @param entity An entity address.
    error AddressAlreadyExists(address entity);

    /// @dev An error to be reverted if the contract was being called before the initialization.
    error NotInitialized();

    /// @dev An error to be reverted if an `entity` does not possess the `role`.
    /// @param role A role an entity doesn't posess.
    /// @param entity An entity violating authorization.
    error NotAuthorized(bytes32 role, address entity);

    /// @dev An error to be reverted if some scalar property of the data structure was addressed wrongly.
    /// @param scalar A scalar.
    /// @param comment Some comment as to what kind of a data structure property this is.
    error InvalidScalar(uint256 scalar, string comment);

    /// @dev An error to be reverted if some pair of scalars is not equal, but they should be.
    /// @param x A first scalar.
    /// @param y A second scalar.
    /// @param comment Some comment as to what kind of a data structure property this is.
    error AreNotEqual(uint256 x, uint256 y, string comment);

    error NotEnoughStaked(uint256 amount, uint256 limit);

    error TooMuchStaked(uint256 amount, uint256 limit);

    error DistributionEnded(uint256 timeDifference);

    error DistributionNotStarted(uint256 timeDifference);

    error InvalidWeightedInput(uint256[] amounts);

    error NotEnoughRewardToDistribute(uint256 provided, uint256 actual);

    /// @dev A struct to hold pools scalar deploy parameters.
    struct PoolParameters {
        // An index of pool prototype in the factory list of prototypes.
        uint256 protoPoolIdx;
        // Expected chaidId of chain deploying to.
        uint256 chainId;
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

    /// @dev A helper function to generate bit masks from boolean array.
    /// @param flags A boolean array.
    function getMaskFromBooleans(
        bool[] calldata flags
    ) internal pure returns (bytes32 result) {
        if (flags.length > 256) {
            revert InvalidLength(flags.length, "flagsLength>256");
        }
        for (uint256 i = 0; i < flags.length; i++) {
            if (flags[i]) {
                result |= bytes32(i == 0 ? 1 : 1 << i);
            }
        }
    }

    /// @dev A helper function to check if some bit is up in the mask.
    /// @param mask A mask to be checked.
    /// @param index An index of the bit to be checked.
    function isBitUp(
        bytes32 mask,
        uint8 index
    ) internal pure returns (bool result) {
        uint256 counter = index == 0 ? 1 : 1 << index;
        return bytes32(counter) == mask & bytes32(counter);
    }
}
