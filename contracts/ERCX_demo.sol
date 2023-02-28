//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./ERCX.sol";

/**
    Demo contract used for testing purposes.
 */
contract ERCX_demo is ERCX {

    constructor(string memory name, string memory symbol)
     ERCX(name, symbol)
     {         
     }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

}