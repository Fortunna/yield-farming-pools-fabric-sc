// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

import "@openzeppelin/contracts-new/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-new/access/IAccessControl.sol";
import "@openzeppelin/contracts-new/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-new/security/Pausable.sol";

import "./libraries/FortunnaLib.sol";
import "./libraries/FortunnaErrorsLib.sol";

/// @title A contract that helps to manage the state of the Fortunna contracts.
/// @author Fortunna Team
/// @notice The contract contains protection from the direct calls and roles management.
abstract contract FactoryAuthorized is
    Initializable,
    Pausable,
    ReentrancyGuard
{
    /// @dev An address of the actual contract instance. The original address as part of the context.
    address internal immutable __self = address(this);

    /// @dev An address of the FortunnaFactory contract.
    address internal _factory;

    /// @dev A protection from the direct call modifier.
    modifier delegatedOnly() {
        if (_isInitializing() || __self == address(this)) {
            revert FortunnaErrorsLib.NotInitialized();
        }
        _;
    }

    /// @dev An internal function that checks if a certain `role` is granted to the sender.
    /// @param role A role hash.
    function _onlyRoleInFactory(bytes32 role) internal view {
        address sender = _msgSender();
        if (!IAccessControl(_factory).hasRole(role, sender)) {
            revert FortunnaErrorsLib.NotAuthorized(role, sender);
        }
    }

    /// @dev A modifier that allows only the admin sender to proceed.
    modifier onlyAdmin() {
        // 0x00 == DEFAULT_ADMIN_ROLE
        _onlyRoleInFactory(0x00);
        _;
    }

    /// @dev A modifier that allows only a certain `role` bearer to proceed.
    /// @param role A role hash.
    modifier only(bytes32 role) {
        _onlyRoleInFactory(role);
        _;
    }

    /// @dev An internal initializer which stores an address pointer to the FortunnaFactory instance.
    /// @param __factory The factory address.
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
