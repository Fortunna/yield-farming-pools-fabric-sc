// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;
pragma abicoder v2;

import "../libraries/FortunnaLib.sol";

/// @title An interface to implement by the contract of the Fortuna Pool.
/// @author Fortunna Team
/// @notice The interface contains events and initializing function of the pool.
interface IFortunnaPool {
    /// @notice An event to be emitted when the part of the total reward is set to be distributed.
    /// @param partOfTotalRewards An exact amount of the part.
    event PartDistributed(uint256 partOfTotalRewards);

    /// @notice An event to be emitted when the total reward is set up.
    /// @param reward An exact amount of the total rewards.
    event RewardAdded(uint256 reward);

    /// @notice An event to be emitted when a user performs the stake.
    /// @param user A user (staker) address.
    /// @param amount Amount of the Fortuna Dust staked.
    event Staked(address indexed user, uint256 amount);

    /// @notice An event to be emitted when a user withdraws their staked Fortuna Dust.
    /// @param user A user (staker) address.
    /// @param amount An amount of the Fortuna Dust to be withdrawn.
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice An event to be emitted when a user receives a reward Fortuna Dust.
    /// @param user A user (staker) address.
    /// @param reward A reward Fortuna Dust paid to the user.
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice An event to be emitted when a user performs an emergency withdraw of their staked Fortuna Dust.
    /// @param user A user (staker) address.
    /// @param amount An amount of Fortuna Dust to be withdrawn.
    event EmergencyWithdraw(address indexed user, uint256 amount);

    /// @notice A getter function that returns a FortunnaFactory instance address.
    function factory() external view returns (address);

    /// @notice A function that is to be called when the pool is created by the factory.
    /// @param poolOwner An owner of the pool address.
    /// @param poolParameters A scalar parameters of the pool.
    /// @param poolParametersArrays A vector parameters of the pool.
    function initialize(
        address poolOwner,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external;
}
