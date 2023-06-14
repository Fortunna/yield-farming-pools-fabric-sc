// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../FortunnaLib.sol";

/// @title The interface for the Fortunna Yield Farming pools factory.
/// @author Fortunna Team
/// @notice The Fortunna Yield Faming pools factory facilitates creation of Fortunna pools and control over the protocol fees.
interface IFortunnaFactory {
    /// @notice An event to be fired when native tokens arrive to the fabric.
    /// @param amount An exact amount of the tokens arrived.
    event NativeTokenReceived(uint256 indexed amount);

    /// @notice A getter function to acquire an address of the named pool prototype.
    /// @param poolPrototype Hash of the name of the pool prototype.
    function getPoolPrototype(bytes32 poolPrototype) external view returns (address);

    /// @notice A getter function to acquire the payment info for one pool deploy.
    /// @return token An address of the token to be held as payment asset. 
    /// @return cost An actual cost of the pool deploy.
    function paymentInfo() external view returns (address token, uint256 cost);

    /// @notice An admin setter function to adjust payment info.
    /// @param _paymentInfo A struct to hold new payment info. 
    function setPaymentInfo(FortunnaLib.PaymentInfo calldata _paymentInfo) external;

    /// @notice An admin function to create a link between deployed implementation of the pool prototype an it's name.
    /// @param poolPrototypeName A human readable name of the pool prototype.
    /// @param poolPrototype An address of the deployed implementation.
    function setupPoolPrototype(
        string calldata poolPrototypeName,
        address poolPrototype
    ) external;

    /// @notice A public helper function to make mask generation quicker.
    /// @param flags An array of booleans to be converted to a mask.
    function generateMaskForInitialRewardAmountsPair(
        bool[] calldata flags
    ) external pure returns (bytes32);

    /// @notice An admin function to send all collected payments in any tokens to the specific receiver.
    /// @param token A token to be send to.
    /// @param who A receiver of the tokens.
    /// @param amount An exact amount of the tokens to be sent.
    function sendCollectedTokens(
        address token,
        address payable who,
        uint256 amount
    ) external;

    /// @notice The main public function. It is deploying the pool according to the pool parameters and it's prototype.
    /// @param deploySalt Some random 32 bytes to make the deploy cheaper.
    /// @param poolParameters A scalar parameters for the pool.
    /// @param poolParametersArrays A vector parameters for the pool.
    function createPool(
        bytes32 deploySalt,
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external payable returns (address poolAddress);
}