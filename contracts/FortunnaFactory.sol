// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/IFortunnaFactory.sol";
import "./interfaces/IFortunnaPool.sol";

/// @title Canonical Fortunna Yield Farming pools factory
/// @author Fortunna Team
/// @notice Deploys Fortunna Yield Farming pools and manages ownership and control over pool protocol fees.
contract FortunnaFactory is AccessControl, IFortunnaFactory {
    using SafeERC20 for IERC20;
    using FortunnaLib for bytes32;
    using Clones for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IFortunnaFactory
    mapping(bytes32 => address) public override getPoolPrototype;

    /// @inheritdoc IFortunnaFactory
    FortunnaLib.PaymentInfo public override paymentInfo;

    /// @dev A set of unique deployed pools.
    EnumerableSet.AddressSet internal pools;

    /// @notice A constructor.
    /// @param paymentTokens An array of tokens addresses to be allowed as payment for pool deploy tokens.
    constructor(address[] memory paymentTokens) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(FortunnaLib.ALLOWED_PAYMENT_TOKEN_ROLE, address(0));
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            _grantRole(
                FortunnaLib.ALLOWED_PAYMENT_TOKEN_ROLE,
                paymentTokens[i]
            );
        }
    }

    /// @inheritdoc IFortunnaFactory
    function getPoolAt(uint256 index) external view override returns (address) {
        return pools.at(index);
    }

    /// @inheritdoc IFortunnaFactory
    function getPoolsLength() external view override returns (uint256) {
        return pools.length();
    }

    /// @inheritdoc IFortunnaFactory
    function setPaymentInfo(
        FortunnaLib.PaymentInfo calldata _paymentInfo
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        paymentInfo = _paymentInfo;
    }

    /// @inheritdoc IFortunnaFactory
    function setupPoolPrototype(
        string calldata poolPrototypeName,
        address poolPrototype
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        getPoolPrototype[keccak256(bytes(poolPrototypeName))] = poolPrototype;
    }

    /// @inheritdoc AccessControl
    function renounceRole(bytes32 role, address account) public override {
        if (hasRole(FortunnaLib.BANNED_ROLE, account))
            revert FortunnaLib.Banned(account);
        super.renounceRole(role, account);
    }

    /// @inheritdoc IFortunnaFactory
    function generateMaskForInitialRewardAmountsPair(
        bool[] calldata flags
    ) external pure override returns (bytes32) {
        return FortunnaLib.getMaskFromBooleans(flags);
    }

    /// @dev An internal function that validates the addresses if they're allowed
    /// to be used as staking, reward, or external tokens and if the arrays lengths are less then 256.
    /// Also there is a check if `_utilizingTokens` and `_externalRewardTokens` are unique arrays.
    /// @param sender Alias for `_msgSender()`.
    /// @param stakingTokensMask A bit mask to define if the `utilizingTokens` token is for staking.
    /// @param rewardTokensMask A bit mask to define if the `utilizingTokens` token is for user rewards.
    /// @param utilizingTokens An array of tokens either for stake or for rewards.
    function _validateRoles(
        address sender,
        uint256 initialRewardAmountsLength,
        uint256 initialDepositAmountsLength,
        bytes32 stakingTokensMask,
        bytes32 rewardTokensMask,
        address[] calldata utilizingTokens
    ) internal view {
        if (hasRole(FortunnaLib.BANNED_ROLE, sender))
            revert FortunnaLib.Banned(sender);
        if (utilizingTokens.length > 256) {
            revert FortunnaLib.InvalidLength(
                utilizingTokens.length,
                "utilizingTokens>256"
            );
        }
        for (uint8 i = 0; i < utilizingTokens.length; i++) {
            address token = utilizingTokens[i];
            if (stakingTokensMask.isBitUp(i)) {
                if (!hasRole(FortunnaLib.ALLOWED_STAKING_TOKEN_ROLE, token)) {
                    revert FortunnaLib.NotAuthorized(
                        FortunnaLib.ALLOWED_STAKING_TOKEN_ROLE,
                        token
                    );
                }
            }
            if (rewardTokensMask.isBitUp(i)) {
                if (!hasRole(FortunnaLib.ALLOWED_REWARD_TOKEN_ROLE, token)) {
                    revert FortunnaLib.NotAuthorized(
                        FortunnaLib.ALLOWED_REWARD_TOKEN_ROLE,
                        token
                    );
                }
            }
        }
        if (initialRewardAmountsLength != utilizingTokens.length) {
            revert FortunnaLib.AreNotEqual(
                initialRewardAmountsLength,
                utilizingTokens.length,
                "tokensLen!=initRewardLen"
            );
        }

        if (initialDepositAmountsLength != utilizingTokens.length) {
            revert FortunnaLib.AreNotEqual(
                initialDepositAmountsLength,
                utilizingTokens.length,
                "tokensLen!=initDepositLen"
            );
        }
    }

    /// @dev An internal function that checks scalar parameters of the pools.
    /// Firstly, if the chainIds are as expected equal. Secondly, if the start and end timestamps making
    /// a valid time interval. Thirdly, if min and max stake amounts are making also a valid interval. Then,
    /// if early withdrawal fee and deposit/withdraw fee are represented as base points validly.
    /// @param _poolParameters A struct containing the scalar parameters of the pool.
    function _validateScalarParameters(
        FortunnaLib.PoolParameters calldata _poolParameters
    ) internal view {
        if (_poolParameters.chainId != block.chainid) {
            revert FortunnaLib.ForeignChainId(_poolParameters.chainId);
        }
        if (_poolParameters.startTimestamp <= _poolParameters.endTimestamp) {
            revert FortunnaLib.IncorrectInterval(
                _poolParameters.startTimestamp,
                _poolParameters.endTimestamp,
                "time"
            );
        }
        if (_poolParameters.minStakeAmount <= _poolParameters.maxStakeAmount) {
            revert FortunnaLib.IncorrectInterval(
                _poolParameters.minStakeAmount,
                _poolParameters.maxStakeAmount,
                "stakeAmount"
            );
        }
        if (
            _poolParameters.earlyWithdrawalFeeBasePoints >
            FortunnaLib.BASE_POINTS_MAX
        ) {
            revert FortunnaLib.IncorrectBasePoints(
                _poolParameters.earlyWithdrawalFeeBasePoints,
                "earlyWithdrawal"
            );
        }
        if (
            _poolParameters.depositWithdrawFeeBasePoints >
            FortunnaLib.BASE_POINTS_MAX
        ) {
            revert FortunnaLib.IncorrectBasePoints(
                _poolParameters.depositWithdrawFeeBasePoints,
                "depositWithdraw"
            );
        }
        if (
            _poolParameters.totalRewardBasePointsPerDistribution >
            FortunnaLib.BASE_POINTS_MAX
        ) {
            revert FortunnaLib.IncorrectBasePoints(
                _poolParameters.totalRewardBasePointsPerDistribution,
                "rewardBasePoints"
            );
        }
    }

    /// @inheritdoc IFortunnaFactory
    function createPool(
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external payable override returns (address poolAddress) {
        address sender = _msgSender();
        _validateRoles(
            sender,
            poolParametersArrays.initialRewardAmounts.length,
            poolParametersArrays.initialDepositAmounts.length,
            poolParameters.stakingTokensMask,
            poolParameters.rewardTokensMask,
            poolParametersArrays.utilizingTokens
        );
        _validateScalarParameters(poolParameters);

        address prototypeAddress = getPoolPrototype[
            keccak256(bytes(poolParametersArrays.poolPrototypeName))
        ];
        if (prototypeAddress == address(0)) {
            revert FortunnaLib.UnknownPrototypeName(
                poolParametersArrays.poolPrototypeName
            );
        }

        if (paymentInfo.paymentToken == address(0)) {
            if (msg.value < paymentInfo.cost) {
                revert FortunnaLib.NotEnoughtPayment(msg.value);
            }
        } else {
            IERC20(paymentInfo.paymentToken).safeTransferFrom(
                sender,
                address(this),
                paymentInfo.cost
            );
        }

        bytes32 deploySalt = keccak256(
            abi.encodePacked(prototypeAddress, sender, pools.length())
        );
        poolAddress = Clones.predictDeterministicAddress(
            prototypeAddress,
            deploySalt
        );
        if (!pools.add(poolAddress)) {
            revert FortunnaLib.AddressAlreadyExists(poolAddress);
        }
        Clones.cloneDeterministic(prototypeAddress, deploySalt);
        IFortunnaPool(poolAddress).initialize(
            poolParameters,
            poolParametersArrays
        );
    }

    /// @inheritdoc IFortunnaFactory
    function sendCollectedTokens(
        address token,
        address payable who,
        uint256 amount
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token != address(0)) {
            IERC20(token).safeTransfer(_msgSender(), amount);
        } else {
            who.transfer(amount);
        }
    }

    /// @dev Every income in native tokens should be recorded as the behaviour
    /// of the contract would be a funds hub like.
    receive() external payable {
        emit NativeTokenReceived(msg.value);
    }
}
