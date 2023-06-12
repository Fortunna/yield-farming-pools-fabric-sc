// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "../FortunnaLib.sol";

interface IFortunnaFactory {
    event NativeTokenReceived(uint256 indexed amount);
    function sendCollectedTokens(
        address token,
        address payable who,
        uint256 amount
    ) external;

    function createPool(
        bytes32 deploySalt,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external payable returns (address poolAddress);
}
