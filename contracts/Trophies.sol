// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Trophies is Ownable, ERC1155 {
    using Strings for uint256;
    struct Stake {
        uint256[] tokenIds;
        uint256 timestamp;
    }
    mapping(address => Stake) userToStake;
    address public runnersContract = 0x1485297e942ce64E0870EcE60179dFda34b4C625;
    uint256 public stakingPeriod = 30 days;
    string baseUri = "https://moonrunners.herokuapp.com/api/trophies/";

    // trophy eligibility
    uint256 diamondEligibility = 25;
    uint256 goldEligibility = 10;
    uint256 silverEligibility = 5;
    uint256 bronzeEligibility = 1;

    // trophy ids
    uint256 diamondTrophyId = 4;
    uint256 goldTrophyId = 3;
    uint256 silverTrophyId = 2;
    uint256 bronzeTrophyId = 1;

    function setRunnersContract(address _runnersContract) public onlyOwner {
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

    function tokenExistsInArray(uint256 tokenId, uint256[] memory tokenIds) private pure returns(bool) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    function stake(uint256[] calldata _tokenIds) public {
        if (!stakeExists(msg.sender)) {
            Stake memory newStake = Stake(_tokenIds, block.timestamp);
            userToStake[msg.sender] = newStake;
            for (uint256 i = 0; i < _tokenIds.length; i++) {
                IERC721(runnersContract).transferFrom(msg.sender, address(this), _tokenIds[i]);
            }
        } else {
            Stake memory existingStake = getStake(msg.sender);
            for (uint256 i = 0; i < _tokenIds.length; i++) {
                uint256 tokenId = _tokenIds[i];
                if(!tokenExistsInArray(tokenId, existingStake.tokenIds)) {
                    userToStake[msg.sender].tokenIds.push(tokenId);
                    IERC721(runnersContract).transferFrom(msg.sender, address(this), _tokenIds[i]);
                }
            }
        }
    }

    function unstake(uint256[] calldata _tokenIds) public onlyStaker {
        Stake memory existingStake = getStake(msg.sender);
        uint256 newTokenIdsLength = existingStake.tokenIds.length;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            if (tokenExistsInArray(tokenId, existingStake.tokenIds)) {
                newTokenIdsLength--;
            }
        }

        uint256[] memory newTokenIds = new uint256[](newTokenIdsLength);
        uint256 newTokenIdsCounter = 0;
        for (uint256 i = 0; i < existingStake.tokenIds.length; i++) {
            uint256 tokenId = existingStake.tokenIds[i];
            if (tokenExistsInArray(tokenId, _tokenIds)) {
                IERC721(runnersContract).transferFrom(address(this), msg.sender, tokenId);
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

    // also used by frontend
    function getPossibleTrophyClaim() public view returns(uint256) {
        if (!stakeExists(msg.sender)) return 0;
        Stake memory existingStake = getStake(msg.sender);

        bool hasStakedForLongEnough = existingStake.timestamp + stakingPeriod < block.timestamp;
        if (!hasStakedForLongEnough) {
            return 0;
        }

        if (super.balanceOf(msg.sender, diamondTrophyId) == 0 && existingStake.tokenIds.length >= diamondEligibility) {
            return diamondTrophyId;
        }

        if (
            super.balanceOf(msg.sender, diamondTrophyId) == 0 &&
            super.balanceOf(msg.sender, goldTrophyId) == 0 &&
            existingStake.tokenIds.length >= goldEligibility
        ) {
            return goldTrophyId;
        }

        if (
            super.balanceOf(msg.sender, diamondTrophyId) == 0 &&
            super.balanceOf(msg.sender, goldTrophyId) == 0 &&
            super.balanceOf(msg.sender, silverTrophyId) == 0 &&
            existingStake.tokenIds.length >= silverEligibility
        ) {
            return silverTrophyId;
        }

        if (
            super.balanceOf(msg.sender, diamondTrophyId) == 0 &&
            super.balanceOf(msg.sender, goldTrophyId) == 0 &&
            super.balanceOf(msg.sender, silverTrophyId) == 0 &&
            super.balanceOf(msg.sender, bronzeTrophyId) == 0 &&
            existingStake.tokenIds.length >= bronzeEligibility
        ) {
            return bronzeTrophyId;
        }
        return 0;
    }

    function claim() public onlyStaker {
        uint256 trophyId = getPossibleTrophyClaim();
        require(trophyId > 0, "No claim is possible for you!");
        super._mint(msg.sender, trophyId, 1, "");
    }

    function _beforeTokenTransfer(
        address,
        address from,
        address to,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) internal override virtual {
        require(from == address(0) || to == address(0), "Trophies cannot be transferred");
    }

    event Soulbound(uint256 indexed id, bool bounded);

    function _afterTokenTransfer(
        address,
        address from,
        address,
        uint256[] memory ids,
        uint256[] memory,
        bytes memory
    ) internal override virtual {
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                emit Soulbound(id, true);
            }
        }
    }

    function isSoulbound(uint256) external pure returns (bool) {
        return true;
    }

    function uri(uint256 _tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseUri, _tokenId.toString()));
    }
}