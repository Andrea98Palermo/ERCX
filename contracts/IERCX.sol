//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/**
    A standard for ERC721 NFTs rental and layaway
 */
interface IERCX {

    struct RentalInfo {
        address provider;    //Original owner of rented token
        uint256 deadline;   //Rental deadline
    }

    struct TokenRentals {
        RentalInfo[] rentals;        //List containing token's rental and subrentals details
        address providerApproved;    //Address approved by last rental provider for layaway transfer
        address receiverApproved;   //Address approved by last rental receiver for layawayed token transfer
        bool allowSubrental;        //Specifies if token can be subrented
        bool allowTransfers;        //Specifies if token can be transfered during rental
    }

    struct LayawayInfo {
        address provider;    //Original owner of layawayed token
        uint256 deadline;   //Layaway deadline
        address providerApproved;    //Address approved by layaway provider for layaway transfer
        address receiverApproved;   //Address approved by layaway receiver for layawayed token transfer
    }
                   
    /** @dev Emitted on rental start and deadline update.
     */
    event RentalUpdate(uint256 indexed tokenId, address indexed provider, address indexed receiver, uint256 deadline);

    /** @dev Emitted on rental termination.
     */
    event RentalTermination(uint256 indexed tokenId, address indexed provider, address indexed receiver);
    
    /** @dev Emitted when the address approved for rental of a token is changed or reaffirmed
    The zero address indicates there is no approved address (approval removal).
    When a transfer occurs, this is also emitted to indicate that the address approved for rental
    for that token (if any) is reset to none.*/
    event RentalApproval(address indexed approver, address indexed approved, uint256 indexed tokenId);

    /** @dev Emitted when the ownership of a rental is transfered.
     */
    event RentalOwnershipTransfer(uint256 indexed tokenId, address indexed from, address indexed to);

    /** @dev Emitted when a rented token is transfered.
     */
    event RentedTokenTransfer(uint256 indexed tokenId, address indexed from, address indexed to);

    /** @dev Emitted when a rental provider cedes the rented token to the receiver
     */
    event RentedTokenRedemption(uint256 indexed tokenId, address indexed from, address indexed to);

    /** @dev Emitted when the address approved for rented token transfer is changed or reaffirmed.
    The zero address indicates there is no approved address (approval removal).*/
    event RentedTokenTransferApproval(address indexed approver, address indexed approved, uint256 indexed tokenId);
    
    /** @dev Emitted when the address approved for rental ownership transfer is changed or reaffirmed.
    The zero address indicates there is no approved address (approval removal).*/
    event RentalOwnershipTransferApproval(address indexed approver, address indexed approved, uint256 indexed tokenId);

    
    
    /** @dev Emitted on layaway start and update.
     */
    event LayawayUpdate(uint256 indexed tokenId, address indexed provider, address indexed receiver, uint256 deadline);

    /** @dev Emitted on layaway termination
     */
    event LayawayTermination(uint256 indexed tokenId, address indexed provider, address indexed receiver, bool paymentCompleted);

    /** @dev Emitted when a layaway ownership is transfered.
     */
    event LayawayOwnershipTransfer(uint256 indexed tokenId, address indexed from, address indexed to);

    /** @dev Emitted when a layawayed token is transfered.
     */
    event LayawayedTokenTransfer(uint256 indexed tokenId, address indexed from, address indexed to); 

    /** @dev Emitted when the address approved for layaway of a token is changed or reaffirmed.
    The zero address indicates there is no approved address (approval removal).
    When a transfer occurs, this is also emitted to indicate that the address approved for rental
    for that token (if any) is reset to none.*/
    event LayawayApproval(address indexed approver, address indexed approved, uint256 indexed tokenId);

     /** @dev Emitted when the address approved for layawayed token transfer is changed or reaffirmed.
    The zero address indicates there is no approved address (approval removal).*/
    event LayawayedTokenTransferApproval(address indexed approver, address indexed approved, uint256 indexed tokenId);
    
    /** @dev Emitted when the address approved for layaway ownership transfer is changed or reaffirmed.
    The zero address indicates there is no approved address (approval removal).*/
    event LayawayOwnershipTransferApproval(address indexed approver, address indexed approved, uint256 indexed tokenId);





