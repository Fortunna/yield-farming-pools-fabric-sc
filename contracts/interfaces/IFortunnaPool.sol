// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../FortunnaLib.sol";

interface IFortunnaPool {
    function initalize(
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external;
}
