// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

/// @title The interface for the Fortunna Yield Farming smart-contracts that can receive native tokens.
/// @author Fortunna Team
/// @notice The interface allows smart-contracts to use an event to document all native tokens incoms.
interface INativeTokenReceivable {
    /// @notice An event to be fired when native tokens arrive to the fabric.
    /// @param amount An exact amount of the tokens arrived.
    event NativeTokenReceived(uint256 indexed amount);
}
