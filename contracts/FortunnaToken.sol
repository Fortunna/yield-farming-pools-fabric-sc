// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

import "@openzeppelin/contracts-new/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-new/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-new/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-new/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-new/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-new/access/IAccessControl.sol";
import "@openzeppelin/contracts-new/utils/Address.sol";

import "./libraries/FortunnaErrorsLib.sol";
import "./libraries/FortunnaBitMaskLib.sol";
import "./FactoryAuthorized.sol";
import "./interfaces/IFortunnaToken.sol";
import "./interfaces/IFortunnaPool.sol";

/// @title Fortunna Yield Farming Fortunna Token - Fortuna Dust.
/// @author Fortunna Team
/// @notice Deploys FortunnaToken either for staking or rewards providing.
contract FortunnaToken is ERC20, FactoryAuthorized, IFortunnaToken {
    using SafeERC20 for IERC20;
    using FortunnaBitMaskLib for bytes32;
    using Address for address payable;

    /// @notice A getter function of boolean variable that indicares either the token was meant for staking or rewards providing. 
    bool public isStakingOrRewardToken;
    /// @notice A getter for the corresponding pool address that the contract is tied to.
    address public pool;
    /// @notice A getter for the generative symbol function (like in IERC20).
    bytes internal underlyingTokensSymbols = bytes("");

    /// @notice A getter for the list of an underlying tokens.
    address[] public underlyingTokens;
    /// @notice A getter with 1 parameter - get an amount of an underlying token on the contract.
    mapping(uint256 => uint256) public getReserve;

    /// @notice A classic OZ ERC20 constructor.
    constructor() ERC20("Fortunna Token", "FTA") {}

    /// @inheritdoc IFortunnaToken
    function initialize(
        bool _stakingOrRewardTokens,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external override initializer {
        address sender = _msgSender();
        pool = sender;
        super._initialize(IFortunnaPool(sender).factory());
        isStakingOrRewardToken = _stakingOrRewardTokens;
        _mint(FortunnaLib.DEAD_ADDRESS, 1); // to make mint/burn functions work and not to dry out entirely the liquidity.
        for (
            uint8 i = 0;
            i < poolParametersArrays.utilizingTokens.length;
            i++
        ) {
            getReserve[i] = 1;
            if (
                _stakingOrRewardTokens
                    ? poolParameters.stakingTokensMask.isBitUp(i)
                    : poolParameters.rewardTokensMask.isBitUp(i)
            ) {
                underlyingTokens.push(poolParametersArrays.utilizingTokens[i]);
                if (poolParametersArrays.utilizingTokens[i] != address(0)) {
                    underlyingTokensSymbols = abi.encodePacked(
                        underlyingTokensSymbols,
                        IERC20Metadata(poolParametersArrays.utilizingTokens[i])
                            .symbol(),
                        "x"
                    );
                } else {
                    underlyingTokensSymbols = abi.encodePacked(
                        underlyingTokensSymbols,
                        "ETHx"
                    );
                }
            }
        }
    }

    /// @inheritdoc ERC20
    function name()
        public
        view
        override(ERC20, IERC20Metadata)
        returns (string memory result)
    {
        result = string(
            abi.encodePacked(
                "Fortunna LP token",
                isStakingOrRewardToken ? " for staking <" : " for rewards <",
                underlyingTokensSymbols,
                ">"
            )
        );
    }

    /// @inheritdoc ERC20
    function symbol()
        public
        view
        override(ERC20, IERC20Metadata)
        returns (string memory result)
    {
        result = string(
            abi.encodePacked(
                isStakingOrRewardToken ? "fts" : "ftr",
                underlyingTokensSymbols
            )
        );
    }

    /// @inheritdoc IFortunnaToken
    function calcUnderlyingTokensInOrOutPerFortunnaToken(
        uint256 underlyingTokenIdx,
        uint256 amountToMintOrBurn
    ) public view override returns (uint256 underlyingTokensInOrOut) {
        underlyingTokensInOrOut =
            ((amountToMintOrBurn *
                getReserve[underlyingTokenIdx] *
                FortunnaLib.PRECISION) / totalSupply()) /
            FortunnaLib.PRECISION;
    }

    /// @inheritdoc IFortunnaToken
    function calcFortunnaTokensInOrOutPerUnderlyingToken(
        uint256 underlyingTokenIdx,
        uint256 underlyingTokenAmountInOrOut
    ) public view override returns (uint256 fortunnaTokensAmountInOrOut) {
        fortunnaTokensAmountInOrOut =
            ((underlyingTokenAmountInOrOut *
                totalSupply() *
                FortunnaLib.PRECISION) / getReserve[underlyingTokenIdx]) /
            FortunnaLib.PRECISION;
    }

    /// @inheritdoc IFortunnaToken
    function mint(
        address user,
        uint256 amountToMint
    ) external payable override delegatedOnly {
        if (!isStakingOrRewardToken) {
            _onlyRoleInFactory(FortunnaLib.LP_MINTER_BURNER_ROLE);
        }
        for (uint256 i = 0; i < underlyingTokens.length; i++) {
            uint256 amountIn = calcUnderlyingTokensInOrOutPerFortunnaToken(
                i,
                amountToMint
            );
            if (underlyingTokens[i] != address(0)) {
                IERC20(underlyingTokens[i]).safeTransferFrom(
                    user,
                    address(this),
                    amountIn
                );
            } else {
                if (amountIn > msg.value) {
                    revert FortunnaErrorsLib.NotEnoughtPayment(amountIn);
                }
            }
            getReserve[i] += amountIn;
        }
        _mint(user, amountToMint);
    }

    /// @inheritdoc IFortunnaToken
    function burn(
        address payable user,
        uint256 amount
    ) external override delegatedOnly {
        if (!isStakingOrRewardToken) {
            _onlyRoleInFactory(FortunnaLib.LP_MINTER_BURNER_ROLE);
        }
        for (uint256 i = 0; i < underlyingTokens.length; i++) {
            uint256 amountOut = calcUnderlyingTokensInOrOutPerFortunnaToken(
                i,
                amount
            );
            if (underlyingTokens[i] != address(0)) {
                IERC20(underlyingTokens[i]).safeTransferFrom(
                    address(this),
                    user,
                    amountOut
                );
            } else {
                user.sendValue(amountOut);
            }
            getReserve[i] -= amountOut;
        }
        _burn(user, amount);
    }

    /// @dev A helper internal function that helps peruse the pairs list to find an amount of the underlying token under a certain index.
    function _getInitialAmountOfUnderlyingToken(
        uint256[2][] calldata pairs,
        uint8 idx
    ) internal pure returns (uint256 result) {
        for (uint256 i = 0; i < pairs.length; i++) {
            if (pairs[i][0] == idx) {
                result = pairs[i][1];
                break;
            }
        }
    }

    /// @inheritdoc ERC20
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        uint256 currentAllowance = allowance(owner, spender);
        if (spender == pool) {
            currentAllowance = type(uint256).max;
        }
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "FortunnaToken: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /// @dev Every income in native tokens should be recorded as the behaviour
    /// of the contract would be a funds hub like.
    receive() external payable {
        emit NativeTokenReceived(msg.value);
    }
}
