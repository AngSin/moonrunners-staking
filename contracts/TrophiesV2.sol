// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract TrophiesV2 is Initializable, ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using Strings for uint256;
    struct Stake {
        uint256[] tokenIds;
        uint256 timestamp;
    }
    mapping(address => Stake) userToStake;
    address public runnersContract;
    uint256 public stakingPeriod;
    string baseUri;

    // trophy eligibility
    uint256 diamondEligibility;
    uint256 goldEligibility;
    uint256 silverEligibility;
    uint256 bronzeEligibility;

    // trophy ids
    uint256 diamondTrophyId;
    uint256 goldTrophyId;
    uint256 silverTrophyId;
    uint256 bronzeTrophyId;

    function setRunnersContract(address _runnersContract) public onlyOwner {
        runnersContract = _runnersContract;
    }

    function setBaseUri(string calldata _baseUri) public onlyOwner {
        baseUri = _baseUri;
    }

    function setStakingPeriod(uint256 _stakingPeriod) public onlyOwner {
        stakingPeriod = _stakingPeriod;
    }

    function initialize() initializer public {
        baseUri = "https://moonrunners.herokuapp.com/api/trophies/";
        __ERC1155_init(baseUri);
        __Ownable_init();
        __UUPSUpgradeable_init();
        runnersContract = 0x1485297e942ce64E0870EcE60179dFda34b4C625;
        stakingPeriod = 30 days;
        diamondEligibility = 25;
        goldEligibility = 10;
        silverEligibility = 5;
        bronzeEligibility = 1;
        diamondTrophyId  = 4;
        goldTrophyId = 3;
        silverTrophyId = 2;
        bronzeTrophyId = 1;
        dragonTokenIdBuffer = 20_000;
        dragonsContract = 0x6b5483b55b362697000d8774d8ea9c4429B261BB;
    }

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

        if (existingStake.tokenIds.length >= diamondEligibility) {
            if (super.balanceOf(msg.sender, diamondTrophyId) == 0) {
                return diamondTrophyId;
            } else {
                return 0;
            }
        }

        if (existingStake.tokenIds.length >= goldEligibility) {
            if (super.balanceOf(msg.sender, goldTrophyId) == 0) {
                return goldTrophyId;
            } else {
                return 0;
            }
        }

        if (existingStake.tokenIds.length >= silverEligibility) {
            if (super.balanceOf(msg.sender, silverTrophyId) == 0) {
                return silverTrophyId;
            } else {
                return 0;
            }
        }

        if (existingStake.tokenIds.length >= bronzeEligibility) {
            if (super.balanceOf(msg.sender, bronzeTrophyId) == 0) {
                return bronzeTrophyId;
            } else {
                return 0;
            }
        }

        return 0;
    }

    function claim() public onlyStaker {
        uint256 trophyId = getPossibleTrophyClaim();
        require(trophyId > 0, "No claim is possible for you!");
        super._mint(msg.sender, trophyId, 1, "");
    }

    function airdropTrophy(uint256 _trophyId, address _airdropWinner) public onlyOwner {
        super._mint(_airdropWinner, _trophyId, 1, "");
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

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

    // V2
    uint256 dragonTokenIdBuffer;
    address dragonsContract;

    function setDragonsContract(address _dragonsContract) public onlyOwner {
        dragonsContract = _dragonsContract;
    }

    function stakeDragons(uint256[] calldata _tokenIds) public {
        uint256[] memory bufferedDragonIds = new uint256[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            bufferedDragonIds[i] = _tokenIds[i] + dragonTokenIdBuffer;
        }
        if (!stakeExists(msg.sender)) {
            Stake memory newStake = Stake(bufferedDragonIds, block.timestamp);
            userToStake[msg.sender] = newStake;
            for (uint256 i = 0; i < _tokenIds.length; i++) {
                IERC721(dragonsContract).transferFrom(msg.sender, address(this), _tokenIds[i]);
            }
        } else {
            Stake memory existingStake = getStake(msg.sender);
            for (uint256 i = 0; i < bufferedDragonIds.length; i++) {
                uint256 bufferedDragonId = bufferedDragonIds[i];
                if(!tokenExistsInArray(bufferedDragonId, existingStake.tokenIds)) {
                    userToStake[msg.sender].tokenIds.push(bufferedDragonId);
                    IERC721(dragonsContract).transferFrom(msg.sender, address(this), _tokenIds[i]);
                }
            }
        }
    }

    function unstakeDragons(uint256[] calldata _tokenIds) public onlyStaker {
        uint256[] memory bufferedDragonIds = new uint256[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            bufferedDragonIds[i] = _tokenIds[i] + dragonTokenIdBuffer;
        }
        Stake memory existingStake = getStake(msg.sender);
        uint256 newTokenIdsLength = existingStake.tokenIds.length;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 bufferedDragonId = _tokenIds[i] + dragonTokenIdBuffer;
            bufferedDragonIds[i] = bufferedDragonId;
            if (tokenExistsInArray(bufferedDragonId, existingStake.tokenIds)) {
                newTokenIdsLength--;
            }
        }

        uint256[] memory newTokenIds = new uint256[](newTokenIdsLength);
        uint256 newTokenIdsCounter = 0;
        for (uint256 i = 0; i < existingStake.tokenIds.length; i++) {
            uint256 bufferedDragonId = existingStake.tokenIds[i];
            if (tokenExistsInArray(bufferedDragonId, bufferedDragonIds)) {
                IERC721(dragonsContract).transferFrom(address(this), msg.sender, bufferedDragonId - dragonTokenIdBuffer);
            } else {
                newTokenIds[newTokenIdsCounter] = bufferedDragonId;
                newTokenIdsCounter++;
            }
        }

        if (newTokenIdsLength == 0) {
            userToStake[msg.sender].timestamp = 0;
        }
        userToStake[msg.sender].tokenIds = newTokenIds;
    }
}