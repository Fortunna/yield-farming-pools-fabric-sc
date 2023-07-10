// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

import "@openzeppelin/contracts-new/proxy/Clones.sol";
import "@openzeppelin/contracts-new/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-new/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-new/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-new/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IFortunnaFactory.sol";
import "./interfaces/IFortunnaPool.sol";
import "./interfaces/IFortunnaToken.sol";
import "./FactoryAuthorized.sol";

contract FortunnaPool is IFortunnaPool, FactoryAuthorized {
    using Clones for address;
    using SafeERC20 for IERC20;
    using SafeERC20 for IFortunnaToken;
    using FortunnaLib for bytes32;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    enum Fee {
        GET_REWARD,
        STAKE,
        WITHDRAW
    }

    FortunnaLib.PoolParameters public scalarParams;

    IFortunnaToken public stakingToken;
    IFortunnaToken public rewardToken;

    uint256 public lastRewardTimestamp;
    uint256 public accRewardTokenPerShare;

    uint256 public rewardTokensPerSec;

    uint256 public totalStakedTokensBalance;

    uint256 public expectedRewardTokensBalanceToDistribute;
    uint256 public requestedRewardTokensToDistribute;
    uint256 public providedRewardTokensBalance;

    mapping(address => UserInfo) public usersInfo;

    uint256[] internal _accumulatedFees;
    FortunnaLib.PoolParametersArrays internal vectorParams;

    function initialize(
        address poolOwner,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external override initializer {
        address sender = _msgSender();
        IFortunnaFactory __factory = IFortunnaFactory(sender);
        scalarParams = poolParameters;
        vectorParams = poolParametersArrays;
        super._initialize(address(__factory));

        uint256 poolIdx = __factory.getPoolsLength() - 1;
        address fortunnaTokenPrototype = __factory.getPrototypeAt(
            __factory.FORTUNNA_TOKEN_PROTO_INDEX()
        );
        bytes32 stakingTokenDeploySalt = keccak256(abi.encodePacked(poolIdx, true));
        bytes32 rewardTokenDeploySalt = keccak256(abi.encodePacked(poolIdx, false));

        stakingToken = IFortunnaToken(
            fortunnaTokenPrototype.cloneDeterministic(stakingTokenDeploySalt)
        );
        rewardToken = IFortunnaToken(
            fortunnaTokenPrototype.cloneDeterministic(rewardTokenDeploySalt)
        );
        stakingToken.initialize(true, poolParameters, poolParametersArrays);
        rewardToken.initialize(false, poolParameters, poolParametersArrays);

        uint256 amountToMint = calculateFortunnaTokens(
            poolParametersArrays.initialDepositAmounts,
            address(stakingToken)
        );
        if (amountToMint > 0) {
            stakingToken.mint(poolOwner, amountToMint);
            amountToMint = 0;
        }

        amountToMint = calculateFortunnaTokens(
            poolParametersArrays.initialRewardAmounts,
            address(rewardToken)
        );
        if (amountToMint > 0) {
            rewardToken.mint(poolOwner, amountToMint);
        }
    }

    function calculateFortunnaTokens(
        uint256[2][] memory initialDepositAmounts,
        address fortunnaTokenAddress
    ) public view returns (uint256 amountToMint) {
        for (uint256 i = 0; i < initialDepositAmounts.length; i++) {
            uint256[2] memory pair = initialDepositAmounts[i];
            if (pair[1] == 0) continue;
            amountToMint += IFortunnaToken(fortunnaTokenAddress)
                .calcFortunnaTokensInOrOutPerUnderlyingToken(i, pair[1]);
        }
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
        if (amount < providedRewardTokensBalance) {
            revert FortunnaErrorsLib.NotEnoughRewardToDistribute(
                providedRewardTokensBalance,
                requestedRewardTokensToDistribute
            );
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

    function _checkTimeIntervals() internal view {
        if (block.timestamp < scalarParams.startTimestamp) {
            revert FortunnaErrorsLib.DistributionNotStarted(
                scalarParams.startTimestamp - block.timestamp
            );
        }
        if (block.timestamp > scalarParams.endTimestamp) {
            revert FortunnaErrorsLib.DistributionEnded(
                block.timestamp - scalarParams.endTimestamp
            );
        }
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount > scalarParams.maxStakeAmount) {
            revert FortunnaErrorsLib.TooMuchStaked(
                amount,
                scalarParams.maxStakeAmount
            );
        }
        if (amount < scalarParams.minStakeAmount) {
            revert FortunnaErrorsLib.NotEnoughStaked(
                amount,
                scalarParams.minStakeAmount
            );
        }
        _checkTimeIntervals();
        address sender = _msgSender();
        UserInfo storage userInfo = usersInfo[sender];
        _getReward();
        stakingToken.safeTransferFrom(sender, address(this), amount);
        if (scalarParams.depositWithdrawFeeBasePoints > 0) {
            uint256 fee = (amount * scalarParams.depositWithdrawFeeBasePoints) /
                FortunnaLib.BASE_POINTS_MAX;
            _accumulatedFees[uint256(Fee.STAKE)] += fee;
            amount -= fee;
        }
        totalStakedTokensBalance += amount;
        userInfo.amount += amount;
        userInfo.rewardDebt =
            (userInfo.amount * accRewardTokenPerShare) /
            FortunnaLib.PRECISION;
        emit Staked(sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        _checkTimeIntervals();
        address sender = _msgSender();
        UserInfo storage userInfo = usersInfo[sender];
        if (userInfo.amount < amount) {
            revert FortunnaErrorsLib.InvalidScalar(
                amount,
                "cannotWithdrawThisMuch"
            );
        }
        _getReward();
        userInfo.amount -= amount;
        userInfo.rewardDebt =
            (userInfo.amount * accRewardTokenPerShare) /
            FortunnaLib.PRECISION;
        totalStakedTokensBalance -= amount;
        if (scalarParams.depositWithdrawFeeBasePoints > 0) {
            uint256 fee = (amount * scalarParams.depositWithdrawFeeBasePoints) /
                FortunnaLib.BASE_POINTS_MAX;
            _accumulatedFees[uint256(Fee.WITHDRAW)] += fee;
            amount -= fee;
        }
        stakingToken.safeTransfer(sender, amount);
        emit Withdrawn(sender, amount);
    }

    function _getReward() internal {
        address sender = _msgSender();
        UserInfo storage userInfo = usersInfo[sender];
        updatePool();
        uint256 pending = (userInfo.amount * accRewardTokenPerShare) /
            FortunnaLib.PRECISION -
            userInfo.rewardDebt;
        uint256 startTimestamp = scalarParams.startTimestamp;

        uint256 fee = 0;
        if (
            pending > 0 &&
            block.timestamp > startTimestamp &&
            block.timestamp <
            startTimestamp + scalarParams.minLockUpRewardsPeriod &&
            scalarParams.earlyWithdrawalFeeBasePoints > 0
        ) {
            fee =
                (pending * scalarParams.earlyWithdrawalFeeBasePoints) /
                FortunnaLib.BASE_POINTS_MAX;
            _accumulatedFees[uint256(Fee.GET_REWARD)] += fee;
            pending -= fee;
        }

        _safeRewardTransfer(sender, pending);
        uint256 pendingAndFee = pending + fee;
        requestedRewardTokensToDistribute -= pendingAndFee;
        providedRewardTokensBalance -= pendingAndFee;
    }

    function getReward() external nonReentrant {
        _checkTimeIntervals();
        _getReward();
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

    function getAccumulatedFeesAmount(Fee fee) external view returns (uint256) {
        return _accumulatedFees[uint256(fee)];
    }

    function withdrawFee(address receiver, Fee fee) public onlyAdmin {
        if (fee == Fee.GET_REWARD) {
            _safeRewardTransfer(receiver, _accumulatedFees[uint256(fee)]);
        }
        if (fee == Fee.STAKE || fee == Fee.WITHDRAW) {
            stakingToken.safeTransfer(receiver, _accumulatedFees[uint256(fee)]);
        }
    }

    function withdrawAllFees(address receiver) external onlyAdmin {
        for (uint256 i = 0; i < _accumulatedFees.length; i++) {
            withdrawFee(receiver, Fee(i));
        }
    }

    function addExpectedRewardTokensBalanceToDistribute() 
        external 
        only(FortunnaLib.POOL_REWARDS_PROVIDER)
    {
        uint256 amount = rewardToken.balanceOf(_msgSender()); 
        expectedRewardTokensBalanceToDistribute += amount;
        emit RewardAdded(amount);
    }

    function providePartOfTotalRewards()
        external
        only(FortunnaLib.POOL_REWARDS_PROVIDER)
    {
        uint256 amount = (expectedRewardTokensBalanceToDistribute *
            scalarParams.totalRewardBasePointsPerDistribution) /
            FortunnaLib.BASE_POINTS_MAX;
        rewardToken.safeTransferFrom(_msgSender(), address(this), amount);
        providedRewardTokensBalance += amount;
        emit PartDistributed(amount);
    }

    function _safeRewardTransfer(address to, uint256 amount) internal {
        if (amount == 0) return;
        if (amount > requestedRewardTokensToDistribute) {
            IERC20(rewardToken).safeTransfer(
                to,
                requestedRewardTokensToDistribute
            );
        } else {
            IERC20(rewardToken).safeTransfer(to, amount);
        }
    }
}
