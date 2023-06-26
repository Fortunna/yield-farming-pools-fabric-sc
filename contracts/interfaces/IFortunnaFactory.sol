// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

import "../libraries/FortunnaErrorsLib.sol";
import "../libraries/FortunnaBitMaskLib.sol";
import "../libraries/FortunnaLib.sol";
import "./INativeTokenReceivable.sol";

/// @title The interface for the Fortunna Yield Farming pools factory.
/// @author Fortunna Team
/// @notice The Fortunna Yield Faming pools factory facilitates creation of Fortunna pools and control over the protocol fees.
interface IFortunnaFactory is INativeTokenReceivable {
    event PoolCreated(address indexed pool);

    /// @notice A getter function to acquire the payment info for one pool deploy.
    /// @return token An address of the token to be held as payment asset.
    /// @return cost An actual cost of the pool deploy.
    function paymentInfo() external view returns (address token, uint256 cost);

    /// @notice An admin setter function to adjust payment info.
    /// @param _paymentInfo A struct to hold new payment info.
    function setPaymentInfo(
        FortunnaLib.PaymentInfo calldata _paymentInfo
    ) external;

    /// @notice An admin function to create to add deployed prototype.
    /// @param prototype An address of the deployed prototype.
    function addPrototype(address prototype) external;

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
    /// @param poolParameters A scalar parameters for the pool.
    /// @param poolParametersArrays A vector parameters for the pool.
    function createPool(
        FortunnaLib.PoolParameters calldata poolParameters,
        FortunnaLib.PoolParametersArrays calldata poolParametersArrays
    ) external payable returns (address poolAddress);

    /// @notice A public getter function to acquire a pool address at the specific index.
    /// @param index An index in the pools enumerable set.
    function getPoolAt(uint256 index) external view returns (address);

    /// @notice A public getter function to acquire the total amount of deployed pools.
    function getPoolsLength() external view returns (uint256);

    /// @notice A public getter function to acquire a prototype address at the specific index.
    /// @param index An index in the pools enumerable set.
    function getPrototypeAt(uint256 index) external view returns (address);

    /// @notice A public getter function to acquire the total amount of deployed prototypes.
    function getPrototypesLength() external view returns (uint256);
}
