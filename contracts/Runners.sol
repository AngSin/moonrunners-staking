// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Runners is ERC721 {
    constructor() ERC721("RUN","RUN") {
        for (uint256 i = 1; i <101; i++) {
            super._safeMint(msg.sender, i);
        }
    }
}