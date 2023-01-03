/*
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERCX_rental.sol";

contract ERCX is ERC721, IERCX_rental {

    struct RentalInfo {
        address exOwner;    //Original owner of rented token
        uint256 installmentAmount;   //Amount due per installment
        uint256 frequency;  //Installments frequency
        uint256 nInstallments;  //Number of installments to be paid
    }

    //Mapping from tokenId to rental info
    mapping (uint256 => RentalInfo) internal _rentals;
    
    //Mapping from tokenId to address approved for rental
    mapping (uint256 => address) internal _rentalApprovals;



    /// @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
    constructor(string memory name_, string memory symbol_)
    ERC721(name_, symbol_)
    {}



    function startRental(uint256 tokenId, address to, uint256 installmentAmount, uint256 frequency, uint256 nInstallments) public virtual override {
        address approved = _rentalApprovals[tokenId];

        require(ERC721.ownerOf(tokenId) == _msgSender() || approved == _msgSender(), "ERCX: Can be called only by owner or address approved for rental");
    }

}*/


//ERC4907 permette all'owner di trasferire durante un prestito e cancella lo user

//Creare nuovo sistema di approvazione o usare quello di erc721
//Funzioni doppie + mapping private o funzioni singole + mapping internal  -->  sdoppiare quando ci sono da fare controlli che dipendono dalla chiamata esterna
//Cambiare in loanForUse
