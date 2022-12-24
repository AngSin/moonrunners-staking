// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Trophies is Ownable, ERC1155 {
    struct Stake {
        uint16[] tokenIds;
        uint256 timestamp;
    }
    mapping(address => Stake) userToStake;
    IERC721 public runnersContract;
    uint256 public stakingPeriod = 30 days;
    string baseUri;

    // trophy eligibility
    uint8 diamondEligibility = 25;
    uint8 goldEligibility = 10;
    uint8 silverEligibility = 5;
    uint8 bronzeEligibility = 1;

    // trophy ids
    uint8 diamondTrophyId = 3;
    uint8 goldTrophyId = 2;
    uint8 silverTrophyId = 1;
    uint8 bronzeTrophyId = 0;

    function setRunnersContract(IERC721 _runnersContract) public onlyOwner {
        runnersContract = _runnersContract;
    }

    function setBaseUri(string calldata _baseUri) public onlyOwner {
        baseUri = _baseUri;
    }

    function setStakingPeriod(uint256 _stakingPeriod) public onlyOwner {
        stakingPeriod = _stakingPeriod;
    }

    constructor() ERC1155(baseUri) {}

    function stakeExists(address _user) public view returns(bool) {
        return userToStake[_user].timestamp > 0;
    }

    modifier onlyStaker() {
        require(stakeExists(msg.sender), "You must stake first!");
        _;
}

    function tokenExistsInArray(uint16 tokenId, uint16[] memory tokenIds) private pure returns(bool) {
        for (uint16 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    function stake(uint16[] calldata _tokenIds) public {
        if (!stakeExists(msg.sender)) {
            Stake memory newStake = Stake(_tokenIds, block.timestamp);
            userToStake[msg.sender] = newStake;
            for (uint16 i = 0; i < _tokenIds.length; i++) {
                runnersContract.transferFrom(msg.sender, address(this), _tokenIds[i]);
            }
        } else {
            Stake memory existingStake = getStake(msg.sender);
            for (uint16 i = 0; i < _tokenIds.length; i++) {
                uint16 tokenId = _tokenIds[i];
                if(!tokenExistsInArray(tokenId, existingStake.tokenIds)) {
                    userToStake[msg.sender].tokenIds.push(tokenId);
                    runnersContract.transferFrom(msg.sender, address(this), _tokenIds[i]);
                }
            }
        }
    }

    function unstake(uint16[] calldata _tokenIds) public onlyStaker {
        Stake memory existingStake = getStake(msg.sender);
        uint256 newTokenIdsLength = existingStake.tokenIds.length;
        for (uint16 i = 0; i < _tokenIds.length; i++) {
            uint16 tokenId = _tokenIds[i];
            if (tokenExistsInArray(tokenId, existingStake.tokenIds)) {
                newTokenIdsLength--;
            }
        }

        uint16[] memory newTokenIds = new uint16[](newTokenIdsLength);
        uint256 newTokenIdsCounter = 0;
        for (uint16 i = 0; i < existingStake.tokenIds.length; i++) {
            uint16 tokenId = existingStake.tokenIds[i];
            if (tokenExistsInArray(tokenId, _tokenIds)) {
                runnersContract.transferFrom(address(this), msg.sender, tokenId);
            } else {
                newTokenIds[newTokenIdsCounter] = tokenId;
                newTokenIdsCounter++;
            }
        }

        if (newTokenIdsLength == 0) {
            userToStake[msg.sender].timestamp = 0;
        }
        userToStake[msg.sender].tokenIds = newTokenIds;
    }

    function getStake(address _user) public view returns(Stake memory) {
        return userToStake[_user];
    }

    function claim() public onlyStaker {
        Stake memory existingStake = getStake(msg.sender);

        bool hasStakedForLongEnough = existingStake.timestamp + stakingPeriod < block.timestamp;
        require(hasStakedForLongEnough, "You have not staked long enough!");

        require(super.balanceOf(msg.sender, diamondTrophyId) == 0, "You already have a Diamond trophy!");
        if (existingStake.tokenIds.length >= diamondEligibility) {
            return super._mint(msg.sender, diamondTrophyId, 1, "");
        }

        require(super.balanceOf(msg.sender, goldTrophyId) == 0, "You already have a Gold trophy!");
        if (existingStake.tokenIds.length >= goldEligibility) {
            return super._mint(msg.sender, goldTrophyId, 1, "");
        }

        require(super.balanceOf(msg.sender, silverTrophyId) == 0, "You already have a Silver trophy!");
        if (existingStake.tokenIds.length >= silverEligibility) {
            return super._mint(msg.sender, silverTrophyId, 1, "");
        }

        require(super.balanceOf(msg.sender, bronzeTrophyId) == 0, "You already have a Bronze trophy!");
        if (existingStake.tokenIds.length >= bronzeEligibility) {
            return super._mint(msg.sender, bronzeTrophyId, 1, "");
        }
    }
}