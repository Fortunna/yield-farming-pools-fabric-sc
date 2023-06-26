// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FortunnaErrorsLib.sol";

/// @title Fortunna Yield Farming pools lib that contains bit mas manipulation helpers.
/// @author Fortunna Team
/// @notice A lib holding bit mas manipulation functionality.
library FortunnaBitMaskLib {
    /// @dev A helper function to generate bit masks from boolean array.
    /// @param flags A boolean array.
    function getMaskFromBooleans(
        bool[] calldata flags
    ) internal pure returns (bytes32 result) {
        if (flags.length > 256) {
            revert FortunnaErrorsLib.InvalidLength(flags.length, "flagsLength>256");
        }
        for (uint256 i = 0; i < flags.length; i++) {
            if (flags[i]) {
                result |= bytes32(i == 0 ? 1 : 1 << i);
            }
        }
    }

    /// @dev A helper function to check if some bit is up in the mask.
    /// @param mask A mask to be checked.
    /// @param index An index of the bit to be checked.
    function isBitUp(
        bytes32 mask,
        uint8 index
    ) internal pure returns (bool result) {
        uint256 counter = index == 0 ? 1 : 1 << index;
        return bytes32(counter) == mask & bytes32(counter);
    }
}