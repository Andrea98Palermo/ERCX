//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERCX.sol";
import "hardhat/console.sol";

contract ERCX is ERC721, IERCX { 


    //Mapping from tokenId to layaway details
    mapping (uint256 => LayawayInfo) internal _layaways;
    
    //Mapping from tokenId to address approved for layaway
    mapping (uint256 => address) internal _layawayApprovals;

    //Mapping from tokenId to list of rental and subrental details
    mapping (uint256 => TokenRentals) internal _rentals;

    //Mapping used to associate rental and subrental providers to their index in the corresponding list in _rentals mapping
    mapping (uint256 => mapping(address => uint256)) internal _subrentLevels;
    
    //Mapping from tokenId to address approved for rental
    mapping (uint256 => mapping(address => address)) internal _rentalApprovals;



    /// @notice Requires token to be layawayed
    modifier onlyLayawayedToken(uint256 tokenId) {
        require(isLayawayed(tokenId), "ERCX: Token must be currently layawayed");
        _;
    }

    /// @notice Requires token to be rented
    modifier onlyRentedToken(uint256 tokenId) {
        require(isRented(tokenId), "ERCX: Token must be currently rented");
        _;
    }  


    /// @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
    constructor(string memory name_, string memory symbol_)
    ERC721(name_, symbol_)
    {}

    /// @dev See {IERCX-startLayaway}.
    function startLayaway(uint256 tokenId, address to, uint256 deadline) public virtual override {  
        address owner = _ownerOf(tokenId);
        address layawayApproved = _layawayApprovals[tokenId];
        
        require(layawayApproved == _msgSender(), "ERCX: Can be called only by address approved for layaway");
        require(!isLayawayed(tokenId) && !isRented(tokenId), "ERCX: Cannot start layaway on a layawayed or rented token");
        require(deadline > block.timestamp, "ERCX: layaway deadline expired yet");
        require(to != address(0), "ERCX: cannot layaway to the zero address");
        
        _transfer(owner, to, tokenId);
        _layawayApprovals[tokenId] = layawayApproved;

        LayawayInfo storage info =  _layaways[tokenId];
        info.provider = owner;      
        info.deadline = deadline;
        
        emit LayawayUpdate(tokenId, owner, to, deadline);
    }

    /// @dev See {IERCX-startRental}.
    function startRental(uint256 tokenId, address to, uint256 deadline, bool allowSubrental, bool allowTransfers) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        address approved = _rentalApprovals[tokenId][owner];

        require(owner == _msgSender() || approved == _msgSender(), "ERCX: Can be called only by owner or address approved for rental");
        require(owner != to, "Cannot self-rent");
        require(!isLayawayed(tokenId), "ERCX: Cannot start rental on a layawayed token");
        require(!isRented(tokenId), "ERCX: Use startSubrental function to subrent");
        require(deadline > block.timestamp, "ERCX: Rental deadline expired yet");
        require(to != address(0), "ERCX: cannot rent to the zero address"); 

        _transfer(owner, to, tokenId);
        _rentalApprovals[tokenId][owner] = approved;

        RentalInfo memory rental;
        rental.provider = owner;      
        rental.deadline = deadline;

        RentalInfo[] storage rentals = _rentals[tokenId].rentals;
        rentals.push(rental);
        
        _subrentLevels[tokenId][owner] = 1;
        _rentals[tokenId].allowSubrental = allowSubrental;
        _rentals[tokenId].allowTransfers = allowTransfers;
        
        emit RentalUpdate(tokenId, owner, to, deadline);
    }

    /// @dev See {IERCX-startSubental}.
    function startSubrental(uint256 tokenId, address to, uint256 deadline) public virtual override onlyRentedToken(tokenId) {
        address owner = ERC721.ownerOf(tokenId);
        address approved = _rentalApprovals[tokenId][owner];

        require(owner == _msgSender() || approved == _msgSender(), "ERCX: Can be called only by owner or address approved for rental");
        require(owner != to, "Cannot self-rent");
        require(!isLayawayed(tokenId), "ERCX: Cannot start rental on a layawayed token");
        require(deadline > block.timestamp, "ERCX: Rental deadline expired yet");
        require(to != address(0), "ERCX: cannot rent to the zero address"); 
        require(_rentals[tokenId].allowSubrental, "ERCX: Subrental is not allowed on this token");
        require(_subrentLevels[tokenId][to] == 0, "ERCX: cannot rent token to an account that previously rented it");
        require(deadline <= _rentals[tokenId].rentals[_rentals[tokenId].rentals.length - 1].deadline, "ERCX: Cannot subrent for a period longer than your rental period");
        
        _transfer(owner, to, tokenId);
        _rentalApprovals[tokenId][owner] = approved;

        RentalInfo memory rental;
        rental.provider = owner;      
        rental.deadline = deadline;

        RentalInfo[] storage rentals = _rentals[tokenId].rentals;
        rentals.push(rental);
        _subrentLevels[tokenId][owner] = rentals.length;
        
        emit RentalUpdate(tokenId, owner, to, deadline);
    }

    /// @dev See {IERCX-updateLayaway}.
    function updateLayaway(uint256 tokenId, uint256 deadline) public virtual override onlyLayawayedToken(tokenId) {
        LayawayInfo storage info = _layaways[tokenId];

        require(_layawayApprovals[tokenId] == _msgSender(), "ERCX: Can be called only by address approved for layaway");
        require(deadline > info.deadline, "ERCX: Cannot anticipate deadline");

        info.deadline = deadline;

        emit LayawayUpdate(tokenId, info.provider, _ownerOf(tokenId), deadline);
    }

    /// @dev See {IERCX-updateRental}.
    function updateRental(uint256 tokenId, uint256 deadline, address provider) public virtual override onlyRentedToken(tokenId) {
        
        uint256 subrentLevel = _subrentLevels[tokenId][provider];
        require(subrentLevel != 0, "ERCX: Specified rental does not exist");      
        if(subrentLevel >= 2) {
            require(deadline <= _rentals[tokenId].rentals[subrentLevel - 2].deadline, "ERCX: Cannot set subrent deadline after your rental deadline");
        }
        
        RentalInfo storage info = _rentals[tokenId].rentals[subrentLevel - 1];
        require(info.provider == _msgSender() || _rentalApprovals[tokenId][info.provider] == _msgSender(), "ERCX: Can be called only by renter or address approved for rental");
        require(deadline > info.deadline, "ERCX: Cannot anticipate deadline");

        info.deadline = deadline;

        emit RentalUpdate(tokenId, info.provider, _ownerOf(tokenId), deadline);
    }

    /// @dev See {IERCX-endLayaway}.
    function endLayaway(uint256 tokenId, bool paymentCompleted) public virtual override {
        require(_msgSender() == _layawayApprovals[tokenId], "ERCX: layaway can be terminated only by approved address");
        
        LayawayInfo memory info =  _layaways[tokenId];
        
        delete _layawayApprovals[tokenId];
        delete _layaways[tokenId];

        address currentOwner = _ownerOf(tokenId);
        if (!paymentCompleted) {
            require(info.deadline < block.timestamp, "ERCX: layaway not expired yet");
            _transfer(_ownerOf(tokenId), info.provider, tokenId);
        }

        emit LayawayTermination(tokenId, info.provider, currentOwner, paymentCompleted);
    }

    /// @dev See {IERCX-endRental}.
    function endRental(uint256 tokenId, address provider) public virtual override onlyRentedToken(tokenId) {
        uint256 subrentLevel = _subrentLevels[tokenId][provider];
        require(subrentLevel != 0, "ERCX: Specified rental does not exist");
        
        RentalInfo memory info = _rentals[tokenId].rentals[subrentLevel - 1];
        require(info.deadline < block.timestamp, "ERCX: rental not expired yet");

        address currentOwner = _ownerOf(tokenId);
        uint256 nRentals = _rentals[tokenId].rentals.length;
        for (uint256 i = subrentLevel; i <= nRentals; i++) {
            address renter = _rentals[tokenId].rentals[_rentals[tokenId].rentals.length - 1].provider;

            emit RentalTermination(tokenId, renter, currentOwner);

            _rentals[tokenId].rentals.pop();
            if(i != nRentals - 1) {
                delete _rentalApprovals[tokenId][renter];
            }
            delete _subrentLevels[tokenId][renter];
        }

        delete _rentalApprovals[tokenId][currentOwner];
        delete _rentals[tokenId].providerApproved;
        delete _rentals[tokenId].receiverApproved;

        _transfer(currentOwner, provider, tokenId);
    }

    /// @dev See {IERCX-approveLayawayControl}.
    function approveLayawayControl(address to, uint256 tokenId) public virtual override {
        require(!isLayawayed(tokenId) && !isRented(tokenId), "ERCX: cannot approve layawayed or rented token");
        
        address owner = _ownerOf(tokenId);
        require(to != owner, "ERCX: layaway approval to current owner");
        require(_msgSender() == owner, "ERCX: approve caller is not token owner");

        _layawayApprovals[tokenId] = to;
        
        emit LayawayApproval(owner, to, tokenId);
    }

    /// @dev See {IERCX-approveLayawayTransfer}.
    function approveLayawayTransfer(address to, uint256 tokenId) public virtual override onlyLayawayedToken(tokenId) {
        address provider =  _layaways[tokenId].provider;
        address sender = _msgSender();
        require(sender == provider || sender == _ownerOf(tokenId), "ERCX: Only layaway provider or receiver can approve layaway transfer");
        if (_msgSender() == provider) {
            _layaways[tokenId].providerApproved = to;
             emit LayawayOwnershipTransferApproval(sender, to, tokenId);
        }
        else {
            _layaways[tokenId].receiverApproved = to;
            emit LayawayedTokenTransferApproval(sender, to, tokenId);
        }
    }

    /// @dev See {IERCX-approveRentalTransfer}.
    function approveRentalTransfer(address to, uint256 tokenId) public virtual override onlyRentedToken(tokenId) {
        require(_rentals[tokenId].allowTransfers, "ERCX: Transfers during rental not allowed on this token");

        address provider =  _rentals[tokenId].rentals[_rentals[tokenId].rentals.length - 1].provider;
        address sender = _msgSender();
        require(sender == provider || sender == _ownerOf(tokenId), "ERCX: Only rental provider or receiver can approve rental transfer");
        
        if (_msgSender() == provider) {
            _rentals[tokenId].providerApproved = to;
            emit RentalOwnershipTransferApproval(sender, to, tokenId);
        }
        else {
            _rentals[tokenId].receiverApproved = to;
            emit RentedTokenTransferApproval(sender, to, tokenId);
        }
    }

    /// @dev See {IERCX-approveRentalControl}.
    function approveRentalControl(uint256 tokenId, address to) public virtual override {
        require(!isLayawayed(tokenId), "ERCX: Cannot rent layawayed token");
        
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERCX: Rental approval to current owner");
        require(_msgSender() == owner, "ERCX: approve caller is not token owner");

        _rentalApprovals[tokenId][owner] = to;
        
        emit RentalApproval(owner, to, tokenId);
    }

    /// @dev See {IERCX-getLayawayApproved}.
    function getLayawayApproved(uint256 tokenId) public view virtual override returns (address approved) {
        _requireMinted(tokenId);
        return _layawayApprovals[tokenId];
    }

    /// @dev See {IERCX-getRentalApproved}.
    function getRentalApproved(uint256 tokenId, address approver) public view virtual override returns (address approved) {
        _requireMinted(tokenId);
        return _rentalApprovals[tokenId][approver];
    }
    
    /// @dev See {IERCX-getLayawayprovider}.
    function getLayawayProvider(uint256 tokenId) public view virtual override onlyLayawayedToken(tokenId) returns (address provider) {
        return _layaways[tokenId].provider;
    }
    
    /// @dev See {IERCX-getLayawayDeadline}.
    function getLayawayDeadline(uint256 tokenId) public view virtual override onlyLayawayedToken(tokenId) returns (uint256 deadline) {
        return _layaways[tokenId].deadline;
    }

    /// @dev See {IERCX-getLayawayOwnershipTransferApproved}.
    function getLayawayOwnershipTransferApproved(uint256 tokenId) public view virtual override onlyLayawayedToken(tokenId) returns (address approved) {
        return _layaways[tokenId].providerApproved;
    }

    /// @dev See {IERCX-getLayawayedTokenTransferApproved}.
    function getLayawayedTokenTransferApproved(uint256 tokenId) public view virtual override onlyLayawayedToken(tokenId) returns (address approved) {
        return _layaways[tokenId].receiverApproved;
    }

    /// @dev See {IERCX-getRentalDeadline}.
    function getRentalDeadline(uint256 tokenId, address provider) public view virtual override onlyRentedToken(tokenId) returns (uint256 deadline) {
        uint256 subrentLevel = _subrentLevels[tokenId][provider];
        require(subrentLevel != 0, "ERCX: Specified rental does not exist");
        return _rentals[tokenId].rentals[subrentLevel - 1].deadline;
    }

    /// @dev See {IERCX-isSubrentalAllowed}.
    function isSubrentalAllowed(uint256 tokenId) public view virtual override onlyRentedToken(tokenId) returns (bool subrentalAllowed) {
        return _rentals[tokenId].allowSubrental;
    }

    /// @dev See {IERCX-isRentalTransferAllowed}.
    function isRentalTransferAllowed(uint256 tokenId) public view virtual override onlyRentedToken(tokenId) returns (bool transferAllowed) {
        return _rentals[tokenId].allowTransfers;
    }

    /// @dev See {IERCX-getRentalOwnershipTransferApproved}.
    function getRentalOwnershipTransferApproved(uint256 tokenId) public view virtual override onlyRentedToken(tokenId) returns (address approved) {
        return _rentals[tokenId].providerApproved;
    }

    /// @dev See {IERCX-getRentedTokenTransferApproved}.
    function getRentedTokenTransferApproved(uint256 tokenId) public view virtual override onlyRentedToken(tokenId) returns (address approved) {
        return _rentals[tokenId].receiverApproved;
    }

    /// @dev See {IERCX-getRentals}.
    function getRentals(uint256 tokenId) public view virtual override onlyRentedToken(tokenId) returns (RentalInfo[] memory rentals) {
        return _rentals[tokenId].rentals;
    }

    /** @dev See {IERCX-transferLayawayedToken}.*/
    function transferLayawayedToken(address to, uint256 tokenId) public virtual override onlyLayawayedToken(tokenId) {
        LayawayInfo memory info = _layaways[tokenId];
        address sender = _msgSender();
        address owner = _ownerOf(tokenId);
        
        require(sender == owner || sender == info.receiverApproved, "ERCX: only layaway receiver or approved address can transfer layawayex token");
        require(to != info.provider, "ERCX: Cannot transfer to layaway provider");
        
        emit LayawayedTokenTransfer(tokenId, owner, to);

        address layawayApproved = _layawayApprovals[tokenId];
        _transfer(owner, to, tokenId);
        _layaways[tokenId].receiverApproved = address(0);
        _layawayApprovals[tokenId] = layawayApproved;
    }

    /** @dev See {IERCX-transferLayaway}.*/
    function transferLayawayOwnership(address to, uint256 tokenId) public virtual override onlyLayawayedToken(tokenId) {
        LayawayInfo memory info = _layaways[tokenId];
        address sender = _msgSender();

        require(sender == info.provider || sender == info.providerApproved, "ERCX: only layaway provider or approved address can transfer layaway");
        require(to != _ownerOf(tokenId), "ERCX: Cannot transfer to layaway receiver");

        emit LayawayOwnershipTransfer(tokenId, info.provider, to);
        
        _layaways[tokenId].provider = to;
        _layaways[tokenId].providerApproved = address(0);

    }

    /** @dev See {IERCX-transferRentedToken}.*/
    function transferRentedToken(address to, uint256 tokenId) public virtual override onlyRentedToken(tokenId) {
        TokenRentals storage info = _rentals[tokenId];
        require(info.allowTransfers, "ERCX: transfers during rental not allowed on this token");
        address sender = _msgSender();
        address owner = _ownerOf(tokenId);
        require(sender == owner || sender == info.receiverApproved, "ERCX: only rental receiver or approved address can transfer during rental");
        
        require(_subrentLevels[tokenId][to] == 0, "ERCX: cannot transfer to an account that is currently subrenting the token");
            
        emit RentedTokenTransfer(tokenId, owner, to);

        address rentalApproved = _rentalApprovals[tokenId][owner];
        _transfer(owner, to, tokenId);
        info.receiverApproved = address(0);
        _rentalApprovals[tokenId][owner] = rentalApproved;
    }

    /** @dev See {IERCX-transferRentalOwnership}.*/
    function transferRentalOwnership(address to, uint256 tokenId) public virtual override onlyRentedToken(tokenId) {
        RentalInfo storage rental = _rentals[tokenId].rentals[_rentals[tokenId].rentals.length - 1];
        TokenRentals storage info = _rentals[tokenId];
        require(info.allowTransfers, "ERCX: transfers during rental not allowed on this token");
        address sender = _msgSender();
        address owner = _ownerOf(tokenId);

        require(sender == rental.provider || sender == info.providerApproved, "ERCX: only rental provider or approved address can transfer during rental");

        require(to != owner, "ERCX: Cannot transfer to rental receiver");
        require(_subrentLevels[tokenId][to] == 0, "ERCX: cannot transfer to an account that is currently subrenting the token");


        emit RentalOwnershipTransfer(tokenId, rental.provider, to);
        
        info.providerApproved = address(0);

        _subrentLevels[tokenId][to] = _subrentLevels[tokenId][rental.provider];
        delete _subrentLevels[tokenId][rental.provider];

        _rentalApprovals[tokenId][to] = _rentalApprovals[tokenId][rental.provider];
        delete _rentalApprovals[tokenId][rental.provider];
        
        rental.provider = to;
    }

    /** @dev See {IERCX-redeemRentedToken}.*/
    function redeemRentedToken(uint256 tokenId) public virtual override onlyRentedToken(tokenId) {
        require(_rentals[tokenId].rentals.length == 1, "ERCX: Unrented or subrented tokens cannot be sold");
        RentalInfo memory rental = _rentals[tokenId].rentals[0];
        require(_msgSender() == rental.provider || _msgSender() == _rentalApprovals[tokenId][rental.provider], "ERCX: can be called only by rental provider or address approved for rental");
        
        delete _rentals[tokenId];
        delete _rentalApprovals[tokenId][rental.provider];
        delete _subrentLevels[tokenId][rental.provider];

        emit RentedTokenRedemption(tokenId, rental.provider, _ownerOf(tokenId));
    }
    
    /**  @dev See {ERC721-_beforeTokeenTransfer}.
     @notice Resets layaway and rental approvals before transfering */
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual override{
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        for (uint256 tokenId = firstTokenId; tokenId < firstTokenId + batchSize; tokenId++) {
            delete _layawayApprovals[tokenId];
            delete _rentalApprovals[tokenId][from];
        }
    } 
    
    /**  @dev See {ERC721-transferFrom}.
     @notice Resets layaway and rental approvals before transfering */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(!isLayawayed(tokenId), "ERCX: use transferLayawayedToken function to transfer a layawayed token");
        require(!isRented(tokenId), "ERCX: Cannot transfer rented token. If rental expired call endRental before");
        ERC721.transferFrom(from, to, tokenId);
    }

    /**  @dev See {ERC721-safeTransferFrom}.
     @notice Resets layaway and rental approvals before transfering */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(!isLayawayed(tokenId), "ERCX: use transferLayawayedToken function to transfer a layawayed token");
        require(!isRented(tokenId), "ERCX: Cannot transfer rented token. If rental expired call endRental before");
        ERC721.safeTransferFrom(from, to, tokenId);
    }

    /**  @dev See {ERC721-safeTransferFrom}.
     @notice Resets layaway and rental approvals before transfering */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        require(!isLayawayed(tokenId), "ERCX: use transferLayawayedToken function to transfer a layawayed token");
        require(!isRented(tokenId), "ERCX: Cannot transfer rented token. If rental expired call endRental before");
        ERC721.safeTransferFrom(from, to, tokenId, data);
    }

    /**  @dev See {ERC721-approve}.
     @notice throws if 'tokenId' is currently layawayed or rented*/
    function approve(address to, uint256 tokenId) public virtual override {
        require(!isLayawayed(tokenId) && !isRented(tokenId), "ERCX: cannot approve layawayed or rented token");
        ERC721.approve(to, tokenId);  
    }

    /** @dev See {IERC165-supportsInterface}. */ 
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERCX).interfaceId || super.supportsInterface(interfaceId);
    }


    /**
     * @dev Get index of rental or subrental provider
     * in the corresponding list in _rentals mapping
     */
    function getSubrentLevel(uint256 tokenId, address provider) public view virtual onlyRentedToken(tokenId) returns (uint256 subrentLevel) {
        return _subrentLevels[tokenId][provider] - 1;
    }


    /**
     * @dev Check if `tokenId` is currently layawayed.
     *  Does not check for token existence.
     */
    function isLayawayed(uint256 tokenId) public view virtual returns (bool) {
        return _layaways[tokenId].provider != address(0);
    }

    /**
     * @dev Check if `tokenId` is currently rented.
     *  Does not check for token existence.
     */
    function isRented(uint256 tokenId) public view virtual returns (bool) {
        return _rentals[tokenId].rentals.length > 0;
    }

    /**
     * @dev Check if `tokenId` is currently rented or subrented by `provider`
     */
    function rentalExists(uint256 tokenId, address provider) public view virtual returns (bool exists) {
        uint256 subrentLevel = _subrentLevels[tokenId][provider];
        return subrentLevel != 0;
    }

    /**
     * @dev Check if `provider` is currently subrenting `tokenId`
     */
    function isSubrent(uint256 tokenId, address provider) public view returns (bool subrent) {
        return _subrentLevels[tokenId][provider] != 1;
    }

}
