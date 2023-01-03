pragma solidity ^0.8.0;

import "./ERCX_v0.sol";

contract ERCXDemo is ERCX {

    constructor(string memory name, string memory symbol)
     ERCX(name, symbol)
     {         
     }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

}