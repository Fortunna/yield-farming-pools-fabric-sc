// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../FortunnaLib.sol";
import "./INativeTokenReceivable.sol";

interface IFortunnaToken is IERC20, IERC20Metadata, INativeTokenReceivable {
    function mint(address user, uint256 amount) external payable;

    function burn(address payable user, uint256 amount) external;

    function calcFortunnaTokensInOrOutPerUnderlyingToken(
        uint256 underlyingTokenIdx,
        uint256 underlyingTokenAmountInOrOut
    ) external view returns (uint256 fortunnaTokensAmountInOrOut);

    function calcUnderlyingTokensInOrOutPerFortunnaToken(
        uint256 underlyingTokenIdx,
        uint256 amountToMintOrBurn
    ) external view returns (uint256 underlyingTokensInOrOut);

    function initialize(
        address poolCreator,
        bool stakingOrRewardTokens,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external payable;
}
