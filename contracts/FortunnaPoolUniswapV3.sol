// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import "./interfaces/IFortunnaPool.sol";
import "./interfaces/external/IAccessControl.sol";

contract FortunnaPoolUniswapV3 is
    Initializable,
    Pausable,
    ReentrancyGuard,
    IFortunnaPool,
    IERC721Receiver
{
    struct RewardInfo {
        uint256[ASSETS_COUNT] userRewardsPerTokensPaid;
        uint256[ASSETS_COUNT] rewards;
    }

    struct DepositInfo {
        uint256[ASSETS_COUNT] amounts;
        uint128 balance; // liquidity share
        uint256 lastDepositTime;
    }

    uint24 public constant POOL_FEE = 3000;
    uint256 public constant REWARDS_DURATION = 12 hours;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    uint8 public constant ASSETS_COUNT = 2;

    uint128 public totalLiquidity;
    uint256 public positionId;
    uint256 public lastUpdateTime;
    uint256 public periodFinish;

    INonfungiblePositionManager public nonfungiblePositionManager;

    uint256[ASSETS_COUNT] public rewardRates;
    uint256[ASSETS_COUNT] public rewardsPerTokenStored;
    address[ASSETS_COUNT] public tokens;

    bool internal isInitialized;
    address internal _factory;

    FortunnaLib.PoolParameters scalarParams;
    FortunnaLib.PoolParametersArrays vectorParams;

    // user => amount paid \ reward amount in every token from `tokens`
    mapping(address => RewardInfo) internal rewardsInfo;

    // owner => deposit info
    mapping(address => DepositInfo) internal depositsInfo;

    function initialize(
        address _token0,
        address _token1,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays,
        INonfungiblePositionManager _nonfungiblePositionManager
    ) external initializer {
        _factory = _msgSender();
        nonfungiblePositionManager = _nonfungiblePositionManager;
        initialize(_token0, _token1, poolParameters, poolParametersArrays);
    }

    function initialize(
        address _token0,
        address _token1,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) public override onlyInitializing {
        tokens[0] = _token0;
        tokens[1] = _token1;
        scalarParams = poolParameters;
        vectorParams = poolParametersArrays;
        isInitialized = true;
    }

    function factory() external view override returns (address) {
        return _factory;
    }

    /// @notice Deposits tokens for the user.
    /// @dev Updates user's last deposit time. The deposit amount of tokens cannot be equal to 0.
    /// @param amount0 Amount of tokens to deposit.
    function stake(
        uint256 amount0,
        uint256 amount1
    )
        external
        whenNotPaused
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
        updateReward(_msgSender())
    {
        address sender = _msgSender();
        require(
            amount0 > 0 && amount1 > 0,
            "FortunnaPoolUniswapV3: can not stake zeros"
        );
        depositsInfo[sender].lastDepositTime = block.timestamp;
        uint256[ASSETS_COUNT] memory addedActualAmounts;
        uint128 addedLiquidity;
        if (totalLiquidity == 0) {
            (
                addedLiquidity,
                addedActualAmounts[0],
                addedActualAmounts[1]
            ) = _mintNewPosition(sender, amount0, amount1);
        } else {
            (
                addedLiquidity,
                addedActualAmounts[0],
                addedActualAmounts[1]
            ) = _increaseLiquidityCurrentRange(sender, amount0, amount1);
        }
        depositsInfo[sender].amounts[0] += addedActualAmounts[0];
        depositsInfo[sender].amounts[1] += addedActualAmounts[1];
        depositsInfo[sender].balance += addedLiquidity;
        totalLiquidity += addedLiquidity;
        emit Staked(sender, addedLiquidity);
    }

    /// @notice Withdraws all tokens deposited by the user and gets rewards for him.
    /// @dev Withdrawal comission is the same as for the `withdraw()` function.
    function exit() external whenNotPaused {
        withdraw(depositsInfo[_msgSender()].balance);
        getReward();
    }

    /// @notice Withdraws desired amount of deposited tokens for the user.
    /// @param amount Desired amount of liquidity tokens to withdraw.
    function withdraw(
        uint128 amount
    ) public whenNotPaused nonReentrant updateReward(_msgSender()) {
        address sender = _msgSender();
        require(amount > 0, "FortunnaPoolUniswapV3: can not withdraw 0");
        (uint256 withdrawn0, uint256 withdrawn1) = _decreaseLiquidity(
            sender,
            amount
        );
        depositsInfo[sender].amounts[0] -= withdrawn0;
        depositsInfo[sender].amounts[1] -= withdrawn1;
        depositsInfo[sender].balance -= amount;
        totalLiquidity -= amount;
        emit Withdrawn(sender, amount);
    }

    /// @notice Transfers rewards to the user.
    /// @dev There are no fees on the reward.
    function getReward()
        public
        whenNotPaused
        nonReentrant
        updateReward(_msgSender())
    {
        address sender = _msgSender();
        for (uint8 i = 0; i < ASSETS_COUNT; i++) {
            uint256 reward = rewardsInfo[sender].rewards[i];
            if (reward > 0) {
                rewardsInfo[sender].rewards[i] = 0;
                TransferHelper.safeTransfer(tokens[i], sender, reward);
                emit RewardPaid(sender, reward);
            }
        }
    }

    /// @notice Notifies the contract of an incoming reward and recalculates the reward rate.
    /// @dev Called by the admin once every 12 hours.
    function notifyRewardAmount()
        external
        updateReward(address(0))
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256[ASSETS_COUNT] memory totalRewards;
        (totalRewards[0], totalRewards[1]) = _collectAllFees();
        for (uint8 i = 0; i < ASSETS_COUNT; i++) {
            if (block.timestamp >= periodFinish) {
                rewardRates[i] = totalRewards[i] / REWARDS_DURATION;
            } else {
                uint256 remaining = periodFinish - block.timestamp;
                uint256 leftover = remaining * rewardRates[i];
                rewardRates[i] =
                    (totalRewards[i] + leftover) /
                    REWARDS_DURATION;
            }
            uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
            require(
                rewardRates[i] <= balance / REWARDS_DURATION,
                "FortunnaPoolUniswapV3: provided reward too high"
            );
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp + REWARDS_DURATION;
            emit RewardAdded(totalRewards[i]);
        }
    }

    /// @notice Retrieves the last time reward was applicable.
    /// @dev Allows the contract to correctly calculate rewards earned by users.
    /// @return Last time reward was applicable.
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice Retrieves the amount of reward per token staked.
    /// @dev The logic is derived from the StakingRewards contract.
    /// @return Amount of reward per token staked.
    function rewardPerToken(uint8 index) public view returns (uint256) {
        if (totalLiquidity == 0) {
            return rewardsPerTokenStored[index];
        }
        return
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRates[index] *
                FortunnaLib.PRECISION) /
            totalLiquidity +
            rewardsPerTokenStored[index];
    }

    /// @notice Retrieves the amount of rewards earned by the user.
    /// @dev The logic is derived from the StakingRewards contract.
    /// @param user User address.
    /// @return Amount of rewards earned by the user.
    function earned(address user, uint8 index) public view returns (uint256) {
        return
            (depositsInfo[user].balance *
                (rewardPerToken(index) -
                    rewardsInfo[user].userRewardsPerTokensPaid[index])) /
            FortunnaLib.PRECISION +
            rewardsInfo[user].rewards[index];
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @notice Calls the mint function defined in periphery, mints the same amount of each token.
    /// For this example we are providing 1000 PTT and 1000 USDC in liquidity
    /// @return liquidity The amount of liquidity for the position
    /// @return amount0 The amount of tokens[0]
    /// @return amount1 The amount of tokens[1]
    function _mintNewPosition(
        address sender,
        uint256 amount0ToMint,
        uint256 amount1ToMint
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        // transfer tokens to contract
        TransferHelper.safeTransferFrom(
            tokens[0],
            sender,
            address(this),
            amount0ToMint
        );
        TransferHelper.safeTransferFrom(
            tokens[1],
            sender,
            address(this),
            amount1ToMint
        );

        // Approve the position manager
        TransferHelper.safeApprove(
            tokens[0],
            address(nonfungiblePositionManager),
            amount0ToMint
        );
        TransferHelper.safeApprove(
            tokens[1],
            address(nonfungiblePositionManager),
            amount1ToMint
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: tokens[0],
                token1: tokens[1],
                fee: POOL_FEE,
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                amount0Desired: amount0ToMint,
                amount1Desired: amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        // Note that the pool defined by PTT/USDC and fee tier 0.3% must already be created and initialized in order to mint
        (positionId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);

        // Remove allowance and refund in both assets.
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove(
                tokens[0],
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(tokens[0], sender, refund0);
        }

        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove(
                tokens[1],
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund1 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(tokens[1], sender, refund1);
        }
    }

    /// @notice Collects the fees associated with provided liquidity
    /// @dev The contract must hold the erc721 token before it can collect fees
    /// @return amount0 The amount of fees collected in tokens[0]
    /// @return amount1 The amount of fees collected in tokens[1]
    function _collectAllFees()
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        // Caller must own the ERC721 position, meaning it must be a deposit
        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to _msgSender() and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: positionId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);
    }

    /// @dev A function that decreases the current liquidity by half. An example to show how to call the `decreaseLiquidity` function defined in periphery.
    function _decreaseLiquidity(
        address sender,
        uint128 amountToDecrease
    ) internal returns (uint256 amount0, uint256 amount1) {
        // get liquidity data for tokenId
        uint128 liquidity = depositsInfo[sender].balance;
        require(
            amountToDecrease <= liquidity,
            "FortunnaPoolUniswapV3: cannot decrease on this amount of liquidity."
        );

        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: positionId,
                    liquidity: amountToDecrease,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );

        TransferHelper.safeTransfer(tokens[0], sender, amount0);
        TransferHelper.safeTransfer(tokens[1], sender, amount1);
    }

    /// @notice Increases liquidity in the current range
    /// @dev Pool must be initialized already to add liquidity
    /// @param liquidity The liquidity amount added
    /// @param amount0 The amount to add of tokens[0]
    /// @param amount1 The amount to add of tokens[1]
    function _increaseLiquidityCurrentRange(
        address sender,
        uint256 amountAdd0,
        uint256 amountAdd1
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        TransferHelper.safeTransferFrom(
            tokens[0],
            sender,
            address(this),
            amountAdd0
        );
        TransferHelper.safeTransferFrom(
            tokens[1],
            sender,
            address(this),
            amountAdd1
        );

        TransferHelper.safeApprove(
            tokens[0],
            address(nonfungiblePositionManager),
            amountAdd0
        );
        TransferHelper.safeApprove(
            tokens[1],
            address(nonfungiblePositionManager),
            amountAdd1
        );

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: positionId,
                    amount0Desired: amountAdd0,
                    amount1Desired: amountAdd1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    modifier updateReward(address user) {
        lastUpdateTime = lastTimeRewardApplicable();
        for (uint8 i = 0; i < ASSETS_COUNT; i++) {
            rewardsPerTokenStored[i] = rewardPerToken(i);
            if (user != address(0)) {
                rewardsInfo[user].rewards[i] = earned(user, i);
                rewardsInfo[user].userRewardsPerTokensPaid[
                    i
                ] = rewardsPerTokenStored[i];
            }
        }
        _;
    }

    modifier onlyInitializing() {
        require(
            !isInitialized,
            "FortunnaPoolUniswapV3: cannot call the function when the contract already initialized."
        );
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(
            IAccessControl(_factory).hasRole(role, _msgSender()),
            "FortunnaPoolUniswapV3: unauthorized access"
        );
        _;
    }
}
