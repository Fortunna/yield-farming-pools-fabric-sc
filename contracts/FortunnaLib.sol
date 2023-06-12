// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library FortunnaLib {
    function getMaskFromBooleans(
        bool[] calldata flags
    ) internal pure returns (bytes32 result) {
        for (uint256 i = 0; i < flags.length; i++) {
            if (flags[i]) {
                result |= bytes32(1 << i);
            }
        }
    }

    function isBitUp(
        bytes32 mask,
        uint8 index
    ) internal pure returns (bool result) {
        uint256 counter = 1 << index;
        return bytes32(counter) == mask & bytes32(counter);
    }
}
