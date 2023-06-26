// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Fortunna Yield Farming pools lib that contains all the errors.
/// @author Fortunna Team
/// @notice A lib holding default errors.
library FortunnaErrorsLib {
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

    error NotImplemented();
}