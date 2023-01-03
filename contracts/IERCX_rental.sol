pragma solidity ^0.8.0;

interface IERCX_rental {
                   
    event RentalUpdate(uint256 indexed tokenId, address indexed exOwner, uint256 installmentAmount, uint256 frequency, uint256 nInstallments);

    event InstallmentPayment(uint256 indexed tokenId);

    /// @dev Emitted when the address approved for rental of a token is changed or reaffirmed
    ///  The zero address indicates there is no approved address (approval removal).
    ///  When a transfer occurs, this is also emitted to indicate that the address approved for rental
    ///  for that token (if any) is reset to none.
    event RentalApproval(address indexed owner, address indexed approved, uint256 indexed tokenId);


    function startRental(uint256 tokenId, address to, uint256 installmentAmount, uint256 frequency, uint256 nInstallments) external;

    function payInstallment(uint256 tokenId) external;

    function endRental(uint256 tokenId) external;

    function approveRentalControl(uint256 tokenId, address to) external;

    function getRentalApproved(uint256 tokenId) external view returns (address approved);

}



