// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../FortunnaLib.sol";

interface IFortunnaPool {
    event RewardAdded(address indexed rewardToken, uint256 reward);
    event Staked(
        address indexed stakingToken,
        address indexed user,
        uint256 amount
    );
    event Withdrawn(
        address indexed stakingToken,
        address indexed user,
        uint256 amount
    );
    event RewardPaid(
        address indexed rewardToken,
        address indexed user,
        uint256 reward
    );

    function initialize(
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external;
}
