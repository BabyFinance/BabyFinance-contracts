// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IERC721Stake {
    struct StakedToken {
        uint256 id;
        uint256 cid;
        uint256 tokenId;
    }

    struct CollectionInfo {
        address collection;
        mapping (uint256 => uint256) multiplier;
        uint256 lastRewardTime;
        mapping (uint256 => uint256) accPhaseScorePerPoint;
        uint256 totalStaked;
        mapping (uint256 => uint256) phasesTotalStaked;
        mapping (uint256 => uint256) phasesTotalScoreDebt;
        uint256 accScorePerPoint;
        uint256 totalScoreDebt;
        uint256 currentMultiplier;
    }

    struct UserInfo {
        uint256 staked;
        mapping (uint256 => uint256) phasesStaked;
        mapping (uint256 => uint256) phasesScoreDebt;
        mapping (uint256 => bool) phasesUpdated;
        mapping (uint256 => uint256) scoreDebt;
    }

    event Stake(address indexed user, uint256 indexed cid, uint256 indexed tokenId, uint256 stakedTokenId);
    event Unstake(address indexed user, uint256 indexed stakeId);
}
