// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IFortunnaPool.sol";
import "./FactoryAuthorized.sol";

contract FortunnaPool is IFortunnaPool, FactoryAuthorized {
    using SafeERC20 for IERC20;
    using FortunnaLib for bytes32;

    struct UserInfo {
        mapping(address => uint256) staked;
        mapping(address => uint256) rewardDebt;
    }

    FortunnaLib.PoolParameters public scalarParams;
    FortunnaLib.PoolParametersArrays public vectorParams;

    uint256 public rewardsDuration = 12 hours;

    function initialize(
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external override initializer {
        scalarParams = poolParameters;
        vectorParams = poolParametersArrays;
        super._initialize(_msgSender());
        // deploy fortunna token for staking,
        // deploy fortunna token for rewards
    }

    function updatePool() public {}

    function stake(uint256 amount) external {}

    function withdraw(
        uint8[] calldata stakingTokenIndicies,
        uint256[] calldata amounts
    ) external {}

    function getReward() public {
        // uint8[] calldata rewardTokenIndicies
    }
}
