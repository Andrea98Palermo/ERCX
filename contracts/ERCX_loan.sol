pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERCX_loan.sol";

contract ERCX_loan is ERC721, IERCX_loan {
    
    struct LoanInfo {
        address exOwner;    //Original token owner 
        uint256 installmentAmount;   //Amount due per installment
        uint256 frequency;  //Installments frequency
        uint256 paidInstallments;  //Number of installments paid yet
        uint256 totalInstallments;   //Total number of installments for the loan
        uint256 loanStart;
    }

    //Mapping from tokenId to rental info
    mapping (uint256 => LoanInfo) internal _loans;
    
    //Mapping from tokenId to address approved for rental
    mapping (uint256 => address) internal _loanApprovals;



    /// @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
    constructor(string memory name_, string memory symbol_)
    ERC721(name_, symbol_)
    {}



    function startLoan(uint256 tokenId, address to, uint256 installmentAmount, uint256 frequency, uint256 nInstallments) public virtual payable override {
        address approved = _loanApprovals[tokenId];
        address exOwner = _ownerOf(tokenId);

        require(approved == _msgSender() || exOwner == _msgSender(), "ERCX: Can be called only by owner or address approved for loan");
        require(!_isLoaned(tokenId), "ERCX: Cannot subloan");
        require(to != address(0), "ERCX: cannot loan to the zero address");

        LoanInfo storage info =  _loans[tokenId];
        
        _transfer(exOwner, to, tokenId);
        _loanApprovals[tokenId] = approved;

        info.exOwner = exOwner;
        info.installmentAmount = installmentAmount;
        info.frequency = frequency;
        info.totalInstallments = nInstallments;
        info.loanStart = block.timestamp;
        
        if (approved == _msgSender()) {
            require(msg.value >= installmentAmount, "ERCX: First installment must be paid to start the loan");
            payable(exOwner).transfer(msg.value);
            info.paidInstallments = 1;
        }
        else {
            info.paidInstallments = 0;      //useless
        }   
        
        emit LoanUpdate(tokenId, exOwner, installmentAmount, frequency, nInstallments);
    }

    function payInstallment(uint256 tokenId) public virtual payable override {
        require(_isLoaned(tokenId), "ERCX: Token is not loaned");
        
        LoanInfo storage info =  _loans[tokenId];

        require(info.paidInstallments < info.totalInstallments, "ERCX: All installments paid yet");

        require(msg.value >= info.installmentAmount, "ERCX: Sent value must be greater or equal to installment value");
        payable(info.exOwner).transfer(msg.value);

        info.paidInstallments += 1;

        emit InstallmentPayment(tokenId);
    }

    function endLoan(uint256 tokenId) public virtual override {
        LoanInfo storage info =  _loans[tokenId];
        bool installmentExpired = block.timestamp > info.loanStart + info.frequency * info.paidInstallments;
        require(info.totalInstallments == info.paidInstallments || installmentExpired, "ERCX: loan not yet terminated");
        
        if (installmentExpired) {
            address approved = _loanApprovals[tokenId];
            _transfer(_ownerOf(tokenId), info.exOwner, tokenId);
            _loanApprovals[tokenId] = approved;
            emit LoanTermination(tokenId, true);
        }
        else {
            emit LoanTermination(tokenId, false);
        }

        delete _loans[tokenId];

    }

    function approveLoanControl(address to, uint256 tokenId) public virtual override {
        
        require(!_isLoaned(tokenId), "ERCX: Cannot approve loaned token");
        
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERCX: Rental approval to current owner");
        require(_msgSender() == owner, "ERCX: approve caller is not token owner");

        _loanApprovals[tokenId] = to;
        
        emit LoanApproval(_ownerOf(tokenId), to, tokenId);
    }

    function getLoanApproved(uint256 tokenId) public view virtual override returns (address approved) {
        _requireMinted(tokenId);

        return _loanApprovals[tokenId];
    }



    /**
     * @dev Check if `tokenId` is currently rented.
     *  Does not check for token existence.
     */
    function _isLoaned(uint256 tokenId) internal view virtual returns (bool) {
        return _loans[tokenId].exOwner != address(0);
    }





    /// @dev See {ERC721-_beforeTokeenTransfer}.
    ///  checks if tokens are not rented and resets rental approvals before transfering 
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual override{
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        for (uint256 tokenId = firstTokenId; tokenId < firstTokenId + batchSize; tokenId++) {
            delete _loanApprovals[tokenId];
        }
    } 

    
    function transferLoanedToken(address to, uint256 tokenId) public virtual {
        address exOwner = _loans[tokenId].exOwner;
        require(_msgSender() == exOwner || _msgSender() == ERC721.getApproved(tokenId), "ERCX: only loaner or approved address can transfer during loan");
        _loans[tokenId].exOwner = to;
        ERC721._approve(address(0), tokenId);
        delete _loanApprovals[tokenId];
        emit LoanedTokenTransfer(exOwner, to, tokenId);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(!_isLoaned(tokenId), "ERCX: use transferLoanedToken function to transfer a loaned token");
        ERC721.transferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(!_isLoaned(tokenId), "ERCX: use transferLoanedToken function to transfer a loaned token");
        ERC721.safeTransferFrom(from, to, tokenId);
    }

    /// @dev See {ERC721-approve}.
    /// Also requires tokenId not to be currently rented
    function approve(address to, uint256 tokenId) public virtual override {
        require(!_isLoaned(tokenId), "ERCX: Cannot approve loaned token");
        ERC721.approve(to, tokenId);
    }
    

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERCX_loan).interfaceId || super.supportsInterface(interfaceId);
    }


}


