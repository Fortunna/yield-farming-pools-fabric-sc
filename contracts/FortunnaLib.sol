// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library FortunnaLib {
    error Banned(address account);
    error RewardTokenNotAllowed(address token);
    error StakingTokenNotAllowed(address token);
    error ExternalTokenNotAllowed(address token);
    error UnknownPrototypeName(string name);
    error NotEnoughtPayment(uint256 amount);

    struct PoolParameters {
        uint256 chainId;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 minLockUpRewardsPeriod;
        uint256 earlyWithdrawalFeeBasePoints;
        uint256 depositWitdrawFeeBasePoints;
        // Bit mask, where if the Nth bit is up then
        // in Nth pair of initial reward info first element is an address, otherwise: index
        bytes32 mask;
    }

    struct PoolParametersArrays {
        string poolPrototypeName;
        address[] utilizingTokens;
        address[] externalRewardTokens;
        uint256[] stakingTokensIndicies;
        uint256[] rewardTokensIndicies;
        // initial total rewards amounts per index or address;
        // array of pairs <index or address, initial reward amount>
        bytes32[2][] initialRewardAmounts;
        // array of pairs <index of staking token, deposit amount>
        uint256[2][] initialDepositAmounts;
    }

    struct PaymentInfo {
        address paymentToken;
        uint256 cost;
    }

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
