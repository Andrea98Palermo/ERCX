pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IERCX {

    /// @dev Emitted on rental starting, deadline updating and rental termination.
    /// The zero address for exOwner indicates rental terminantion.
    /// The receiver of the rental can be obtained calling ERC721.ownerOf(tokenId) before rental is terminated                        
    event RentalUpdate(uint256 indexed tokenId, address indexed exOwner, uint256 deadline);

    /// @dev Emitted when the address approved for rental of a token is changed or reaffirmed
    ///  The zero address indicates there is no approved address (approval removal).
    ///  When a transfer occurs, this is also emitted to indicate that the address approved for rental
    ///  for that token (if any) is reset to none.
    event RentalApproval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    //OR

    //emitted on new rentals and deadline updates
    //event RentalUpdate(uint256 indexed tokenId, address indexed from, address indexed to, uint256 deadline);
    // +
    //emitted on rental terminantion
    //event RentalTerimination(uint256 tokenId);



    /// @notice Start token rental to an address until deadline
    /// @dev Throws if `tokenId` is not valid NFT.
    ///  Can be called only by owner or address approved for rental.
    /// @param to  The receiver of the token.
    /// @param tokenId  Token to be rented.
    /// @param deadline  UNIX timestamp until which the rental is valid (rented token cannot be claimed back). 
    function rent(address to, uint256 tokenId, uint256 deadline) external;

    /// @notice Returns rented token to original owner
    /// @dev Can be called by any address but throws if deadline is not expired yet
    /// @param tokenId  Token to be returned.
    function endRental(uint256 tokenId) external;       

    /// @notice Change or reaffirm the approved address for a token.
    /// @dev The zero address indicates there is no approved address (approval removal).
    ///  Can be called only by current token owner.
    /// @param to  Approved address.
    /// @param tokenId  Token to be approved.
    function approveRentalControl(address to, uint256 tokenId) external;    //may also use normal ERC721 approvals

    /// @notice Get the approved address for a token
    /// @dev Throws if `tokenId` is not a valid NFT.
    ///  The zero address indicates there is no approved address.
    /// @param tokenId  The NFT to find the approved address for
    /// @return approved  The approved address for this NFT, or the zero address if there is none
    function getRentalApproved(uint256 tokenId) external view returns (address approved);

    //function deadlineUpdate?

    //function RentalInfo(tokenId) --> returns ex owner and deadline (if tokenId is rented) (maybe also current owner?)


}

contract ERCX is ERC721, IERCX {

    struct RentalInfo {
        address exOwner;    //Original owner of rented token
        uint256 deadline;   //Rental deadline
    }

    //Mapping from tokenId to rental info
    mapping (uint256 => RentalInfo) private _rentals;  
    
    //Mapping from tokenId to address approved for rental
    mapping (uint256 => address) private _rentalApprovals;


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
        
        require(ERC721.ownerOf(tokenId) == _msgSender() || getRentalApproved(tokenId) == _msgSender(), "ERCX: Can be called only by owner or address approved for rental");
        require(!_isRented(tokenId), "ERCX: Cannot subrent");  
        require(deadline > block.timestamp, "ERCX: Rental deadline expired yet");

        _rent(to, tokenId, deadline);
    }

    /// @dev See {IERCX-endRental}.
    function endRental(uint256 tokenId) public virtual override onlyRentedToken(tokenId) {
        
        //require(_isRented(tokenId), "ERCX: Token is not currently rented");
        require(_rentals[tokenId].deadline > block.timestamp, "ERCX: Rental not expired yet");

        _endRental(tokenId);
    }

    /// @dev See {IERCX-approveRentalControl}.
    function approveRentalControl(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERCX: Rental approval to current owner");
        require(_msgSender() == owner, "ERCX: approve caller is not token owner");

        _approveRentalControl(to, tokenId);
    }

    /// @dev See {IERCX-getRentalApproved}.
    function getRentalApproved(uint256 tokenId) public view virtual override returns (address approved) {
        _requireMinted(tokenId);

        return _rentalApprovals[tokenId];
    }
    
    function deadlineUpdate(uint256 tokenId, uint256 deadline) public virtual onlyRentedToken(tokenId) {

        //require(_isRented(tokenId), "ERCX: Token is not currently rented");
        require(_rentals[tokenId].exOwner == _msgSender() || getRentalApproved(tokenId) == _msgSender(), "ERCX: Can be called only by renter or address approved for rental");
        require(deadline > _rentals[tokenId].deadline, "ERCX: Cannot anticipate deadline");

        _deadlineUpdate(tokenId, deadline);
    }

    function rentalInfo(uint256 tokenId) public view virtual onlyRentedToken(tokenId) returns (address exOwner, uint256 deadline) {
        //require(_isRented(tokenId), "ERCX: token is not rented");

        return (_rentals[tokenId].exOwner, _rentals[tokenId].deadline);
    }



    /**
     * @dev Rent `tokenId` to `to` until `deadline`.
     *  As opposed to {rent}, this imposes no restrictions on msg.sender and deadline and doesn't check if token is rented yet
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     *
     * Emits a {RentalUpdate} event.
     */
    function _rent(address to, uint256 tokenId, uint256 deadline) internal virtual {
        require(to != address(0), "ERCX: cannot rent to the zero address");

        RentalInfo storage info =  _rentals[tokenId];
        address exOwner = _ownerOf(tokenId); 
        info.exOwner = exOwner;      
        info.deadline = deadline;

        _transfer(exOwner, to, tokenId);
        
        emit RentalUpdate(tokenId, exOwner, deadline);
    }

    /**
     * @dev Approve rental control to `to` for `tokenId`
     *  As opposed to {approveRentalControl}, this imposes no restrictions on msg.sender and approved address
     *
     * Emits a {RentalApproval} event.
     */
    function _approveRentalControl(address to, uint256 tokenId) internal virtual {
        _rentalApprovals[tokenId] = to;
        
        emit RentalApproval(_ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Return rented `tokenId` to original owner
     *  As opposed to {endRental}, this imposes no restrictions on deadline
     *
     * Emits a {RentalUpdate} event.
     */
    function _endRental(uint256 tokenId) internal virtual {
        _transfer(_ownerOf(tokenId), _rentals[tokenId].exOwner, tokenId);
        
        emit RentalUpdate(tokenId, address(0x0), _rentals[tokenId].deadline);
       
        delete _rentals[tokenId];
    }

    /**
     * @dev Update deadline of an existing rental
     *  As opposed to {deadlineUpdate}, this imposes no restrictions on msg.sender and deadline
     *
     * Emits a {RentalUpdate} event.
     */
    function _deadlineUpdate(uint256 tokenId, uint256 deadline) internal virtual {
        RentalInfo storage info = _rentals[tokenId];
        info.deadline = deadline;

        emit RentalUpdate(tokenId, info.exOwner, deadline);
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

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERCX).interfaceId || super.supportsInterface(interfaceId);
    }

}


//ERC4907 permette all'owner di trasferire durante un prestito e cancella lo user

//Creare nuovo sistema di approvazione (in caso implementando anche gli operators) o usare quello di erc721
//Inserire isRented nell'interfaccia e renderla public?
//Inserire deadlineUpdate nell'interfaccia?
//Inserire rentalInfo nell'intefaccia? Aggiungere ex owner come valore di ritorno

//Eventi --> singolo o doppio? sostituire from e to con exOwner?
//Mapping private o internal
//ERC721.ownerOf o _ownerOf

