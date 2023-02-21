//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./ERCX.sol";


contract LayawayMarketplace {
    
    event newLayawayProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 installmentAmount, uint256 installmentFrequency, uint256 totalInstallments);
    event newTransferProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price);



    struct LayawayProposal {
        ERCX collection;
        uint256 tokenId;
        address proposer;
        uint256 installmentAmount;      //Amount due per installment
        uint256 installmentFrequency;   //Installments frequency
        uint256 totalInstallments;      //Total number of installments for the layaway
        uint256 proposalId;
    }

    struct TransferProposal {
        ERCX collection;
        uint256 tokenId;
        address proposer;
        uint256 price;
        uint256 proposalId;
    }

    struct Layaway {
        ERCX collection;
        uint256 tokenId;
        uint256 installmentAmount;      //Amount due per installment
        uint256 installmentFrequency;   //Installments frequency
        uint256 paidInstallments;       //Number of installments paid yet
        uint256 totalInstallments;      //Total number of installments for the layaway
        uint256 lastPaymentTime;
        uint256 layawayId;
    }


    mapping(uint256 => LayawayProposal) private _layawayProposals;
    uint256 private _layawayProposalsCount;

    mapping(uint256 => Layaway) private _layaways;
    uint256 private _layawaysCount;

    mapping(uint256 => TransferProposal) private _transferProposals;
    uint256 private _transferProposalsCount;



    constructor() {}


    function makeLayawayProposal(ERCX collection, uint256 tokenId, uint256 installmentAmount, uint256 installmentFrequency, uint256 totalInstallments) external {
        require(!collection._isRented(tokenId) && !collection._isLayawayed(tokenId), "LayawayMarketplace: Cannot layaway a rented or layawayed token");
        
        address owner = collection.ownerOf(tokenId);
        require(owner == msg.sender, "LayawayMarketplace: only token owner can create a layaway proposal");
        require(collection.getLayawayApproved(tokenId) == address(this), "LayawayMarketplace: you must approve layaway control to this contract in order to create a rental proposal");
        require(totalInstallments >= 1, "LayawayMarketplace: layaway must have at least one installment");
        require(installmentFrequency > 300, "LayawayMarketplace: Installment frequency cannot be less than five minutes");

        LayawayProposal storage proposal = _layawayProposals[_layawayProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = owner;
        proposal.installmentAmount = installmentAmount;
        proposal.installmentFrequency = installmentFrequency;
        proposal.totalInstallments = totalInstallments;
        proposal.proposalId = _layawayProposalsCount++;

        emit newLayawayProposal(collection, tokenId, installmentAmount, installmentFrequency, totalInstallments);
    }


    function makeLayawayTransferProposal(ERCX collection, uint256 tokenId, uint256 price) external {
        address sender = msg.sender;
        if(collection.getLayawayProvider(tokenId) == sender) {
            require(collection.getLayawayTransferProviderApproved(tokenId) == address(this), "LayawayMarketplace: you must approve layaway transfer to this contract in order to make a transfer proposal");
        }
        else if (collection.ownerOf(tokenId) == sender){
            require(collection.getLayawayTransferReceiverApproved(tokenId) == address(this), "LayawayMarketplace: you must approve layaway transfer to this contract in order to make a transfer proposal");
        }
        else {
            revert("LayawayMarketplace: you must be the layaway provider or receiver in order to make a transfer proposal");
        }
         
        TransferProposal storage proposal = _transferProposals[_transferProposalsCount];
        proposal.collection = collection;
        proposal.tokenId = tokenId;
        proposal.proposer = sender;
        proposal.price = price;
        proposal.proposalId = _transferProposalsCount++; 

        emit newTransferProposal(collection, tokenId, price);
    }

    function acceptLayawayProposal(uint256 proposalId) external payable returns (int layawayId) {
        LayawayProposal memory proposal = _layawayProposals[proposalId];
        require(proposal.proposer == proposal.collection.ownerOf(proposal.tokenId), "LayawayMarketplace: proposer does not own the token anymore");
        require(msg.value >= proposal.installmentAmount, "LayawayMarketplace: you must pay the first installment in order to accept the proposal");
        require(proposal.collection.getLayawayApproved(proposal.tokenId) == address(this), "LayawayMarketplace: proposer must approve rental control to this contract in order to start the rental");
        
        delete _layawayProposals[proposalId];
        _layawayProposalsCount--;

        try proposal.collection.startLayaway(proposal.tokenId, msg.sender, block.timestamp+proposal.installmentFrequency) {
            payable(proposal.proposer).transfer(msg.value);

            Layaway storage layaway = _layaways[_layawaysCount];
            layaway.collection = proposal.collection;
            layaway.tokenId = proposal.tokenId;
            layaway.installmentAmount = proposal.installmentAmount;
            layaway.installmentFrequency = proposal.installmentFrequency;  
            layaway.paidInstallments = 1;       
            layaway.totalInstallments = proposal.totalInstallments;      
            layaway.lastPaymentTime = block.timestamp;
            layaway.layawayId = _layawaysCount++;
            return int(layaway.layawayId);
        }
        catch {
            return -1;
        }
    }

    function payLayawayInstallment(uint256 layawayId) external payable {
        Layaway storage layaway = _layaways[layawayId];

        require(layaway.paidInstallments < layaway.totalInstallments, "LayawayMarketplace: All installments paid yet");
        require(msg.value >= layaway.installmentAmount, "LayawayMarketplace: Sent value must be greater or equal to installment value");

        address provider = layaway.collection.getLayawayProvider(layaway.tokenId);
        payable(provider).transfer(msg.value);

        layaway.paidInstallments++;
        layaway.lastPaymentTime = block.timestamp;
    }

    function endLayaway(uint256 layawayId) external {
        Layaway memory layaway = _layaways[layawayId];

        if(layaway.paidInstallments == layaway.totalInstallments) {
            layaway.collection.endLayaway(layaway.tokenId, true);
        }
        else{
            require(layaway.lastPaymentTime + layaway.installmentFrequency <= block.timestamp, "LayawayMarketplace: layaway not expired yet");
            layaway.collection.endLayaway(layaway.tokenId, false);
        }
    }

    



    function acceptTransferProposal(uint256 proposalId) external payable returns (bool success) {
        TransferProposal memory proposal = _transferProposals[proposalId];
        require(msg.value >= proposal.price, "LayawayMarketplace: you must pay for the transfer in order to accept the proposal");
        require(proposal.collection.getLayawayTransferProviderApproved(proposal.tokenId) == address(this) || proposal.collection.getLayawayTransferReceiverApproved(proposal.tokenId) == address(this) , "LayawayMarketplace: proposer must approve layaway transfer to this contract in order to accept the proposal");

        delete _transferProposals[proposalId];
        _transferProposalsCount--;

        if(proposal.proposer == proposal.collection.getLayawayProvider(proposal.tokenId)) {
            try proposal.collection.transferLayaway(msg.sender, proposal.tokenId) {
                payable(proposal.proposer).transfer(msg.value);
                return true;
            }
            catch {
                return false;
            }
        }
        else if (proposal.proposer == proposal.collection.ownerOf(proposal.tokenId)) {      // if proposer is token owner
            try proposal.collection.transferLayawayedToken(msg.sender, proposal.tokenId) {
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


    function deleteLayawayProposal(uint256 proposalId) external {
        require(msg.sender == _layawayProposals[proposalId].proposer);
        delete _layawayProposals[proposalId];
        _layawayProposalsCount--;
    }

    function deleteTransferProposal(uint256 proposalId) external {
        require(msg.sender == _transferProposals[proposalId].proposer);
        delete _transferProposals[proposalId];
        _transferProposalsCount--;
    }
}