    /**  @notice Starts token rental to an address until deadline
    @dev Throws if `tokenId` is not a valid NFT.
    Can be called only by owner or address approved for rental.
    @param to  The receiver of the token.
    @param tokenId  Token to be rented.
    @param deadline  UNIX timestamp until which the rental is valid (layawayed token cannot be claimed back). */
    function startRental(uint256 tokenId, address to, uint256 deadline, bool allowSubrental, bool allowTransfers) external;

    /** @notice Starts token subrental rental to an address until deadline
    @dev Throws if `tokenId` is not a valid NFT.
    Can be called only by owner or address approved for rental.
    @param to  The receiver of the token.
    @param tokenId  Token to be subrented.
    @param deadline  UNIX timestamp until which the subrental is valid (rented token cannot be claimed back). */
    function startSubrental(uint256 tokenId, address to, uint256 deadline) external;

    /**  @notice Updates rental deadline
    @dev Throws if `tokenId` is not a valid NFT.
    Can be called only by owner or address approved for rental.
    @param tokenId  Token to be layawayed.
    @param deadline  UNIX timestamp until which the layaway is valid (layawayed token cannot be claimed back). 
    @param provider  Provider of rental to be updated, needed to identify the correct rental record in case of subrental*/
    function updateRental(uint256 tokenId, uint256 deadline, address provider) external;
    
    /**  @notice Returns rented token to original owner
    @dev Can be called by any address but throws if deadline is not expired yet
    @param tokenId  Token to be returned.
    @param provider  Provider of rental to be terminated, needed to identify the correct rental record in case of subrental*/
    function endRental(uint256 tokenId, address provider) external;

    /**  @notice Transfers a token during rental.
     @param tokenId  Rented token.
     @param to  Receiver of the token */
    function transferRentedToken(address to, uint256 tokenId) external;

    /**  @notice Transfers rental ownership to a new provider.
     @param tokenId  Rented token.
     @param to  Receiver of rental ownership */
    function transferRentalOwnership(address to, uint256 tokenId) external;

    /**  @notice Definitively transfers rented token to rental receiver.
     @dev Can be called only by rental provider or address approved for rental
     @param tokenId  Rented token. */
    function redeemRentedToken(uint256 tokenId) external;

    /** @notice Change or reaffirm the address approved for rental for a token.
    @dev The zero address indicates there is no approved address (approval removal).
    Can be called only by current token owner; throws if 'tokenId' is currently layawayed and if 'to' is the current token owner
    @param to  Approved address.
    @param tokenId  Token to be approved. */
    function approveRentalControl(uint256 tokenId, address to) external;

    /** @notice Change or reaffirm the address approved for rental ownership transfer or rented token transfer.
    @dev The zero address indicates there is no approved address (approval removal).
    Can be called only by rental receiver or provider; throws if 'tokenId' is not currently rented
    @param to  Approved address.
    @param tokenId  Token to be approved. */
    function approveRentalTransfer(address to, uint256 tokenId) external;

    /**  @notice Get the address approved for rental for a token by specified 'approver'
    @dev Throws if `tokenId` is not a valid NFT.
    The zero address indicates there is no approved address.
    @param tokenId  The NFT to find the approved address for
    @param approver  Address who approved the rental, needed to identify the correct rental record in case of subrental
    @return approved  The approved address for this NFT, or the zero address if there is none */
    function getRentalApproved(uint256 tokenId, address approver) external view returns (address approved);

    /**  @notice Retrieves deadline of specified rental
    @dev Throws if 'tokenId' is not a valid NFT
    @param tokenId  Rented token.
    @param provider  Provider of rental, needed to identify the correct rental record in case of subrental*/
    function getRentalDeadline(uint256 tokenId, address provider) external view returns (uint256 deadline);

    /**  @notice Checks if subrental is allowed for a particular token
    @param tokenId  Token to be checked */
    function isSubrentalAllowed(uint256 tokenId) external view returns (bool subrentalAllowed);

    /**  @notice Checks if rental transfer is allowed for a particular token
    @param tokenId  Token to be checked */
    function isRentalTransferAllowed(uint256 tokenId) external view returns (bool transferAllowed);

    /**  @notice Retrieves address approved by rental provider for rental ownership transfer
    @param tokenId  Rented token.*/
    function getRentalOwnershipTransferApproved(uint256 tokenId) external view returns (address approved);    

