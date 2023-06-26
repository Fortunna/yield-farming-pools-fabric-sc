// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

interface IAccessControl {
    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);
}
