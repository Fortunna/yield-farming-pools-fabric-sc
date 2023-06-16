// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IFortunnaPool.sol";
import "./interfaces/IFortunnaToken.sol";
import "./FactoryAuthorized.sol";

contract FortunnaPool is IFortunnaPool, FactoryAuthorized {
    using SafeERC20 for IERC20;
    using FortunnaLib for bytes32;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    FortunnaLib.PoolParameters public scalarParams;

    IFortunnaToken public stakingToken;
    IFortunnaToken public rewardToken;

    uint256 public allocPoint;
    uint256 public lastRewardTimestamp;
    uint256 public accRewardTokenPerShare;

    uint256 public allocationPoint;
    uint256 public totalAllocatedPoints;
    uint256 public rewardTokensPerSec;

    uint256 public totalStakedTokensBalance;
    uint256 public totalRewardTokensBalance;

    mapping(address => UserInfo) public usersInfo;
    FortunnaLib.PoolParametersArrays public vectorParams;

    function initialize(
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external override initializer {
        address __factory = _msgSender();
        scalarParams = poolParameters;
        vectorParams = poolParametersArrays;
        super._initialize(__factory);
        // deploy fortunna token for staking,
        // deploy fortunna token for rewards
    }

    function pendingRewards(address user) external view returns (uint256) {
        UserInfo storage userInfo = usersInfo[user];
        uint256 _accRewardTokenPerShare = accRewardTokenPerShare;
        uint256 _stakingTokenBalance = totalStakedTokensBalance;
        if (block.timestamp > lastRewardTimestamp && _stakingTokenBalance > 0) {
            uint256 reward = ((block.timestamp - lastRewardTimestamp) *
                rewardTokensPerSec *
                allocationPoint) / totalAllocatedPoints;
            _accRewardTokenPerShare +=
                (reward * FortunnaLib.PRECISION) /
                _stakingTokenBalance;
        }
        return
            (userInfo.amount * _accRewardTokenPerShare) /
            FortunnaLib.PRECISION -
            userInfo.rewardDebt;
    }

    function _provideRewardTokens(uint256 amount) internal returns (uint256) {}

    function updatePool() public {}

    function stake(uint256 amount) external {}

    function withdraw(uint256 amount) external {}

    function getReward() public {}

    function factory() external view override returns (address) {
        return _factory;
    }
}
