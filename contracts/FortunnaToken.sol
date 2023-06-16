// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./FactoryAuthorized.sol";
import "./interfaces/IFortunnaToken.sol";
import "./interfaces/IFortunnaPool.sol";

contract FortunnaToken is ERC20, FactoryAuthorized, IFortunnaToken {
    using SafeERC20 for IERC20;
    using FortunnaLib for bytes32;
    using Address for address payable;

    error InvalidWeightedInput(uint256[] amounts);

    bool public stakingOrRewardTokens;
    address public pool;
    bytes internal underlyingTokensSymbols = bytes("");

    address[] public underlyingTokens;
    mapping(uint256 => uint256) public getReserve;

    constructor() ERC20("Fortunna Token", "FTA") {}

    function initialize(
        bool _stakingOrRewardTokens,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external payable override initializer {
        address sender = _msgSender();
        pool = sender;
        super._initialize(IFortunnaPool(sender).factory());
        stakingOrRewardTokens = _stakingOrRewardTokens;
        uint256 initialReserve;
        _mint(address(0), 1e6); // to make mint/burn functions work and not to dry out entirely the liquidity.
        for (
            uint8 i = 0;
            i < poolParametersArrays.utilizingTokens.length;
            i++
        ) {
            initialReserve = _getInitialAmountOfUnderlyingToken(
                poolParametersArrays.initialRewardAmounts,
                i
            );
            getReserve[i] = initialReserve;
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
                    IERC20(poolParametersArrays.utilizingTokens[i])
                        .safeTransferFrom(pool, address(this), initialReserve);
                } else {
                    underlyingTokensSymbols = abi.encodePacked(
                        underlyingTokensSymbols,
                        "ETHx"
                    );
                    if (msg.value != initialReserve) {
                        revert FortunnaLib.NotEnoughtPayment(msg.value);
                    }
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
                stakingOrRewardTokens ? " for staking <" : " for rewards <",
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
                stakingOrRewardTokens ? "fts" : "ftr",
                underlyingTokensSymbols
            )
        );
    }

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

    function mint(
        address user,
        uint256 amount
    ) external payable override delegatedOnly {
        if (!stakingOrRewardTokens) {
            _onlyRoleInFactory(FortunnaLib.LP_MINTER_BURNER_ROLE);
        }
        for (uint256 i = 0; i < underlyingTokens.length; i++) {
            uint256 amountIn = calcUnderlyingTokensInOrOutPerFortunnaToken(
                i,
                amount
            );
            if (underlyingTokens[i] != address(0)) {
                IERC20(underlyingTokens[i]).safeTransferFrom(
                    user,
                    address(this),
                    amountIn
                );
            } else {
                if (amountIn != msg.value) {
                    revert FortunnaLib.NotEnoughtPayment(amountIn);
                }
            }
            getReserve[i] += amountIn;
        }
        _mint(user, amount);
    }

    function burn(
        address payable user,
        uint256 amount
    ) external override delegatedOnly {
        if (!stakingOrRewardTokens) {
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

    receive() external payable {
        emit NativeTokenReceived(msg.value);
    }
}
