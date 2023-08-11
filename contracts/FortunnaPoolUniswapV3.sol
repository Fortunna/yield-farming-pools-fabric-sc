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

/// @title Uniswap V3 Fortunna Yield Farming pool
/// @author Fortunna Team
/// @notice Deploys Uniswap V3 Fortunna Yield Farming pool.
contract FortunnaPoolUniswapV3 is
    Initializable,
    Pausable,
    ReentrancyGuard,
    IFortunnaPool,
    IERC721Receiver
{
    /// @dev A struct that holds an info for total rewards per user.
    struct RewardInfo {
        // A user rewards per liquidity token already paid.
        uint256[ASSETS_COUNT] userRewardsPerTokensPaid;
        // A user rewards claimable.
        uint256[ASSETS_COUNT] rewards;
    }

    /// @dev A struct that holds an info about the deposit info per user.
    struct DepositInfo {
        // A vector of amounts of underlying staking tokens.
        uint256[ASSETS_COUNT] amounts;
        // A liquidity share that belongs to the user.
        uint128 balance;
        // Last time when users rewards were updated.
        uint256 lastDepositTime;
    }

    /// @dev An address of the actual contract instance. The original address as part of the context.
    address private immutable __self = address(this);

    /// @notice A getter for the variable that is a part of the Uniswap V3 setting - fee amount of the pool.
    uint24 public poolFee = 3000;
    /// @notice A getter for the constant that is a part of the Fortuna Pool setting - a time interval after which an admin has to update the provided reward amount.
    uint256 public constant REWARDS_DURATION = 12 hours;
    /// @notice A getter for the constant that is a part of the Uniswap V3 setting - a deadline duration for the Uniswap V3 operations.
    uint32 public constant LIQUIDITY_ADDITION_DEADLINE_DURATION = 1 hours;
    /// @notice A getter for the constant that is a part of the OZ AccessControl setting - An admin role.
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    /// @notice A getter for the constant that is a part of the Fortuna Pool setting - amount of underlying tokens.
    uint8 public constant ASSETS_COUNT = 2;

    /// @notice A getter for the total liquidity minted.
    uint128 public totalLiquidity;
    /// @notice A getter for the ID of the Nonfungible Position at the Uniswap V3.
    uint256 public positionId;
    /// @notice A getter for the time when the pool has been updated recently.
    uint256 public lastUpdateTime;
    /// @notice A getter for the time when the pool has to end the distribution.
    uint256 public periodFinish;

    /// @notice A getter for the address of a NonfungiblePositionManager of Uniswap V3.
    INonfungiblePositionManager public nonfungiblePositionManager;

    /// @notice A getter that returns a reward rates for both of the underlying staking tokens.
    uint256[ASSETS_COUNT] public rewardRates;
    /// @notice A getter that returns a rewards per token stored per underlying staking token.
    uint256[ASSETS_COUNT] public rewardsPerTokenStored;
    /// @notice A getter that returns a pair of addresses of underlying staking tokens.
    address[ASSETS_COUNT] public tokens;

    /// @dev A field that contains the flag - if the contract was initialized.
    bool internal isInitialized;
    /// @dev A field that contains the factory address.
    address internal _factory;

    /// @notice A getter that returns a set of scalar parameters of the pool.    
    FortunnaLib.PoolParameters public scalarParams;
    /// @dev An internal set of the vector parameters of the pool.
    FortunnaLib.PoolParametersArrays internal vectorParams;

    /// @dev A getter that provides the `RewardInfo` struct instance per user.
    mapping(address => RewardInfo) internal rewardsInfo;

    /// @dev A getter that provides the `DepositInfo` struct instance per user.
    mapping(address => DepositInfo) internal depositsInfo;

    /// @inheritdoc IFortunnaPool
    function initialize(
        address,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) public override initializer {
        _factory = _msgSender();
        nonfungiblePositionManager = INonfungiblePositionManager(
            poolParameters.custom.nonfungiblePositionManager
        );
        tokens[0] = poolParametersArrays.utilizingTokens[0];
        tokens[1] = poolParametersArrays.utilizingTokens[1];
        scalarParams = poolParameters;
        vectorParams = poolParametersArrays;
        isInitialized = true;
    }

    /// @inheritdoc IFortunnaPool
    function factory() external view override returns (address) {
        return _factory;
    }

    /// @notice Changes a fee type of the pair to be invested in.
    /// @dev WARNING: should the function be used twice - an older position is locked and inaccessible FOREVER.
    /// @param newFeeType New tier value of the fee in a pair.
    function setFeeType(uint24 newFeeType) 
        external 
        delegatedOnly 
        whenNotPaused 
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        poolFee = newFeeType;
    }

    /// @notice Deposits tokens for the user.
    /// @dev Updates user's last deposit time. The deposit amount of tokens cannot be equal to 0.
    /// @param amount0 Amount of tokens to deposit.
    function stake(
        uint256 amount0,
        uint256 amount1
    )
        external
        delegatedOnly
        whenNotPaused
        nonReentrant
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
    function exit() external delegatedOnly whenNotPaused {
        getReward();
        withdraw(depositsInfo[_msgSender()].balance);
    }

    /// @notice Withdraws desired amount of deposited tokens for the user.
    /// @param amount Desired amount of liquidity tokens to withdraw.
    function withdraw(
        uint128 amount
    )
        public
        delegatedOnly
        whenNotPaused
        nonReentrant
        updateReward(_msgSender())
    {
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
        delegatedOnly
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
        delegatedOnly
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
    function lastTimeRewardApplicable()
        public
        view
        returns (uint256)
    {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice Retrieves the amount of reward per token staked.
    /// @dev The logic is derived from the StakingRewards contract.
    /// @return Amount of reward per token staked.
    function rewardPerToken(
        uint8 index
    ) public view returns (uint256) {
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
    function earned(
        address user,
        uint8 index
    ) public view returns (uint256) {
        return
            (depositsInfo[user].balance *
                (rewardPerToken(index) -
                    rewardsInfo[user].userRewardsPerTokensPaid[index])) /
            FortunnaLib.PRECISION +
            rewardsInfo[user].rewards[index];
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address operator,
        address,
        uint256,
        bytes calldata
    ) external view override returns (bytes4) {
        require(
            operator == address(nonfungiblePositionManager),
            "FortunnaPoolUniswapV3: unauthorized operator"
        );
        return this.onERC721Received.selector;
    }

    /// @notice Calls the mint function defined in periphery, mints the same amount of each token.
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
                fee: poolFee,
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                amount0Desired: amount0ToMint,
                amount1Desired: amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + LIQUIDITY_ADDITION_DEADLINE_DURATION
            });

        nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            tokens[0], 
            tokens[1],
            poolFee,
            uint160(1 << 65) // 1:1 rate
        );
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
                    deadline: block.timestamp + LIQUIDITY_ADDITION_DEADLINE_DURATION
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
                    deadline: block.timestamp + LIQUIDITY_ADDITION_DEADLINE_DURATION
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    /// @dev A modifier that performs an update of the reward info per user. (Parameter: `user` - A user for which the info is updated.)
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

    /// @dev A modifier that allows to continue an execution if the contract is being initialized.
    modifier onlyInitializing() {
        require(
            !isInitialized,
            "FortunnaPoolUniswapV3: cannot call the function when the contract already initialized."
        );
        _;
    }

    /// @dev A modifier that restricts the direct calls to the contract instance. 
    modifier delegatedOnly() {
        require(
            isInitialized && __self != address(this),
            "FortunnaPoolUniswapV3: cannot call directly."
        );
        _;
    }

    /// @dev A modifier that restricts the calls of a non-bearer of `role`. 
    modifier onlyRole(bytes32 role) {
        require(
            IAccessControl(_factory).hasRole(role, _msgSender()),
            "FortunnaPoolUniswapV3: unauthorized access"
        );
        _;
    }
}
