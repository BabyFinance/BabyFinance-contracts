// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import {ERC721Enumerable, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract TestERC721 is ERC721Enumerable {
    constructor () ERC721("Test NFT", "TNFT") {}

    uint256 nextId;

    function mint() external {
        _safeMint(msg.sender, nextId++);
    }
}
