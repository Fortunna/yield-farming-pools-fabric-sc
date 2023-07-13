// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

import "@openzeppelin/contracts-new/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-new/token/ERC20/extensions/IERC20Metadata.sol";

import "../libraries/FortunnaLib.sol";
import "./INativeTokenReceivable.sol";

/// @title An interface to implement by the contract of the Fortuna Dust.
/// @author Fortunna Team
/// @notice The interface contains functions of the mint, burn and calculations of the dust.
interface IFortunnaToken is IERC20, IERC20Metadata, INativeTokenReceivable {
    /// @notice A mint function that could be called either by anyone or only by an admin. Depends if the token is initialized as staking or reward token.
    /// @param user A user (minter) address.
    /// @param amount An amount to be minted.
    function mint(address user, uint256 amount) external payable;

    /// @notice A burn function that could be called either by anyone or only by an admin. Depends if the token is initialized as staking or reward token.
    /// @param user A user (burner) address.
    /// @param amount An amount to be burned.
    function burn(address payable user, uint256 amount) external;

    /// @notice A helper function to calculate an amount of Fortuna Dust to be minted/burned if this amount of an underlying token is placed/taken as a collateral. 
    /// @param underlyingTokenIdx A collateral token index.
    /// @param underlyingTokenAmountInOrOut An amount of the collateral token to be placed in or out.
    /// @return fortunnaTokensAmountInOrOut An amount of Fortuna Dust minted or burned.
    function calcFortunnaTokensInOrOutPerUnderlyingToken(
        uint256 underlyingTokenIdx,
        uint256 underlyingTokenAmountInOrOut
    ) external view returns (uint256 fortunnaTokensAmountInOrOut);

    /// @notice A helper function to calculate an amount of collateral tokens to be gotten out or placed in if a specified amount of Fortuna Dust provided.
    /// @param underlyingTokenIdx A collateral token index in the factory.
    /// @param amountToMintOrBurn An amount of the Fortuna Dust to be minted or burned.
    /// @return underlyingTokensInOrOut An amount of collateral token to be placed in or taken out.
    function calcUnderlyingTokensInOrOutPerFortunnaToken(
        uint256 underlyingTokenIdx,
        uint256 amountToMintOrBurn
    ) external view returns (uint256 underlyingTokensInOrOut);

    /// @notice An initializing function that could be called only once and only by the Pool contract.
    /// @param stakingOrRewardTokens Decide whether the Fortuna Dust token is staking or reward.
    /// @param poolParameters The scalar parameters.
    /// @param poolParametersArrays The vector parameters. 
    function initialize(
        bool stakingOrRewardTokens,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external;
}
