pragma solidity ^0.8.0;

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

    //function RentalInfo(tokenId) --> returns ex owner and deadline (if tokenId is rented) --> SDOPPIARE




}



