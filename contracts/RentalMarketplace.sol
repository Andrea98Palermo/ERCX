//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./ERCX.sol";


/**
    Marketplace that acts as intermediary for ERCX tokens rentals
 */
contract RentalMarketplace {
    
    /**
        Emitted when a new rental proposal is submitted to the contract
     */
    event newRentalProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price, uint256 duration, bool allowSubrental, bool allowTransfers);
    /**
        Emitted when a new subrental proposal is submitted to the contract
     */
    event newSubrentalProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price, uint256 duration);
    /**
        Emitted when a new rental update proposal is submitted to the contract
     */
    event newUpdateProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price, uint256 duration);
    /**
        Emitted when a new rental transfer proposal is submitted to the contract
     */
    event newTransferProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price);
    /**
        Emitted when a new rented token cession proposal is submitted to the contract
     */
    event newCessionProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price);


    struct FullProposal {
        ERCX collection;            //ERCX contract address
        uint256 tokenId;            //NFT's tokenId
        address proposer;           //Proposal creator
        uint256 price;              //Proposed rental price
        uint256 duration;           //Proposed rental duration
        uint256 proposalId;         //Proposal's index in _rentalProposals mapping
        bool allowSubrental;        //Specifies if the proposer wants to allow successive subrental
        bool allowTransfers;        //Specifies if the proposer wants to allow transfers during rental
    }

    struct Proposal {
        ERCX collection;            //ERCX contract address
        uint256 tokenId;            //NFT's tokenId
        address proposer;           //Proposal creator
        uint256 price;              //Proposed rental price
        uint256 duration;           //Proposed rental duration
        uint256 proposalId;         //Proposal's index in proposals mappings
    }

    struct TransferProposal {
        ERCX collection;            //ERCX contract address
        uint256 tokenId;            //NFT's tokenId
        address proposer;           //Proposal creator
        uint256 price;              //Proposed rental price
        uint256 proposalId;         //Proposal's index in _transferProposals mapping
    }


    //Current rental proposals
    mapping(uint256 => FullProposal) private _rentalProposals;
    //Number of existing rental proposals
    uint256 private _rentalProposalsCount;
    
    //Current subrental proposals
    mapping(uint256 => Proposal) private _subrentalProposals;
    //Number of existing subrental proposals
    uint256 private _subrentalProposalsCount;

    //Current rental update proposals
    mapping(uint256 => Proposal) private _updateProposals;
    //Number of existing rental update proposals
    uint256 private _updateProposalsCount;

    //Current rental transfer proposals
    mapping(uint256 => TransferProposal) private _transferProposals;
    //Number of existing rental transfer proposals
    uint256 private _transferProposalsCount;

    //Current rented token cession proposals
    mapping(uint256 => TransferProposal) private _cessionProposals;
    //Number of existing cession proposals
    uint256 private _cessionProposalsCount;


    constructor() {}


    /**
        Creates a rental proposal. Can be called only by owner of 'tokenId'.
     */
    function makeRentalProposal(ERCX collection, uint256 tokenId, uint256 price, uint256 duration, bool allowSubrental, bool allowTransfers) external {
        require(!collection._isRented(tokenId), "RentalMarketplace: Use makeSubrentalProposal function to subrent a token");
        address owner = collection.ownerOf(tokenId);
        require(owner == msg.sender, "RentalMarketplace: only token owner can create a rental proposal");
        require(collection.getRentalApproved(tokenId, owner) == address(this), "RentalMarketplace: you must approve rental control to this contract in order to create a rental proposal");
        require(!collection._isLayawayed(tokenId), "RentalMarketplace: Cannot start rental on a layawayed token");

        FullProposal storage proposal = _rentalProposals[_rentalProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = owner;
        proposal.price = price;
        proposal.duration = duration;
        proposal.proposalId = _rentalProposalsCount++;
        proposal.allowSubrental = allowSubrental;
        proposal.allowTransfers = allowTransfers;

        emit newRentalProposal(collection, tokenId, price, duration, allowSubrental, allowTransfers);
    }

    /**
        Creates a subrental proposal. Can be called only by owner of 'tokenId' if token is rented.
     */
    function makeSubRentalProposal(ERCX collection, uint256 tokenId, uint256 price, uint256 duration) external {
        require(collection._isRented(tokenId), "RentalMarketplace: Use makeRentalProposal function for normal rent");
        address owner = collection.ownerOf(tokenId);
        require(owner == msg.sender, "RentalMarketplace: only token owner can create a rental proposal");
        require(collection.getRentalApproved(tokenId, owner) == address(this), "RentalMarketplace: you must approve rental control to this contract in order to create a rental proposal");
        require(!collection._isLayawayed(tokenId), "RentalMarketplace: Cannot start rental on a layawayed token");
        require(collection.isSubrentalAllowed(tokenId), "RentalMarketplace: Subrental is not allowed on this token");

        Proposal storage proposal = _subrentalProposals[_subrentalProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = owner;
        proposal.price = price;
        proposal.duration = duration;
        proposal.proposalId = _subrentalProposalsCount++; 

        emit newSubrentalProposal(collection, tokenId, price, duration);
    }

    /**
        Creates a rental deadline update proposal. Can be called only by rental provider.
     */
    function makeRentalUpdateProposal(ERCX collection, uint256 tokenId, uint256 price, uint256 duration) external {
        address sender = msg.sender;
        require(collection.rentalExists(tokenId, sender), "RentalMarketplace: specified rental does not exist");
        require(collection.getRentalApproved(tokenId, sender) == address(this), "RentalMarketplace: rental control must be approved to this contract in order to create an update proposal");

        Proposal storage proposal = _updateProposals[_updateProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = sender;
        proposal.price = price;
        proposal.duration = duration;
        proposal.proposalId = _updateProposalsCount++;

        emit newUpdateProposal(collection, tokenId, price, duration);
    }

    /**
        Creates a rental transfer proposal. Can be called only by 'tokenId' rental provider or receiver.
     */
    function makeRentalTransferProposal(ERCX collection, uint256 tokenId, uint256 price) external {
        require(collection.isRentalTransferAllowed(tokenId), "ERCX: transfers during rental not allowed on this token");
        IERCX.RentalInfo[] memory rentals = collection.getRentals(tokenId);
        address sender = msg.sender;
        if(rentals[rentals.length - 1].provider == sender) {
            require(collection.getRentalOwnershipTransferApproved(tokenId) == address(this), "RentalMarketplace: you must approve rental transfer to this contract in order to make a transfer proposal");
        }
        else if (collection.ownerOf(tokenId) == sender){
            require(collection.getRentedTokenTransferApproved(tokenId) == address(this), "RentalMarketplace: you must approve rental transfer to this contract in order to make a transfer proposal");
        }
        else {
            revert("RentalMarketplace: you must be the rental provider or receiver in order to make a transfer proposal");
        }
         
        TransferProposal storage proposal = _transferProposals[_transferProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = sender;
        proposal.price = price;
        proposal.proposalId = _transferProposalsCount++; 

        emit newTransferProposal(collection, tokenId, price);
    }

    /**
        Creates a rented token cession proposal. Can be called only by 'tokenId' rental provider or receiver.
     */
    function makeRentalCessionProposal(ERCX collection, uint256 tokenId, uint256 price) external {
        IERCX.RentalInfo[] memory rentals = collection.getRentals(tokenId);
        require(rentals.length == 1, "RentalMarketplace: unrented or subrented tokens cannot be sold");
        address sender = msg.sender;
        require(sender == rentals[0].provider, "RentalMarketplace: you must be the rental provider in order to make a cession proposal");
        require(collection.getRentalApproved(tokenId, sender) ==  address(this), "RentalMarketplace: you must approve rental control to this contract in order to make a cession proposal");
         
        TransferProposal storage proposal = _cessionProposals[_cessionProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = sender;
        proposal.price = price;
        proposal.proposalId = _cessionProposalsCount++; 

        emit newCessionProposal(collection, tokenId, price);
    }


    /**
        Can be called by any address to accept rental proposal and start rental.
        Caller must pay proposed price.
     */
    function acceptRentalProposal(uint256 proposalId) external payable returns (bool success) {
        FullProposal memory proposal = _rentalProposals[proposalId];

        require(proposal.proposer == proposal.collection.ownerOf(proposal.tokenId), "RentalMarketplace: proposer does not own the token anymore");
        require(msg.value >= proposal.price, "RentalMarketplace: you must pay for the rental in order to accept the proposal");
        require(proposal.collection.getRentalApproved(proposal.tokenId, proposal.collection.ownerOf(proposal.tokenId)) == address(this), "RentalMarketplace: proposer must approve rental control to this contract in order to start the rental");
        
        delete _rentalProposals[proposalId];
        _rentalProposalsCount--;

        try proposal.collection.startRental(proposal.tokenId, msg.sender, block.timestamp+proposal.duration, proposal.allowSubrental, proposal.allowTransfers) {
            payable(proposal.proposer).transfer(msg.value);
            return true;
        }
        catch {
            return false;
        }
    }

    /**
        Can be called by any address to accept subrental proposal and start subrental.
        Caller must pay proposed price.
     */
    function acceptSubrentalProposal(uint256 proposalId) external payable returns (bool success) {
        Proposal memory proposal = _subrentalProposals[proposalId];
        require(proposal.proposer == proposal.collection.ownerOf(proposal.tokenId), "RentalMarketplace: proposer does not own the token anymore");
        require(msg.value >= proposal.price, "RentalMarketplace: you must pay for the rental in order to accept the proposal");
        require(proposal.collection.getRentalApproved(proposal.tokenId, proposal.collection.ownerOf(proposal.tokenId)) == address(this), "RentalMarketplace: proposer must approve rental control to this contract in order to start the rental");
        IERCX.RentalInfo[] memory rentals = proposal.collection.getRentals(proposal.tokenId);
        require(block.timestamp + proposal.duration <= rentals[rentals.length - 1].deadline, "RentalMarketplace: Cannot subrent for a period longer than your rental period");

        delete _subrentalProposals[proposalId];
        _subrentalProposalsCount--;

        try proposal.collection.startSubrental(proposal.tokenId, msg.sender, block.timestamp+proposal.duration) {
            payable(proposal.proposer).transfer(msg.value);
            return true;
        }
        catch {
            return false;
        }
    }

    /**
        Can be called only by rental receiver to accept rental update proposal and update rental deadline.
        Caller must pay proposed price.
     */
    function acceptUpdateProposal(uint256 proposalId) external payable returns (bool success) {
        Proposal memory proposal = _updateProposals[proposalId];

        require(msg.sender == proposal.collection.ownerOf(proposal.tokenId), "RentalMarketplace: only rental receiver can accept update proposal");
        require(msg.value >= proposal.price, "RentalMarketplace: you must pay for the rental in order to accept the proposal");
        require(proposal.collection.getRentalApproved(proposal.tokenId, proposal.proposer) == address(this), "RentalMarketplace: proposer must approve rental control to this contract in order to update the rental");

        uint256 newDeadline = block.timestamp + proposal.duration;
        require(newDeadline > proposal.collection.getRentalDeadline(proposal.tokenId, proposal.proposer), "RentalMarketplace: Cannot anticipate rental deadline");

        IERCX.RentalInfo[] memory rentals = proposal.collection.getRentals(proposal.tokenId);
        require(rentals[rentals.length-1].provider == proposal.proposer, "RentalMarketplace: Proposer is not rental provider anymore");

        if (proposal.collection.isSubrent(proposal.tokenId, proposal.proposer)) {
            require(newDeadline <= proposal.collection.getRentals(proposal.tokenId)[proposal.collection.getSubrentLevel(proposal.tokenId, proposal.proposer) - 1].deadline, "ERCX: Cannot set subrent deadline after your rental deadline");
        }

        delete _updateProposals[proposalId];
        _updateProposalsCount--;

        try proposal.collection.updateRental(proposal.tokenId, block.timestamp+proposal.duration, proposal.proposer) {
            payable(proposal.proposer).transfer(msg.value);
            return true;
        }
        catch {
            return false;
        }
    }


    /**
        Can be called by any address to accept rental transfer proposal.
        If proposer is the rental receiver, the token is transfered to a new receiver.
        Otherwise, if proposer is the rental provider, the rental ownership is transfered to a new provider.
        Caller must pay proposed price.
     */
    function acceptTransferProposal(uint256 proposalId) external payable returns (bool success) {
        TransferProposal memory proposal = _transferProposals[proposalId];
        require(msg.value >= proposal.price, "RentalMarketplace: you must pay for the transfer in order to accept the proposal");
        require(proposal.collection.getRentalOwnershipTransferApproved(proposal.tokenId) == address(this) || proposal.collection.getRentedTokenTransferApproved(proposal.tokenId) == address(this) , "RentalMarketplace: proposer must approve rental transfer to this contract in order to accept the proposal");

        delete _transferProposals[proposalId];
        _transferProposalsCount--;

        IERCX.RentalInfo[] memory rentals = proposal.collection.getRentals(proposal.tokenId);
        if(proposal.proposer == proposal.collection.ownerOf(proposal.tokenId)) {
            try proposal.collection.transferRentedToken(msg.sender, proposal.tokenId) {
                payable(proposal.proposer).transfer(msg.value);
                return true;
            }
            catch {
                return false;
            }
        }
        else if (proposal.proposer == rentals[rentals.length-1].provider) {
            try proposal.collection.transferRentalOwnership(msg.sender, proposal.tokenId) {
                payable(proposal.proposer).transfer(msg.value);
                return true;
            }
            catch {
                return false;
            }
        }
        else {
            return false;
        }
    }

    /**
        Can be called only by rental receiver to accept cession proposal and end the layaway
        Caller must pay proposed price.
     */
    function acceptCessionProposal(uint256 proposalId) external payable returns (bool success) {
        TransferProposal memory proposal = _cessionProposals[proposalId];
        require(msg.sender == proposal.collection.ownerOf(proposal.tokenId), "RentalMarketplace: only rental receiver can accept cession proposal");
        require(msg.value >= proposal.price, "RentalMarketplace: you must pay for the transfer in order to accept the proposal");
        require(proposal.collection.getRentalApproved(proposal.tokenId, proposal.proposer) == address(this), "RentalMarketplace: proposer must approve rental control to this contract in order to accept the proposal");

        IERCX.RentalInfo[] memory rentals = proposal.collection.getRentals(proposal.tokenId);
        require(rentals.length == 1, "RentalMarketplace: unrented or subrented tokens cannot be sold");
        require(proposal.proposer == rentals[rentals.length-1].provider, "RentalMarketplace: Proposer is not rental provider anymore");

        delete _cessionProposals[proposalId];
        _cessionProposalsCount--;

        try proposal.collection.redeemRentedToken(proposal.tokenId) {
            payable(proposal.proposer).transfer(msg.value);
            return true;
        }
        catch {
            return false;
        }
    }

    /**
        Deletes a rental proposal. Can be called only by rental proposer.
     */
    function deleteRentalProposal(uint256 proposalId) external {
        require(msg.sender == _rentalProposals[proposalId].proposer);
        delete _rentalProposals[proposalId];
        _rentalProposalsCount--;
    }

    /**
        Deletes a subrental proposal. Can be called only by subrental proposer.
     */
    function deleteSubrentalProposal(uint256 proposalId) external {
        require(msg.sender == _subrentalProposals[proposalId].proposer);
        delete _subrentalProposals[proposalId];
        _subrentalProposalsCount--;
    }

    /**
        Deletes a rental update proposal. Can be called only by update proposer.
     */
    function deleteUpdateProposal(uint256 proposalId) external {
        require(msg.sender == _updateProposals[proposalId].proposer);
        delete _updateProposals[proposalId];
        _updateProposalsCount--;
    }

    /**
        Deletes a rental transfer proposal. Can be called only by transfer proposer.
     */
    function deleteTransferProposal(uint256 proposalId) external {
        require(msg.sender == _transferProposals[proposalId].proposer);
        delete _transferProposals[proposalId];
        _transferProposalsCount--;
    }

    /**
        Deletes a rental cession proposal. Can be called only by cession proposer.
     */
    function deleteCessionProposal(uint256 proposalId) external {
        require(msg.sender == _cessionProposals[proposalId].proposer);
        delete _cessionProposals[proposalId];
        _cessionProposalsCount--;
    }

}