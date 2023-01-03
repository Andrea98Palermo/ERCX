pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERCX.sol";

contract ERCX is ERC721, IERCX {

    struct RentalInfo {
        address exOwner;    //Original owner of rented token
        uint256 deadline;   //Rental deadline
    }

    //Mapping from tokenId to rental info
    mapping (uint256 => RentalInfo) internal _rentals;  
    
    //Mapping from tokenId to address approved for rental
    mapping (uint256 => address) internal _rentalApprovals;


    /// @notice Requires token to be rented
    modifier onlyRentedToken(uint256 tokenId) {
        require(_isRented(tokenId), "ERCX: Token must be currently rented");
        _;
    }    


    /// @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
    constructor(string memory name_, string memory symbol_)
    ERC721(name_, symbol_)
    {}



    /// @dev See {IERCX-rent}.
    function rent(address to, uint256 tokenId, uint256 deadline) public virtual override {
        
        address approved = _rentalApprovals[tokenId];

        require(ERC721.ownerOf(tokenId) == _msgSender() || approved == _msgSender(), "ERCX: Can be called only by owner or address approved for rental");
        require(!_isRented(tokenId), "ERCX: Cannot subrent");  
        require(deadline > block.timestamp, "ERCX: Rental deadline expired yet");
        require(to != address(0), "ERCX: cannot rent to the zero address");

        RentalInfo storage info =  _rentals[tokenId];
        address exOwner = _ownerOf(tokenId);
        
        _transfer(exOwner, to, tokenId);
        _rentalApprovals[tokenId] = approved;

        info.exOwner = exOwner;      
        info.deadline = deadline;
        
        emit RentalUpdate(tokenId, exOwner, deadline);
    }

    /// @dev See {IERCX-endRental}.
    function endRental(uint256 tokenId) public virtual override onlyRentedToken(tokenId) {
        
        address exOwner = _rentals[tokenId].exOwner;
        uint256 deadline = _rentals[tokenId].deadline;
        require(deadline < block.timestamp, "ERCX: Rental not expired yet");

        address approved = _rentalApprovals[tokenId];
        delete _rentals[tokenId];
        _transfer(_ownerOf(tokenId), exOwner, tokenId);
        _rentalApprovals[tokenId] = approved;
        
        emit RentalUpdate(tokenId, address(0), _rentals[tokenId].deadline);
    }

    /// @dev See {IERCX-approveRentalControl}.
    function approveRentalControl(address to, uint256 tokenId) public virtual override {
        
        require(!_isRented(tokenId), "ERCX: Cannot approve rented token");
        address owner = ERC721.ownerOf(tokenId);
        //if (!_isRented(tokenId)) {owner = ERC721.ownerOf(tokenId);}
        //else {(owner, ) = rentalInfo(tokenId);}
        require(to != owner, "ERCX: Rental approval to current owner");
        require(_msgSender() == owner, "ERCX: approve caller is not token owner");

        _rentalApprovals[tokenId] = to;
        
        emit RentalApproval(_ownerOf(tokenId), to, tokenId);
    }

    /// @dev See {IERCX-getRentalApproved}.
    function getRentalApproved(uint256 tokenId) public view virtual override returns (address approved) {
        _requireMinted(tokenId);

        return _rentalApprovals[tokenId];
    }
    
    
    
    
    function deadlineUpdate(uint256 tokenId, uint256 deadline) public virtual onlyRentedToken(tokenId) {

        RentalInfo storage info = _rentals[tokenId];

        require(info.exOwner == _msgSender() || getRentalApproved(tokenId) == _msgSender(), "ERCX: Can be called only by renter or address approved for rental");
        require(deadline > info.deadline, "ERCX: Cannot anticipate deadline");

        info.deadline = deadline;

        emit RentalUpdate(tokenId, info.exOwner, deadline);
    }

    function rentalInfo(uint256 tokenId) public view virtual onlyRentedToken(tokenId) returns (address exOwner, uint256 deadline) {
        return (_rentals[tokenId].exOwner, _rentals[tokenId].deadline);
    }

    /**
     * @dev Check if `tokenId` is currently rented.
     *  Does not check for token existence.
     */
    function _isRented(uint256 tokenId) internal view virtual returns (bool) {
        return _rentals[tokenId].exOwner != address(0);
    }




    /// @dev See {ERC721-_beforeTokeenTransfer}.
    ///  checks if tokens are not rented and resets rental approvals before transfering 
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual override{
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        for (uint256 tokenId = firstTokenId; tokenId < firstTokenId + batchSize; tokenId++) {
            require(!_isRented(tokenId), "ERCX: Cannot trasfer rented token. If rental expired call endRental before");
            delete _rentalApprovals[tokenId];
        }
    } 

    /// @dev See {ERC721-approve}.
    /// Also requires tokenId not to be currently rented
    function approve(address to, uint256 tokenId) public virtual override {
        require(!_isRented(tokenId), "ERCX: Cannot approve rented token");
        ERC721.approve(to, tokenId);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERCX).interfaceId || super.supportsInterface(interfaceId);
    }

}


//ERC4907 permette all'owner di trasferire durante un prestito e cancella lo user

//Creare nuovo sistema di approvazione o usare quello di erc721
//Funzioni doppie + mapping private o funzioni singole + mapping internal  -->  sdoppiare quando ci sono da fare controlli che dipendono dalla chiamata esterna
//Cambiare in loanForUse
