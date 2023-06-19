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
    using SafeERC20 for IFortunnaToken;
    using FortunnaLib for bytes32;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    FortunnaLib.PoolParameters public scalarParams;

    IFortunnaToken public stakingToken;
    IFortunnaToken public rewardToken;

    uint256 public lastRewardTimestamp;
    uint256 public accRewardTokenPerShare;

    uint256 public rewardTokensPerSec;

    uint256 public totalStakedTokensBalance;

    uint256 public requestedRewardTokensToDistribute;
    uint256 public providedRewardTokensBalance;

    mapping(address => UserInfo) public usersInfo;
    FortunnaLib.PoolParametersArrays internal vectorParams;

    function initialize(
        address _stakingToken,
        address _rewardToken,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external override initializer {
        address __factory = _msgSender();
        scalarParams = poolParameters;
        vectorParams = poolParametersArrays;
        super._initialize(__factory);
        stakingToken = IFortunnaToken(_stakingToken);
        rewardToken = IFortunnaToken(_rewardToken);
        stakingToken.initialize(true, poolParameters, poolParametersArrays);
        rewardToken.initialize(false, poolParameters, poolParametersArrays);
    }

    function pendingRewards(address user) external view returns (uint256) {
        UserInfo storage userInfo = usersInfo[user];
        uint256 _accRewardTokenPerShare = accRewardTokenPerShare;
        uint256 _stakingTokenBalance = totalStakedTokensBalance;
        if (block.timestamp > lastRewardTimestamp && _stakingTokenBalance > 0) {
            uint256 reward = (block.timestamp - lastRewardTimestamp) *
                rewardTokensPerSec;
            _accRewardTokenPerShare +=
                (reward * FortunnaLib.PRECISION) /
                _stakingTokenBalance;
        }
        return
            (userInfo.amount * _accRewardTokenPerShare) /
            FortunnaLib.PRECISION -
            userInfo.rewardDebt;
    }

    function _provideRewardTokens(uint256 amount) internal {
        amount += requestedRewardTokensToDistribute;
        if (providedRewardTokensBalance > amount) {
            revert FortunnaLib.NotEnoughRewardToDistribute(providedRewardTokensBalance, requestedRewardTokensToDistribute);
        }
        requestedRewardTokensToDistribute = amount;
    }

    function updatePool() public {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }
        if (totalStakedTokensBalance == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 reward = (block.timestamp - lastRewardTimestamp) *
            rewardTokensPerSec;
        _provideRewardTokens(reward);
        accRewardTokenPerShare +=
            (rewardTokensPerSec * FortunnaLib.PRECISION) /
            totalStakedTokensBalance;
        lastRewardTimestamp = block.timestamp;
    }

    function stake(uint256 amount) external {
        address sender = _msgSender();
        UserInfo storage userInfo = usersInfo[sender];
        updatePool();
        if (amount > 0) {
            uint256 pending = (userInfo.amount * accRewardTokenPerShare) /
                FortunnaLib.PRECISION -
                userInfo.rewardDebt;
            _safeRewardTransfer(sender, pending);
            requestedRewardTokensToDistribute -= pending;
            providedRewardTokensBalance -= pending;
        }
        stakingToken.safeTransferFrom(sender, address(this), amount);
        totalStakedTokensBalance += amount;
        userInfo.amount += amount;
        userInfo.rewardDebt =
            (userInfo.amount * accRewardTokenPerShare) /
            FortunnaLib.PRECISION;
        emit Staked(sender, amount);
    }

    function withdraw(uint256 amount) external {
        address sender = _msgSender();
        UserInfo storage userInfo = usersInfo[sender];
        if (userInfo.amount < amount) {
            revert FortunnaLib.InvalidScalar(amount, "cannotWithdrawThisMuch");
        }
        
        updatePool();
        uint256 pending = (userInfo.amount * accRewardTokenPerShare) /
                FortunnaLib.PRECISION -
                userInfo.rewardDebt;
        _safeRewardTransfer(sender, pending);

        requestedRewardTokensToDistribute -= pending;
        providedRewardTokensBalance -= pending;
        
        userInfo.amount -= amount;
        userInfo.rewardDebt =
            (userInfo.amount * accRewardTokenPerShare) /
            FortunnaLib.PRECISION;
        stakingToken.safeTransfer(sender, amount);
        totalStakedTokensBalance -= amount;
        emit Withdrawn(sender, amount);
    }

    function emergencyWithdraw() external {
        address sender = _msgSender();
        UserInfo storage userInfo = usersInfo[sender];
        stakingToken.safeTransfer(sender, userInfo.amount);
        emit EmergencyWithdraw(sender, userInfo.amount);
        totalStakedTokensBalance -= userInfo.amount;
        userInfo.amount = 0;
        userInfo.rewardDebt = 0;
    }

    function factory() external view override returns (address) {
        return _factory;
    }

    function provideTotalRewards(uint256 amount) external only(FortunnaLib.POOL_REWARDS_PROVIDER)  {
        rewardToken.safeTransferFrom(_msgSender(), address(this), amount);
        providedRewardTokensBalance += amount;
    }

    function _safeRewardTransfer(address to, uint256 amount) internal {
        if (amount == 0) return;
        if (amount > requestedRewardTokensToDistribute) {
            IERC20(rewardToken).safeTransfer(to, requestedRewardTokensToDistribute);
        } else {
            IERC20(rewardToken).safeTransfer(to, amount);
        }
    }
}
