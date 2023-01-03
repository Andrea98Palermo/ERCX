pragma solidity ^0.8.0;

import "./ERCX_loan.sol";

contract ERCX_loan_demo is ERCX_loan {

    constructor(string memory name, string memory symbol)
     ERCX_loan(name, symbol)
     {         
     }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

}