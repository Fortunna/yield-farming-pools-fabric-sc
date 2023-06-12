// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "../FortunnaLib.sol";

interface IFortunnaFactory {
    function evacuateTokens(address token, uint256 amount) external;

    function sendCollectedPayments(address token, address who) external;

    function createPool(
        bytes32 deploySalt,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external payable returns (address poolAddress);
}
