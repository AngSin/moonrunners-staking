// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Trophies is Ownable {
    struct Stake {
        uint256[] tokenIds;
        uint256 timestamp;
    }
    mapping(address => Stake) userToStake;
    address public runnersContract;

    function setRunnersContract(address _runnersContract) public onlyOwner {
        runnersContract = _runnersContract;
    }

    function stakeExists(address _user) private view returns(bool) {
        return userToStake[_user].timestamp > 0;
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

    function unstake(uint256[] calldata _tokenIds) public {
        if (stakeExists(msg.sender)) {
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
            userToStake[msg.sender].tokenIds = newTokenIds;
        }
    }

    function getStake(address _user) public view returns(Stake memory) {
        return userToStake[_user];
    }
}