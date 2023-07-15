// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";

interface ITrophies {
    struct Stake {
        uint256[] tokenIds;
        uint256 timestamp;
    }

    function getStake(address _user) external returns(Stake memory);
}

interface ILoot {
    function controlledBurn(address _from, uint256 _id, uint256 _amount) external;
}

contract DragonsV2 is
Initializable,
ERC721AUpgradeable,
ERC2981Upgradeable,
DefaultOperatorFiltererUpgradeable,
OwnableUpgradeable,
UUPSUpgradeable
{
    // staking
    mapping (uint256 => uint256) stakingStarted;
    // blood burn
    mapping (uint256 => uint256) bloodToBurnAmount;
    // minting
    mapping(address => uint256) mintedPerWallet;
    uint256 public maxPerWallet;
    uint256 public maxAlMint;
    uint256 public maxSupply;
    uint256 public alMinted;
    bytes32 private root;
    uint256 public price;
    bool public isAllowListMinting;
    bool public isPublicMinting;
    bool public isBloodBurnLive;
    // externals
    string public baseUri;
    address trophiesContract;
    address lootContract;
    // libraries
    using Strings for uint256;

    function initialize(
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) initializerERC721A initializer public {
        __ERC721A_init("Dragons", "DRGN");
        __Ownable_init();
        __UUPSUpgradeable_init();
        DefaultOperatorFiltererUpgradeable.__DefaultOperatorFilterer_init();
        baseUri = "https://moonrunners-dragons.herokuapp.com/dragons/";
        trophiesContract = 0x1485297e942ce64E0870EcE60179dFda34b4C625;
        lootContract = 0xb6d460aC51B93BCa63B694f099C4A8b3B1CF73B4;
        maxPerWallet = 2;
        bloodToBurnAmount[7] = 5; // common blood
        bloodToBurnAmount[6] = 4; // rare blood
        bloodToBurnAmount[5] = 1; // epic blood
        bloodToBurnAmount[4] = 1; // legendary blood
        price = 69_000_000 gwei;
        maxAlMint = 1500;
        maxSupply = 5500;
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }


    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

    function setBloodToBurnAmount(uint256 _bloodId, uint256 _amount) public onlyOwner {
        bloodToBurnAmount[_bloodId] = _amount;
    }

    function setTrophiesContract(address _trophiesContract) public onlyOwner {
        trophiesContract = _trophiesContract;
    }

    function setLootContract(address _lootContract) public onlyOwner {
        lootContract = _lootContract;
    }

    function setRoot(bytes32 _root) public onlyOwner {
        root = _root;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

    function setIsAllowListMinting(bool _isAllowListMinting) public onlyOwner {
        isAllowListMinting = _isAllowListMinting;
    }

    function setIsBloodBurnLive(bool _isBloodBurnLive) public onlyOwner {
        isBloodBurnLive = _isBloodBurnLive;
    }

    function setBaseURI(string calldata _baseUri) public onlyOwner {
        baseUri = _baseUri;
    }

    function setMaxPerWallet(uint256 _maxPerWallet) public onlyOwner {
        maxPerWallet = _maxPerWallet;
    }

    function isStaked(uint256 _tokenId) public view returns (bool) {
        return stakingStarted[_tokenId] > 0;
    }

    function setMaxInitialMint(uint256 _maxAlMint) public onlyOwner {
        maxAlMint = _maxAlMint;
    }

    function setPublicMinting(bool _isPublicMinting, uint256 _price) public onlyOwner {
        isPublicMinting = _isPublicMinting;
        price = _price;
    }

    function toggleStaking(uint256[] calldata _tokenIds, bool _shouldStake) public {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(super.ownerOf(tokenId) == msg.sender, "You do not own this dragon!");
            if (_shouldStake) {
                require(!isStaked(tokenId), "Dragon already staked!");
                stakingStarted[tokenId] = block.timestamp;
            } else {
                require (isStaked(tokenId), "Dragon already un-staked!");
                stakingStarted[tokenId] = 0;
            }
        }
    }

    function mint(bytes32[] memory _proof) public payable {
        require(isAllowListMinting || isPublicMinting, "Mint is not live yet!");
        require (msg.value % price == 0, 'Unexpected amount of ETH sent');
        uint256 amount = msg.value / price;
        require(mintedPerWallet[msg.sender] + amount <= maxPerWallet, "You have already minted the max amount!");
        require(super.totalSupply() + amount <= maxSupply, "Max supply exceeded!");
        require(alMinted + amount <= maxAlMint, "All AL mints are completed");
        if (isAllowListMinting && !isPublicMinting) {
            require(
                ITrophies(trophiesContract).getStake(msg.sender).timestamp > 0 ||
                MerkleProof.verify(_proof, root, keccak256(bytes.concat(keccak256(abi.encode(msg.sender))))),
                "You neither have Moonrunners staked nor are in AL!"
            );
        }
        alMinted += amount;
        mintedPerWallet[msg.sender] += amount;
        super._mint(msg.sender, amount);
    }

    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        if (isStaked(_tokenId)) {
            return string(abi.encodePacked(baseUri, "staked/", _tokenId.toString()));
        }
        return string(abi.encodePacked(baseUri, _tokenId.toString()));
    }

    function _beforeTokenTransfers(
        address,
        address to,
        uint256 tokenId,
        uint256
    ) internal override virtual {
        require(to == address(0) || !isStaked(tokenId), "This dragon is staked!");
    }

    function burnBloodForDragons(uint256[] calldata _bloodIds) public {
        require(isBloodBurnLive, "Blood burning is not live!");
        require(super.totalSupply() + _bloodIds.length <= maxSupply, "Exceeding max dragons supply!");
        uint256[] memory dragonIds = new uint256[](_bloodIds.length);
        for (uint256 i = 0; i < _bloodIds.length; i++) {
            uint256 bloodId = _bloodIds[i];
            dragonIds[i] = super.totalSupply() + i;
            ILoot(lootContract).controlledBurn(msg.sender, bloodId, bloodToBurnAmount[bloodId]);
        }
        super._mint(msg.sender, _bloodIds.length);
        emit BloodBurn(_bloodIds, dragonIds);
    }

    // ---- DefaultOperatorFilterRegistry ----
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public payable override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
    public
    payable
    override
    onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // ---- ERC165 ----
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721AUpgradeable, ERC2981Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // ---- ERC2981 ----

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    function withdraw() public onlyOwner {
        (bool sent,) = payable(super.owner()).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    event BloodBurn(uint256[] bloodIds, uint256[] dragonIds);
}