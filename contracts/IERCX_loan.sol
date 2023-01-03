pragma solidity ^0.8.0;

interface IERCX_loan {
                   
    event LoanUpdate(uint256 indexed tokenId, address indexed exOwner, uint256 installmentAmount, uint256 frequency, uint256 nInstallments);

    event LoanTermination(uint256 indexed tokenId, bool expired);

    event LoanedTokenTransfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event InstallmentPayment(uint256 indexed tokenId);

    /// @dev Emitted when the address approved for rental of a token is changed or reaffirmed
    ///  The zero address indicates there is no approved address (approval removal).
    ///  When a transfer occurs, this is also emitted to indicate that the address approved for rental
    ///  for that token (if any) is reset to none.
    event LoanApproval(address indexed owner, address indexed approved, uint256 indexed tokenId);


    function startLoan(uint256 tokenId, address to, uint256 installmentAmount, uint256 frequency, uint256 nInstallments) external payable;

    function payInstallment(uint256 tokenId) external payable;

    function endLoan(uint256 tokenId) external;

    function approveLoanControl(address to, uint256 tokenId) external;

    function getLoanApproved(uint256 tokenId) external view returns (address approved);

}



