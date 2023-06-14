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

    /// @dev An error to be reverted if a `token` is not allowed to be pools reward token.
    /// @param token Some EIP20 compatible token.
    error RewardTokenNotAllowed(address token);
    
    /// @dev An error to be reverted if a `token` is not allowed to be pools staking token.
    /// @param token Some EIP20 compatible token.
    error StakingTokenNotAllowed(address token);
    
    /// @dev An error to be reverted if a `token` is not allowed to be pools reward token 
    /// from an external protocol.
    /// @param token Some EIP20 compatible token.
    error ExternalTokenNotAllowed(address token);

    /// @dev An error to be reverted if an unknown prototype name would be used to deploy
    /// a pool.
    /// @param name Name of the pools prototype smart-contract.
    error UnknownPrototypeName(string name);

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

    /// @dev A struct to hold pools scalar deploy parameters.
    struct PoolParameters {
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
        // A bit mask, where if the Nth bit is up then
        // in Nth pair of initial reward info first element is an address, otherwise: index
        bytes32 mask;
    }

    /// @dev A struct to hold pools vector deploy parameters.
    struct PoolParametersArrays {
        // A name of the pool prototype to be used.
        string poolPrototypeName;
        // An array of tokens to be used as either reward or staking tokens.
        address[] utilizingTokens;
        // An array of tokens to be used as reward tokens from some external protocols.
        address[] externalRewardTokens;
        // An array of indicies indicating which of `utilizingTokens` addresses are staking tokens.
        uint256[] stakingTokensIndicies;
        // An array of indicies indicating which of `utilizingTokens` addresses are reward tokens.
        uint256[] rewardTokensIndicies;
        // An initial total rewards amounts per index or address;
        // array of pairs <index or address, initial reward amount>
        bytes32[2][] initialRewardAmounts;
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
    bytes32 public constant BANNED_ROLE =
        keccak256("BANNED_ROLE");

    /// @notice A role hash to mark addresses to be held as payment for pool deploy tokens.
    bytes32 public constant ALLOWED_PAYMENT_TOKEN_ROLE =
        keccak256("ALLOWED_PAYMENT_TOKEN_ROLE");
    
    /// @notice A max of base points. (ex. Like 100 in percents)
    uint256 public constant BASE_POINTS_MAX = 10000;

    /// @dev A helper function to generate bit masks from boolean array.
    /// @param flags A boolean array.
    function getMaskFromBooleans(
        bool[] calldata flags
    ) internal pure returns (bytes32 result) {
        if (flags.length > 256) {
            revert InvalidLength(flags.length, "libMaskGen");
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
