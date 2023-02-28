//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./ERCX.sol";


/**
    Marketplace that acts as intermediary for ERCX tokens layaways
 */
contract LayawayMarketplace {
    
    /**
        Emitted when a new layaway proposal is submitted to the contract
     */
    event newLayawayProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 installmentAmount, uint256 installmentFrequency, uint256 totalInstallments);
    
    /**
        Emitted when a new layaway proposal is submitted to the contract
     */
    event newTransferProposal(ERCX indexed collection, uint256 indexed tokenId, uint256 indexed price);



    struct LayawayProposal {
        ERCX collection;                //ERCX contract address
        uint256 tokenId;                //NFT's tokenId
        address proposer;               //Proposal creator
        uint256 installmentAmount;      //Amount due per installment
        uint256 installmentFrequency;   //Installments frequency
        uint256 totalInstallments;      //Total number of installments for the layaway
        uint256 proposalId;             //Proposal's index in _layawayProposals mapping
    }

    struct TransferProposal {
        ERCX collection;                //ERCX contract address
        uint256 tokenId;                //NFT's tokenId
        address proposer;               //Proposal creator
        uint256 price;                  //Proposed trnasfer price
        uint256 proposalId;             //Proposal's index in _transferProposals mapping
    }

    struct Layaway {
        ERCX collection;                //ERCX contract address
        uint256 tokenId;                //NFT's tokenId
        uint256 installmentAmount;      //Amount due per installment
        uint256 installmentFrequency;   //Installments frequency
        uint256 paidInstallments;       //Number of installments paid yet
        uint256 totalInstallments;      //Total number of installments for the layaway
        uint256 lastPaymentTime;        //Timestamp of last paid installment
        uint256 layawayId;              //Layaway's index in _layaways mapping
    }

    //Current layaway proposals
    mapping(uint256 => LayawayProposal) private _layawayProposals;
    
    //Number of existing layaway proposals
    uint256 private _layawayProposalsCount;

    //Layaways currently managed by this contract
    mapping(uint256 => Layaway) private _layaways;

    //Number of layaways currently managed by this contract
    uint256 private _layawaysCount;

    //Current layaway transfer proposals
    mapping(uint256 => TransferProposal) private _transferProposals;

    //Number of existing layaway transfer proposals
    uint256 private _transferProposalsCount;



    constructor() {}


    /**
        Creates a layaway proposal. Can be called only by owner of 'tokenId'.
     */
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


    /**
        Creates a layaway transfer proposal. Can be called only by 'tokenId' layaway provider or receiver.
     */
    function makeLayawayTransferProposal(ERCX collection, uint256 tokenId, uint256 price) external {
        address sender = msg.sender;
        if(collection.getLayawayProvider(tokenId) == sender) {
            require(collection.getLayawayOwnershipTransferApproved(tokenId) == address(this), "LayawayMarketplace: you must approve layaway transfer to this contract in order to make a transfer proposal");
        }
        else if (collection.ownerOf(tokenId) == sender){
            require(collection.getLayawayedTokenTransferApproved(tokenId) == address(this), "LayawayMarketplace: you must approve layaway transfer to this contract in order to make a transfer proposal");
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

    /**
        Can be called by any address to accept layaway proposal and start layaway.
        Caller must pay first layaway installment.
     */
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

    /**
        Can be called by any address to pay a layaway installment. 
        The layaway receiver can be different from the caller.
        If installment price is paid, updates layaway deadline
     */
    function payLayawayInstallment(uint256 layawayId) external payable {
        Layaway storage layaway = _layaways[layawayId];

        require(layaway.paidInstallments < layaway.totalInstallments, "LayawayMarketplace: All installments paid yet");
        require(msg.value >= layaway.installmentAmount, "LayawayMarketplace: Sent value must be greater or equal to installment value");

        address provider = layaway.collection.getLayawayProvider(layaway.tokenId);
        payable(provider).transfer(msg.value);

        layaway.paidInstallments++;
        layaway.lastPaymentTime = block.timestamp;
    }

    /**
        Can be called by any address to end a layaway. 
        If all installments have been paid, the layaway receiver keeps the token.
        Otherwise, if layaway installment deadline is expired, the token is returned to the layaway provider
     */
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

    


    /**
        Can be called by any address to accept layaway transfer proposal.
        If proposer is the layaway receiver, the token is transfered to a new receiver.
        Otherwise, if proposer is the layaway provider, the layaway ownership is transfered to a new provider.
        Caller must pay proposed price.
     */
    function acceptTransferProposal(uint256 proposalId) external payable returns (bool success) {
        TransferProposal memory proposal = _transferProposals[proposalId];
        require(msg.value >= proposal.price, "LayawayMarketplace: you must pay for the transfer in order to accept the proposal");
        require(proposal.collection.getLayawayOwnershipTransferApproved(proposal.tokenId) == address(this) || proposal.collection.getLayawayedTokenTransferApproved(proposal.tokenId) == address(this) , "LayawayMarketplace: proposer must approve layaway transfer to this contract in order to accept the proposal");

        delete _transferProposals[proposalId];
        _transferProposalsCount--;

        if(proposal.proposer == proposal.collection.getLayawayProvider(proposal.tokenId)) {
            try proposal.collection.transferLayawayOwnership(msg.sender, proposal.tokenId) {
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

    /**
        Deletes a layaway proposal. Can be called only by layaway proposer.
     */
    function deleteLayawayProposal(uint256 proposalId) external {
        require(msg.sender == _layawayProposals[proposalId].proposer);
        delete _layawayProposals[proposalId];
        _layawayProposalsCount--;
    }

    /**
        Deletes a transfer proposal. Can be called only by transfer proposer.
     */
    function deleteTransferProposal(uint256 proposalId) external {
        require(msg.sender == _transferProposals[proposalId].proposer);
        delete _transferProposals[proposalId];
        _transferProposalsCount--;
    }
}