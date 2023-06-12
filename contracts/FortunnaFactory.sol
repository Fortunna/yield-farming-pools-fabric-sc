// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./FortunnaLib.sol";
import "./interfaces/IFortunnaFactory.sol";
import "./interfaces/IFortunnaPool.sol";

contract FortunnaFactory is AccessControl, IFortunnaFactory {
    using SafeERC20 for IERC20;
    using FortunnaLib for bytes32;
    using Clones for address;

    mapping(bytes32 => address) public getPoolPrototype;
    FortunnaLib.PaymentInfo public paymentInfo;

    constructor(address[] memory paymentTokens) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(FortunnaLib.ALLOWED_PAYMENT_TOKEN_ROLE, address(0));
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            _grantRole(FortunnaLib.ALLOWED_PAYMENT_TOKEN_ROLE, paymentTokens[i]);
        }
    }

    function setPaymentInfo(
        FortunnaLib.PaymentInfo calldata _paymentInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        paymentInfo = _paymentInfo;
    }

    function setupPoolPrototype(
        string calldata poolPrototypeName,
        address poolPrototype
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        getPoolPrototype[keccak256(bytes(poolPrototypeName))] = poolPrototype;
    }

    function renounceRole(bytes32 role, address account) public override {
        if (hasRole(FortunnaLib.BANNED_ROLE, account)) revert FortunnaLib.Banned(account);
        super.renounceRole(role, account);
    }

    function generateMaskForInitialRewardAmountsPair(
        bool[] calldata flags
    ) external pure returns (bytes32) {
        return FortunnaLib.getMaskFromBooleans(flags);
    }

    function _validateRoles(
        address sender,
        address[] calldata _utilizingTokens,
        uint256[] calldata _stakingTokensIndicies,
        uint256[] calldata _rewardTokensIndicies,
        address[] calldata _externalRewardTokens
    ) internal view {
        if (hasRole(FortunnaLib.BANNED_ROLE, sender)) revert FortunnaLib.Banned(sender);
        uint256 i = 0;
        address token;
        for (i; i < _stakingTokensIndicies.length; i++) {
            token = _utilizingTokens[_stakingTokensIndicies[i]];
            if (!hasRole(FortunnaLib.ALLOWED_STAKING_TOKEN_ROLE, token)) {
                revert FortunnaLib.StakingTokenNotAllowed(token);
            }
        }
        i = 0;
        for (i; i < _rewardTokensIndicies.length; i++) {
            token = _utilizingTokens[_rewardTokensIndicies[i]];
            if (!hasRole(FortunnaLib.ALLOWED_STAKING_TOKEN_ROLE, token)) {
                revert FortunnaLib.RewardTokenNotAllowed(token);
            }
        }
        i = 0;
        for (i; i < _externalRewardTokens.length; i++) {
            token = _externalRewardTokens[i];
            if (!hasRole(FortunnaLib.ALLOWED_STAKING_TOKEN_ROLE, token)) {
                revert FortunnaLib.ExternalTokenNotAllowed(token);
            }
        }
    }

    function _validateScalarParameters(FortunnaLib.PoolParameters calldata _poolParameters) internal view {
        if (_poolParameters.chainId != block.chainid) {
            revert FortunnaLib.ForeignChainId(_poolParameters.chainId);
        }
        if (_poolParameters.startTimestamp <= _poolParameters.endTimestamp) {
            revert FortunnaLib.IncorrectInterval(_poolParameters.startTimestamp, _poolParameters.endTimestamp, "time");
        }
        if (_poolParameters.minStakeAmount <= _poolParameters.maxStakeAmount) {
            revert FortunnaLib.IncorrectInterval(_poolParameters.minStakeAmount, _poolParameters.maxStakeAmount, "stakeAmount");
        }
        if (_poolParameters.earlyWithdrawalFeeBasePoints > FortunnaLib.BASE_POINTS_MAX) {
            revert FortunnaLib.IncorrectBasePoints(_poolParameters.earlyWithdrawalFeeBasePoints, "earlyWithdrawal");
        }
        if (_poolParameters.depositWitdrawFeeBasePoints > FortunnaLib.BASE_POINTS_MAX) {
            revert FortunnaLib.IncorrectBasePoints(_poolParameters.depositWitdrawFeeBasePoints, "depositWithdraw");
        }
    }

    function createPool(
        bytes32 deploySalt,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external payable override returns (address poolAddress) {
        address sender = _msgSender(); 
        _validateRoles(
            sender,
            poolParametersArrays.utilizingTokens,
            poolParametersArrays.stakingTokensIndicies,
            poolParametersArrays.rewardTokensIndicies,
            poolParametersArrays.externalRewardTokens
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
            IERC20(paymentInfo.paymentToken).safeTransferFrom(sender, address(this), paymentInfo.cost);
        }

        poolAddress = Clones.predictDeterministicAddress(
            prototypeAddress,
            deploySalt
        );
        Clones.cloneDeterministic(prototypeAddress, deploySalt);
        IFortunnaPool(poolAddress).initalize(
            poolParameters,
            poolParametersArrays
        );
    }

    function sendCollectedTokens(
        address token,
        address payable who,
        uint256 amount
    )
        external 
        override
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (token != address(0)) {
            IERC20(token).safeTransfer(_msgSender(), amount);
        } else {
            who.transfer(amount);
        }
    }

    receive() external payable {
        emit NativeTokenReceived(msg.value);
    }
}
