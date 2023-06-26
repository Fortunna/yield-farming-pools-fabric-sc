// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

import "../FortunnaLib.sol";

interface IFortunnaPool {
    event PartDistributed(uint256 partOfTotalRewards);
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 reward);

    function factory() external view returns (address);

    function initialize(
        address _stakingToken,
        address _rewardToken,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external;
}
