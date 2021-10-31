// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {IERC721Stake} from "./Interfaces/IERC721Stake.sol";
import {LibCLLu} from "./LibCLL/LibCLL.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import "hardhat/console.sol";

contract ERC721Stake is IERC721Stake, Ownable, IERC721Receiver {
    using LibCLLu for LibCLLu.CLL;
    using SafeMath for uint256;

    mapping (uint256 => StakedToken) public stakedTokens;
    mapping (uint256 => mapping (uint256 => address)) tokenStakedBy;
    mapping (address => uint256) public userTokenStakes;

    CollectionInfo[] public collectionInfo;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    mapping (address => uint256) collectionMap;
    
    uint256 private nextStakedTokenId = 1;
    mapping (address => LibCLLu.CLL) private userStakedTokens;

    mapping (uint256 => uint256) public totalPhaseScores;

    mapping (uint256 => mapping (address => uint256)) public userPhaseScores;
    mapping (uint256 => uint256) public phaseStartTimes;
    uint256 public currentPhase = 0;

    mapping (address => bool) public phaseUpdaters;

    mapping (uint256 => mapping (address => uint256)) public userScores;
    uint256 public _totalScore;
    uint256 private scoresVer = 0;

    constructor(uint256 _startTime) {
        phaseStartTimes[currentPhase] = _startTime;
    }

    function stake(uint256 cid, uint256 tokenId) external {
        CollectionInfo storage collection = collectionInfo[cid];
        UserInfo storage user = userInfo[cid][msg.sender];

        _updateCollection(cid);

        uint256 pendingPhaseScore = user.staked.mul(collection.accPhaseScorePerPoint[currentPhase]).sub(user.phasesScoreDebt[currentPhase]);
        uint256 pendingPhaseTotalScore = collection.totalStaked.mul(collection.accPhaseScorePerPoint[currentPhase]).sub(collection.phasesTotalScoreDebt[currentPhase]);
        
        uint256 pendingScore = user.staked.mul(collection.accScorePerPoint).sub(user.scoreDebt[scoresVer]);
        uint256 pendingTotalScore = collection.totalStaked.mul(collection.accScorePerPoint).sub(collection.totalScoreDebt);

        user.staked = user.staked.add(1);
        user.phasesStaked[currentPhase] = user.staked;
        user.phasesScoreDebt[currentPhase] = user.staked.mul(collection.accPhaseScorePerPoint[currentPhase]);
        user.phasesUpdated[currentPhase] = true;

        collection.totalStaked = collection.totalStaked.add(1);
        collection.phasesTotalStaked[currentPhase] = collection.totalStaked;
        collection.phasesTotalScoreDebt[currentPhase] = collection.totalStaked.mul(collection.accPhaseScorePerPoint[currentPhase]);

        user.scoreDebt[scoresVer] = user.staked.mul(collection.accScorePerPoint);
        collection.totalScoreDebt = collection.totalStaked.mul(collection.accScorePerPoint);

        tokenStakedBy[cid][tokenId] = msg.sender;
        stakedTokens[nextStakedTokenId] = StakedToken(nextStakedTokenId, cid, tokenId);
        userStakedTokens[msg.sender].push(nextStakedTokenId, true);
        userTokenStakes[msg.sender] = userTokenStakes[msg.sender].add(1);

        if (pendingPhaseScore > 0) {
            userPhaseScores[currentPhase][msg.sender] = userPhaseScores[currentPhase][msg.sender].add(pendingPhaseScore);
        }

        if (pendingPhaseTotalScore > 0) {
            totalPhaseScores[currentPhase] = totalPhaseScores[currentPhase].add(pendingPhaseTotalScore);
        }

        if(pendingScore > 0) {
            userScores[scoresVer][msg.sender] = userScores[scoresVer][msg.sender].add(pendingScore);
        }

        if (pendingTotalScore > 0) {
            _totalScore = _totalScore.add(pendingTotalScore);
        }

        IERC721(collection.collection).safeTransferFrom(msg.sender, address(this), tokenId);
        
        emit Stake(msg.sender, cid, tokenId, nextStakedTokenId);

        nextStakedTokenId = nextStakedTokenId.add(1);
    }

    function unstake(uint256 id) external {
        require(id > 0, "Invalid ID");
        StakedToken memory staked = stakedTokens[id];
        CollectionInfo storage collection = collectionInfo[staked.cid];
        UserInfo storage user = userInfo[staked.cid][msg.sender];

        require(tokenStakedBy[staked.cid][staked.tokenId] == msg.sender, "Not your token");

        _updateCollection(staked.cid);

        uint256 pendingPhaseScore = user.staked.mul(collection.accPhaseScorePerPoint[currentPhase]).sub(user.phasesScoreDebt[currentPhase]);
        uint256 pendingPhaseTotalScore = collection.totalStaked.mul(collection.accPhaseScorePerPoint[currentPhase]).sub(collection.phasesTotalScoreDebt[currentPhase]);
        
        uint256 pendingScore = user.staked.mul(collection.accScorePerPoint).sub(user.scoreDebt[scoresVer]);
        uint256 pendingTotalScore = collection.totalStaked.mul(collection.accScorePerPoint).sub(collection.totalScoreDebt);

        user.staked = user.staked.sub(1, "Removing too many user tokens");
        user.phasesStaked[currentPhase] = user.staked;
        user.phasesScoreDebt[currentPhase] = user.staked.mul(collection.accPhaseScorePerPoint[currentPhase]);
        user.phasesUpdated[currentPhase] = true;

        collection.totalStaked = collection.totalStaked.sub(1, "Removing too many. total staked tokens");
        collection.phasesTotalStaked[currentPhase] = collection.totalStaked;
        collection.phasesTotalScoreDebt[currentPhase] = collection.totalStaked.mul(collection.accPhaseScorePerPoint[currentPhase]);

        user.scoreDebt[scoresVer] = user.staked.mul(collection.accScorePerPoint);
        collection.totalScoreDebt = collection.totalStaked.mul(collection.accScorePerPoint);

        delete stakedTokens[id];
        delete tokenStakedBy[staked.cid][staked.tokenId];
        userStakedTokens[msg.sender].remove(id);
        userTokenStakes[msg.sender] = userTokenStakes[msg.sender].sub(1, "Removing too many total user tokens");

        if (pendingPhaseScore > 0) {
            userPhaseScores[currentPhase][msg.sender] = userPhaseScores[currentPhase][msg.sender].add(pendingPhaseScore);
        }

        if (pendingPhaseTotalScore > 0) {
            totalPhaseScores[currentPhase] = totalPhaseScores[currentPhase].add(pendingPhaseTotalScore);
        }

        if(pendingScore > 0) {
            userScores[scoresVer][msg.sender] = userScores[scoresVer][msg.sender].add(pendingScore);
        }

        if (pendingTotalScore > 0) {
            _totalScore = _totalScore.add(pendingTotalScore);
        }

        IERC721(collection.collection).safeTransferFrom(address(this), msg.sender, staked.tokenId);

        emit Unstake(msg.sender, id);
    }

    function nextPhase(bool resetScores) external {
        require(phaseUpdaters[msg.sender], "You can't change the phase");

        uint256 colLen = collectionInfo.length;
        for (uint256 i = 0; i < colLen; i = i.add(1)) {
            _updateCollection(i);
            CollectionInfo storage collection = collectionInfo[i];
            collection.multiplier[currentPhase.add(1)] = collection.multiplier[currentPhase];
            collection.phasesTotalStaked[currentPhase.add(1)] = collection.phasesTotalStaked[currentPhase];

            if (resetScores) {
                collection.accScorePerPoint = 0;
                collection.totalScoreDebt = 0;
            }
        }

        currentPhase = currentPhase.add(1);
        phaseStartTimes[currentPhase] = block.timestamp;

        if (resetScores) {
            _totalScore = 0;
            scoresVer = scoresVer.add(1);
        }
    }

    function collectionLength() external view returns (uint256) {
        return collectionInfo.length;
    }

    function userStakedToken(address user, uint256 head) external view returns (StakedToken memory) {
        return stakedTokens[userStakedTokens[user].step(head, true)];
    }

    function userPhaseScore(address user, uint256 phase) external view returns (uint256) {
        uint256 _userScore = userPhaseScores[phase][user];
        uint256 colLen = collectionInfo.length;
        for (uint256 cid = 0; cid < colLen; cid++) {
            CollectionInfo storage collection = collectionInfo[cid];
            UserInfo storage _user = userInfo[cid][user];
            uint256 accPhaseScorePerPoint = collection.accPhaseScorePerPoint[phase];
            uint256 staked = _user.phasesStaked[phase];
            if (staked == 0 && !_user.phasesUpdated[phase]) {
                for (uint256 p = phase; p >= 0; p = p.sub(1, "Iteration failed")) {
                    if (_user.phasesUpdated[p]) {
                        staked = _user.phasesStaked[p];
                    }
                    if (p == 0) break;
                }
            }
            if (_phaseEndTime(phase) > collection.lastRewardTime && staked != 0) {
                uint256 score = _getPhaseTime(collection.lastRewardTime, phase).mul(collection.multiplier[phase]);
                accPhaseScorePerPoint = accPhaseScorePerPoint.add(score);
            }
            _userScore = _userScore.add(staked.mul(accPhaseScorePerPoint).sub(_user.phasesScoreDebt[phase]));
        }
        return _userScore;
    }

    function totalPhaseScore(uint256 phase) external view returns (uint256) {
        uint256 __totalScore = totalPhaseScores[phase];
        uint256 colLen = collectionInfo.length;
        for (uint256 cid = 0; cid < colLen; cid++) {
            CollectionInfo storage collection = collectionInfo[cid];
            uint256 accPhaseScorePerPoint = collection.accPhaseScorePerPoint[phase];
            uint256 totalStaked = collection.phasesTotalStaked[phase];
            if (_phaseEndTime(phase) > collection.lastRewardTime && totalStaked != 0) {
                uint256 score = _getPhaseTime(collection.lastRewardTime, phase).mul(collection.multiplier[phase]);
                accPhaseScorePerPoint = accPhaseScorePerPoint.add(score);
            }
            __totalScore = __totalScore.add(totalStaked.mul(accPhaseScorePerPoint).sub(collection.phasesTotalScoreDebt[phase]));
        }
        return __totalScore;
    }

    function userScore(address user) external view returns (uint256) {
        uint256 _userScore = userScores[scoresVer][user];
        uint256 colLen = collectionInfo.length;
        for (uint256 cid = 0; cid < colLen; cid++) {
            CollectionInfo storage collection = collectionInfo[cid];
            UserInfo storage _user = userInfo[cid][user];
            uint256 accScorePerPoint = collection.accScorePerPoint;
            uint256 staked = _user.staked;
            if (block.timestamp > collection.lastRewardTime && staked != 0) {
                uint256 score = _getTime(collection.lastRewardTime).mul(collection.currentMultiplier);
                accScorePerPoint = accScorePerPoint.add(score);
            }
            _userScore = _userScore.add(staked.mul(accScorePerPoint).sub(_user.scoreDebt[scoresVer]));
        }
        return _userScore;
    }

    function totalScore() external view returns (uint256) {
        uint256 __totalScore = _totalScore;
        uint256 colLen = collectionInfo.length;
        for (uint256 cid = 0; cid < colLen; cid++) {
            CollectionInfo storage collection = collectionInfo[cid];
            uint256 accScorePerPoint = collection.accScorePerPoint;
            uint256 totalStaked = collection.totalStaked;
            if (block.timestamp > collection.lastRewardTime && totalStaked != 0) {
                uint256 score = _getTime(collection.lastRewardTime).mul(collection.currentMultiplier);
                accScorePerPoint = accScorePerPoint.add(score);
            }
            __totalScore = __totalScore.add(totalStaked.mul(accScorePerPoint).sub(collection.totalScoreDebt));
        }
        return __totalScore;
    }
    
    function addCollection(address collection, uint256 multiplier) external onlyOwner {
        require(!_doesCollectionExist(collection), "Collection already exists");

        uint256 lastRewardTime = block.timestamp > phaseStartTimes[currentPhase] ? block.timestamp : phaseStartTimes[currentPhase];
        uint256 newColIndex = collectionInfo.length;
        collectionInfo.push();
        CollectionInfo storage _collection = collectionInfo[newColIndex];
        _collection.collection = collection;
        _collection.currentMultiplier = multiplier;
        _collection.multiplier[currentPhase] = multiplier;
        _collection.lastRewardTime = lastRewardTime;
        collectionMap[collection] = newColIndex;
    }

    function setCollectionMultiplier(uint256 cid, uint256 multiplier) external onlyOwner {
        _updateCollection(cid);

        CollectionInfo storage collection = collectionInfo[cid];
        collection.currentMultiplier = multiplier;
        collection.multiplier[currentPhase] = multiplier;
    }

    function setPhaseUpdater(address updater, bool allowed) external onlyOwner {
        phaseUpdaters[updater] = allowed;
    }

    function emergencyWithdraw(address collection, uint256 tokenId) external onlyOwner {
        address tokenOwner = address(0);

        if (_doesCollectionExist(collection)) {
            tokenOwner = tokenStakedBy[collectionMap[collection]][tokenId];
        }

        if (tokenOwner != address(0)) {
            try IERC721(collection).safeTransferFrom(address(this), tokenOwner, tokenId) {
                return;
            } catch {}
        }

        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);
    }
    
    function _updateCollection(uint256 cid) internal {
        CollectionInfo storage collection = collectionInfo[cid];
        if (_phaseEndTime(currentPhase) <= collection.lastRewardTime) return;

        uint256 score = _getPhaseTime(collection.lastRewardTime, currentPhase).mul(collection.currentMultiplier);

        collection.accPhaseScorePerPoint[currentPhase] = collection.accPhaseScorePerPoint[currentPhase].add(score);
        collection.accScorePerPoint = collection.accScorePerPoint.add(score);
        collection.lastRewardTime = block.timestamp;
    }
    
    function _phaseEndTime(uint256 phase) internal view returns (uint256) {
        return phase < currentPhase ? phaseStartTimes[phase.add(1)] : block.timestamp;
    }

    function _getPhaseTime(uint256 from, uint256 phase) internal view returns (uint256) {
        uint256 to = _phaseEndTime(phase);
        from = from > phaseStartTimes[phase] ? from : phaseStartTimes[phase];
        if (to < phaseStartTimes[phase]) return 0;
        return to.sub(from, "Time calculation failed");
    }

    function _getTime(uint256 from) internal view returns (uint256) {
        uint256 startTime = phaseStartTimes[0];
        from = from > startTime ? from : startTime;
        uint256 to = block.timestamp;
        if (to < startTime) {
            return 0;
        }
        return to.sub(from, "Time calculation failed");
    }

    function _doesCollectionExist(address collection) internal view returns (bool) {
        uint256 colLen = collectionInfo.length;
        for (uint256 cid = 0; cid < colLen; cid++) {
            if (collectionInfo[cid].collection == collection) return true;
        }
        return false;
    }

    // IERC721Receiver Overrides

    function onERC721Received(
        address operator,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external override view returns (bytes4) {
        require(operator == address(this), "Can't transfer ERC-721 token here without calling stake");
        return IERC721Receiver.onERC721Received.selector;
    }
}
