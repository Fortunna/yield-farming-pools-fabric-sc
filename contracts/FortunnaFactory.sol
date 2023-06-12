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

    bytes32 public constant ALLOWED_REWARD_TOKEN_ROLE =
        keccak256("ALLOWED_REWARD_TOKEN_ROLE");
    bytes32 public constant ALLOWED_STAKING_TOKEN_ROLE =
        keccak256("ALLOWED_STAKING_TOKEN_ROLE");
    bytes32 public constant ALLOWED_EXTERNAL_TOKEN_ROLE =
        keccak256("ALLOWED_EXTERNAL_TOKEN_ROLE");
    bytes32 public constant BANNED_ROLE =
        keccak256("BANNED_ROLE");
    bytes32 public constant ALLOWED_PAYMENT_TOKEN_ROLE =
        keccak256("ALLOWED_PAYMENT_TOKEN_ROLE");

    uint256 public constant BASE_POINTS_MAX = 10000;

    mapping(bytes32 => address) public getPoolPrototype;
    FortunnaLib.PaymentInfo public paymentInfo;

    constructor(address[] memory paymentTokens) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ALLOWED_PAYMENT_TOKEN_ROLE, address(0));
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            _grantRole(ALLOWED_PAYMENT_TOKEN_ROLE, paymentTokens[i]);
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
        if (hasRole(BANNED_ROLE, account)) revert FortunnaLib.Banned(account);
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
        if (hasRole(BANNED_ROLE, sender)) revert FortunnaLib.Banned(sender);
        uint256 i = 0;
        address token;
        for (i; i < _stakingTokensIndicies.length; i++) {
            token = _utilizingTokens[_stakingTokensIndicies[i]];
            if (!hasRole(ALLOWED_STAKING_TOKEN_ROLE, token)) {
                revert FortunnaLib.StakingTokenNotAllowed(token);
            }
        }
        i = 0;
        for (i; i < _rewardTokensIndicies.length; i++) {
            token = _utilizingTokens[_rewardTokensIndicies[i]];
            if (!hasRole(ALLOWED_STAKING_TOKEN_ROLE, token)) {
                revert FortunnaLib.RewardTokenNotAllowed(token);
            }
        }
        i = 0;
        for (i; i < _externalRewardTokens.length; i++) {
            token = _externalRewardTokens[i];
            if (!hasRole(ALLOWED_STAKING_TOKEN_ROLE, token)) {
                revert FortunnaLib.ExternalTokenNotAllowed(token);
            }
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

    function evacuateTokens(address token, uint256 amount) external override {
    }

    function sendCollectedPayments(
        address token,
        address who
    ) external override {}

    receive() external payable {}

    fallback() external {}
}