    /**  @notice Retrieves address approved by rental receiver for rented token transfer
    @param tokenId  Rented token.*/
    function getRentedTokenTransferApproved(uint256 tokenId) external view returns (address approved);

    /**  @notice Retrieves details of all current rentals and subrentals relative to 'tokenId'
    @param tokenId  Rented token.*/
    function getRentals(uint256 tokenId) external view returns (RentalInfo[] memory rentals);



    /** @notice Starts token layaway to an address until deadline
    @notice A layaway must be managed by an external approved address
    @dev Throws if `tokenId` is not a valid NFT.
    Can be called only by address approved for layaway.
    @param to  The receiver of the token.
    @param tokenId  Token to be layawayed.
    @param deadline  UNIX timestamp until which the layaway has been paid and is valid (layawayed token cannot be claimed back). */
    function startLayaway(uint256 tokenId, address to, uint256 deadline) external;

    /** @notice Updates layaway deadline. This should be called by approved address on new installment payment by layaway receiver.
    @dev Throws if `tokenId` is not a valid NFT.
    Can be called only by address approved for rental.
    @param tokenId  Token to be layawayed.
    @param deadline  UNIX timestamp until which the layaway has been paid and is valid (layawayed token cannot be claimed back). */
    function updateLayaway(uint256 tokenId, uint256 deadline) external;

    /**  @notice Terminates layaway returning token to Layaway provider or receiver, depending on layaway payment status
    @notice if 'paymentCompleted' is true, layaway receiver has finished paying installments and can keep the token;
     otherwise token will be foreclosed and returned to layaway provider
    @dev Can only be called by address approved for layaway; throws if deadline is not expired yet.
    Approved address must specify if the layaway payment was completed by the receiver
    @param tokenId  Token to be returned.
    @param paymentCompleted  Specifies whether the layaway payment has been completed */
    function endLayaway(uint256 tokenId, bool paymentCompleted) external;

    /**  @notice Transfers a token during layaway.
    @param tokenId  Layawayed token.
    @param to  Receiver of the token */
    function transferLayawayedToken(address to, uint256 tokenId) external;

    /**  @notice Transfers layaway ownership to a new provider.
    @param tokenId  Layawayed token.
    @param to  Receiver of the layaway ownerhip */
    function transferLayawayOwnership(address to, uint256 tokenId) external;

    /** @notice Change or reaffirm the address approved for layaway for a token.
    @dev The zero address indicates there is no approved address (approval removal).
    Can be called only by current token owner; throws if 'tokenId' is currently layawayed or rented and if 'to' is the current token owner
    @param to  Approved address.
    @param tokenId  Token to be approved. */
    function approveLayawayControl(address to, uint256 tokenId) external;

    /** @notice Change or reaffirm the address approved for layaway transfer for a token.
    @dev The zero address indicates there is no approved address (approval removal).
    Can be called only by layaway receiver or provider; throws if 'tokenId' is not currently layawayed
    @param to  Approved address.
    @param tokenId  Token to be approved. */
    function approveLayawayTransfer(address to, uint256 tokenId) external;

    /**  @notice Get the address approved for layaway for a token
    @dev Throws if `tokenId` is not a valid NFT.
    The zero address indicates there is no approved address.
    @param tokenId  The NFT to find the approved address for
    @return approved  The approved address for this NFT, or the zero address if there is none */
    function getLayawayApproved(uint256 tokenId) external view returns (address approved);

    /**  @notice Retrieves provider of specified Layaway
    @dev Throws if 'tokenId' is not a valid NFT
    @param tokenId  Layawayed token.*/
    function getLayawayProvider(uint256 tokenId) external view returns (address provider);

    /**  @notice Retrieves deadline of specified layaway
    @dev Throws if 'tokenId' is not a valid NFT
    @param tokenId  Layawayed token.*/
    function getLayawayDeadline(uint256 tokenId) external view returns (uint256 deadline);

    /**  @notice Retrieves address approved by layaway provider for layaway ownership transfer
    @param tokenId  Layawayed token.*/
    function getLayawayOwnershipTransferApproved(uint256 tokenId) external view returns (address approved);    

    /**  @notice Retrieves address approved by layaway receiver for layawayed token transfer
    @param tokenId  Layawayed token.*/
    function getLayawayedTokenTransferApproved(uint256 tokenId) external view returns (address approved);

}
