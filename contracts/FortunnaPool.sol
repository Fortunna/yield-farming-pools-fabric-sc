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

/// @title Classic Fortunna Yield Farming pool
/// @author Fortunna Team
/// @notice Deploys Classic Fortunna Yield Farming pool.
contract FortunnaPool is IFortunnaPool, FactoryAuthorized {
    using Clones for address;
    using SafeERC20 for IERC20;
    using SafeERC20 for IFortunnaToken;
    using FortunnaLib for bytes32;

    /// @dev A struct to hold an info about a user.
    struct UserInfo {
        // An amount of staking Fortuna Dust. 
        uint256 amount;
        // An amount of reward Fortuna Dust claimable.
        uint256 rewardDebt;
    }

    /// @dev An enumeration that holds the types of fees that are collected from the pool operations.
    enum Fee {
        GET_REWARD,
        STAKE,
        WITHDRAW
    }
    /// @dev A constant that equals to the `type(Fee).max`.
    uint256 private constant _FEE_LENGTH = 3;

    /// @notice A scalar params of the pool;
    FortunnaLib.PoolParameters public scalarParams;

    /// @notice A getter function for staking Fortuna Dust token address.
    IFortunnaToken public stakingToken;
    /// @notice A getter function for reward Fortuna Dust token address.
    IFortunnaToken public rewardToken;

    /// @notice A getter function for the timestamp when the pool was updated last.
    uint256 public lastRewardTimestamp;
    /// @notice A getter function for the accrued rewards amount per share (deposit).
    uint256 public accRewardTokenPerShare;

    /// @notice A getter for the amount of reward Fortuna Dust per second.
    uint256 public rewardTokensPerSec;

    /// @notice A getter for the total staked Fortuna Dust amount.
    uint256 public totalStakedTokensBalance;

    /// @notice A getter for the variable that stores the total expected amount of Fortuna Dust to be distributed.
    uint256 public expectedRewardTokensBalanceToDistribute;
    /// @notice A getter for the variable that stores the total requested amount of Fortuna Dust to be distrubted.
    uint256 public requestedRewardTokensToDistribute;
    /// @notice A getter for the variable that stores the total provided Fortuna Dust tokens provided by the admin.
    uint256 public providedRewardTokensBalance;

    /// @notice A getter for the users info struct. (Parameter: A user (staker) address.)
    mapping(address => UserInfo) public usersInfo;

    /// @dev An internal list of an accumulated fees amounts.
    uint256[_FEE_LENGTH] internal _accumulatedFees;

    /// @dev An internal container of vector parameters of the pool.
    FortunnaLib.PoolParametersArrays internal vectorParams;

    /// @inheritdoc IFortunnaPool
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

    /// @notice A helper function is to calculate the Fortuna Dust that would be minted when an initial amounts provided.
    /// @param initialAmounts A set of pairs of <index of the underlying token, an amount of this token>. 
    /// @param fortunnaTokenAddress A corresponding Fortuna Dust contract.
    /// @return amountToMint An amount of the Fortuna Dust minted.
    function calculateFortunnaTokens(
        uint256[2][] memory initialAmounts,
        address fortunnaTokenAddress
    ) public view returns (uint256 amountToMint) {
        for (uint256 i = 0; i < initialAmounts.length; i++) {
            uint256[2] memory pair = initialAmounts[i];
            if (pair[1] == 0) continue;
            amountToMint += IFortunnaToken(fortunnaTokenAddress)
                .calcFortunnaTokensInOrOutPerUnderlyingToken(i, pair[1]);
        }
    }

    /// @notice A view function that could get a reward amount belongs to the user.
    /// @param user A user (staker) address.
    /// @return An amount of rewards that belongs to the `user`.
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

    /// @dev An internal function that requests from the provided rewards a part to distribute.
    /// @param amount An amount of Fortuna Dust to distribute.
    function _provideRewardTokens(uint256 amount) internal {
        requestedRewardTokensToDistribute += amount;
        if (requestedRewardTokensToDistribute > providedRewardTokensBalance) {
            revert FortunnaErrorsLib.NotEnoughRewardToDistribute(
                providedRewardTokensBalance,
                requestedRewardTokensToDistribute
            );
        }
    }

    /// @notice A function that updates the pool info. Rewards per seconds, accumulative variables.
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

    /// @dev A validation internal function that checks if the pool is still functioning.
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

    /// @notice One of the main functions - so the sender could stake the Fortuna Dust.
    /// @param amount An amount of the Fortuna Dust to be staked.
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

    /// @notice One of the main functions - so the staker could withdraw his staked amounts.
    /// @param amount An amount of Fortuna Dust to be withdrawn.
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

    /// @dev An internal helper function that recalculates an amount of rewards that belongs to a sender.
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
        emit RewardPaid(sender, pending);
        uint256 pendingAndFee = pending + fee;
        requestedRewardTokensToDistribute -= pendingAndFee;
        providedRewardTokensBalance -= pendingAndFee;
        _recalcTokensPerSec();
    }

    /// @notice One of the main functions - so that the staker could acquire the rewards without having to withdraw his funds.
    function getReward() external nonReentrant {
        _checkTimeIntervals();
        _getReward();
    }

    /// @notice One of the main functions - only called when necessary by the staker, it withdraws senders (stakers) funds without getting the reward, so the funds would be returned safely.
    function emergencyWithdraw() external {
        address sender = _msgSender();
        UserInfo storage userInfo = usersInfo[sender];
        stakingToken.safeTransfer(sender, userInfo.amount);
        emit EmergencyWithdraw(sender, userInfo.amount);
        totalStakedTokensBalance -= userInfo.amount;
        userInfo.amount = 0;
        userInfo.rewardDebt = 0;
    }

    /// @inheritdoc IFortunnaPool
    function factory() external view override returns (address) {
        return _factory;
    }

    /// @notice An information function for the admin and the public to acquire an accumulated fees.
    /// @param fee A type of the fees.
    /// @return An amount claimable for the admin.
    function getAccumulatedFeesAmount(Fee fee) external view returns (uint256) {
        return _accumulatedFees[uint256(fee)];
    }

    /// @notice A function that callable only by the admin. It claims an accumulated fees.
    /// @param receiver A receiver of the claimed fees.
    /// @param fee A type of the fees.
    function withdrawFee(address receiver, Fee fee) public onlyAdmin {
        if (fee == Fee.GET_REWARD) {
            _safeRewardTransfer(receiver, _accumulatedFees[uint256(fee)]);
        }
        if (fee == Fee.STAKE || fee == Fee.WITHDRAW) {
            stakingToken.safeTransfer(receiver, _accumulatedFees[uint256(fee)]);
        }
    }

    /// @notice An analogical function like `withdrawFee`. But it claims all types of the fees.
    /// @param receiver A receiver of the claimed fees.
    function withdrawAllFees(address receiver) external onlyAdmin {
        for (uint256 i = 0; i < _accumulatedFees.length; i++) {
            withdrawFee(receiver, Fee(i));
        }
    }

    /// @notice A function that only callable by the bearer of the `POOL_REWARDS_PROVIDER` role. It sets an expected total amount of reward Fortuna Dust to be distributed.
    function addExpectedRewardTokensBalanceToDistribute() 
        external 
        only(FortunnaLib.POOL_REWARDS_PROVIDER)
    {
        uint256 amount = rewardToken.balanceOf(_msgSender()); 
        expectedRewardTokensBalanceToDistribute += amount;
        emit RewardAdded(amount);
    }

    /// @notice A function that only callable by the bearer of the `POOL_REWARDS_PROVIDER` role. It provides an actual part of the expected total reward Fortuna Dust to the pool and starts distributing.
    function providePartOfTotalRewards()
        external
        only(FortunnaLib.POOL_REWARDS_PROVIDER)
    {
        uint256 amount = (expectedRewardTokensBalanceToDistribute *
            scalarParams.totalRewardBasePointsPerDistribution) /
            FortunnaLib.BASE_POINTS_MAX;
        rewardToken.safeTransferFrom(_msgSender(), address(this), amount);
        providedRewardTokensBalance += amount;
        _recalcTokensPerSec();
        emit PartDistributed(amount);
    }

    /// @dev An internal function that recalculates total reward Fortuna Dust per second.
    function _recalcTokensPerSec() internal {
        rewardTokensPerSec = providedRewardTokensBalance / (scalarParams.endTimestamp - scalarParams.startTimestamp);
    }

    /// @dev An internal function that makes transfers of the reward Fortuna Dust safely and more gas efficient.
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
