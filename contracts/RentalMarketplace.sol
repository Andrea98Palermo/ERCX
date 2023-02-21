//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./ERCX.sol";


contract RentalMarketplace {
    
    event newRentalProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price, uint256 duration, bool allowSubrental, bool allowTransfers);
    event newSubrentalProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price, uint256 duration);
    event newUpdateProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price, uint256 duration);
    event newTransferProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price);
    event newCessionProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price);


    struct FullProposal {
        ERCX collection;
        uint256 tokenId;
        address proposer;
        uint256 price;
        uint256 duration;
        uint256 proposalId;
        bool allowSubrental;
        bool allowTransfers;
    }

    struct Proposal {
        ERCX collection;
        uint256 tokenId;
        address proposer;
        uint256 price;
        uint256 duration;
        uint256 proposalId;
    }

    struct TransferProposal {
        ERCX collection;
        uint256 tokenId;
        address proposer;
        uint256 price;
        uint256 proposalId;
    }



    mapping(uint256 => FullProposal) private _rentalProposals;
    uint256 private _rentalProposalsCount;

    mapping(uint256 => Proposal) private _subrentalProposals;
    uint256 private _subrentalProposalsCount;

    mapping(uint256 => Proposal) private _updateProposals;
    uint256 private _updateProposalsCount;

    mapping(uint256 => TransferProposal) private _transferProposals;
    uint256 private _transferProposalsCount;

    mapping(uint256 => TransferProposal) private _cessionProposals;
    uint256 private _cessionProposalsCount;


    constructor() {}


    function makeRentalProposal(ERCX collection, uint256 tokenId, uint256 price, uint256 duration, bool allowSubrental, bool allowTransfers) external {
        require(!collection._isRented(tokenId), "RentalMarketplace: Use makeSubrentalProposal function to subrent a token");
        address owner = collection.ownerOf(tokenId);
        require(owner == msg.sender, "RentalMarketplace: only token owner can create a rental proposal");
        require(collection.getRentalApproved(tokenId, owner) == address(this), "RentalMarketplace: you must approve rental control to this contract in order to create a rental proposal");
        require(!collection._isLayawayed(tokenId), "RentalMarketplace: Cannot start rental on a layawayed token");
        //require(duration > 300, "RentalMarketplace: Cannot rent for less than five minutes");

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

    function makeSubRentalProposal(ERCX collection, uint256 tokenId, uint256 price, uint256 duration) external {
        require(collection._isRented(tokenId), "RentalMarketplace: Use makeRentalProposal function for normal rent");
        address owner = collection.ownerOf(tokenId);
        require(owner == msg.sender, "RentalMarketplace: only token owner can create a rental proposal");
        require(collection.getRentalApproved(tokenId, owner) == address(this), "RentalMarketplace: you must approve rental control to this contract in order to create a rental proposal");
        require(!collection._isLayawayed(tokenId), "RentalMarketplace: Cannot start rental on a layawayed token");
        //require(duration > 300, "RentalMarketplace: Cannot rent for less than five minutes");

        require(collection.isSubrentalAllowed(tokenId), "RentalMarketplace: Subrental is not allowed on this token");
        //IERCX.RentalInfo[] memory rentals = collection.getRentals(tokenId);
        //require(deadline <= rentals[rentals.length - 1].deadline, "RentalMarketplace: Cannot subrent for a period longer than your rental period");


        Proposal storage proposal = _subrentalProposals[_subrentalProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = owner;
        proposal.price = price;
        proposal.duration = duration;
        proposal.proposalId = _subrentalProposalsCount++; 

        emit newSubrentalProposal(collection, tokenId, price, duration);
    }

    function makeRentalUpdateProposal(ERCX collection, uint256 tokenId, uint256 price, uint256 duration) external {
        address sender = msg.sender;
        require(collection.rentalExists(tokenId, sender), "RentalMarketplace: specified rental does not exist");
        require(collection.getRentalApproved(tokenId, sender) == address(this), "RentalMarketplace: rental control must be approved to this contract in order to create an update proposal");
        //require(block.timestamp + duration > oldDeadline, "RentalMarketplace: Cannot anticipate rental deadline");

        //if (collection.isSubrent(tokenId, sender)) {
            //require(deadline <= collection.getRentals(tokenId)[collection.getSubrentLevel(tokenId, sender) - 1].deadline, "ERCX: Cannot set subrent deadline after your rental deadline");
        //}

        Proposal storage proposal = _updateProposals[_updateProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = sender;
        proposal.price = price;
        proposal.duration = duration;
        proposal.proposalId = _updateProposalsCount++;

        emit newUpdateProposal(collection, tokenId, price, duration);
    }

    function makeRentalTransferProposal(ERCX collection, uint256 tokenId, uint256 price) external {
        //require(collection._isRented(tokenId), "RentalMarketplace: specified token is not currently rented");
        require(collection.isRentalTransferAllowed(tokenId), "ERCX: transfers during rental not allowed on this token");
        IERCX.RentalInfo[] memory rentals = collection.getRentals(tokenId);
        address sender = msg.sender;
        if(rentals[rentals.length - 1].provider == sender) {
            require(collection.getRentalTransferProviderApproved(tokenId) == address(this), "RentalMarketplace: you must approve rental transfer to this contract in order to make a transfer proposal");
        }
        else if (collection.ownerOf(tokenId) == sender){
            require(collection.getRentalTransferReceiverApproved(tokenId) == address(this), "RentalMarketplace: you must approve rental transfer to this contract in order to make a transfer proposal");
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

    function makeRentalCessionProposal(ERCX collection, uint256 tokenId, uint256 price) external {
        //require(collection._isRented(tokenId), "RentalMarketplace: specified token is not currently rented");
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


    function acceptTransferProposal(uint256 proposalId) external payable returns (bool success) {
        TransferProposal memory proposal = _transferProposals[proposalId];
        require(msg.value >= proposal.price, "RentalMarketplace: you must pay for the transfer in order to accept the proposal");
        require(proposal.collection.getRentalTransferProviderApproved(proposal.tokenId) == address(this) || proposal.collection.getRentalTransferReceiverApproved(proposal.tokenId) == address(this) , "RentalMarketplace: proposer must approve rental transfer to this contract in order to accept the proposal");

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
            try proposal.collection.transferRental(msg.sender, proposal.tokenId) {
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

        try proposal.collection.cedeRentedToken(proposal.tokenId) {
            payable(proposal.proposer).transfer(msg.value);
            return true;
        }
        catch {
            return false;
        }
    }

    
    function deleteRentalProposal(uint256 proposalId) external {
        require(msg.sender == _rentalProposals[proposalId].proposer);
        delete _rentalProposals[proposalId];
        _rentalProposalsCount--;
    }

    function deleteSubrentalProposal(uint256 proposalId) external {
        require(msg.sender == _subrentalProposals[proposalId].proposer);
        delete _subrentalProposals[proposalId];
        _subrentalProposalsCount--;
    }

    function deleteUpdateProposal(uint256 proposalId) external {
        require(msg.sender == _updateProposals[proposalId].proposer);
        delete _updateProposals[proposalId];
        _updateProposalsCount--;
    }

    function deleteTransferProposal(uint256 proposalId) external {
        require(msg.sender == _transferProposals[proposalId].proposer);
        delete _transferProposals[proposalId];
        _transferProposalsCount--;
    }

    function deleteCessionProposal(uint256 proposalId) external {
        require(msg.sender == _cessionProposals[proposalId].proposer);
        delete _cessionProposals[proposalId];
        _cessionProposalsCount--;
    }

}