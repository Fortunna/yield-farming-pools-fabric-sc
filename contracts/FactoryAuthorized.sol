// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./FortunnaLib.sol";

abstract contract FactoryAuthorized is
    Initializable,
    Pausable,
    ReentrancyGuard
{
    address internal _factory;

    modifier delegatedOnly() {
        if (_isInitializing()) {
            revert FortunnaLib.NotInitialized();
        }
        _;
    }

    function _onlyRoleInFactory(bytes32 role) internal view {
        address sender = _msgSender();
        if (!IAccessControl(_factory).hasRole(role, sender)) {
            revert FortunnaLib.NotAuthorized(role, sender);
        }
    }

    modifier onlyAdmin() {
        // 0x00 == DEFAULT_ADMIN_ROLE
        _onlyRoleInFactory(0x00);
        _;
    }

    modifier only(bytes32 role) {
        _onlyRoleInFactory(0x00);
        _;
    }

    function _initialize(address __factory) internal {
        _factory = __factory;
    }

    /// @notice Triggers paused state.
    /// @dev Could be called only by the admin.
    function pause() external onlyAdmin {
        _pause();
    }

    /// @notice Returns to normal state.
    /// @dev Could be called only by the admin.
    function unpause() external onlyAdmin {
        _unpause();
    }
}
