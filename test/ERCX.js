const { ethers } = require("hardhat");
const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const time = require("@nomicfoundation/hardhat-network-helpers").time;

const setTimeout = require("timers/promises").setTimeout;


describe("ERCX contract", function () {

  async function deployFixture() {
    const ERCX = await ethers.getContractFactory("ERCX_demo");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("ERCXCollection", "ERCX");
    await hardhatERCX.deployed();

    return { ERCX, hardhatERCX, owner, addr1, addr2, addr3, addr4 };
  }

  async function deployAndMintFixture() {
    const ERCX = await ethers.getContractFactory("ERCX_demo");
    const [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("ERCXCollection", "ERCX");
    await hardhatERCX.deployed();

    let tokenId = 0;
    while (tokenId < 3*3) {
      await hardhatERCX.mint(owner.address, tokenId);
      await hardhatERCX.mint(addr1.address, tokenId+1);
      await hardhatERCX.mint(addr2.address, tokenId+2);
      tokenId += 3;
    }

    return { ERCX, hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 };
  }

  async function deployAndLayawayFixture() {
    const ERCX = await ethers.getContractFactory("ERCX_demo");
    const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("ERCXCollection", "ERCX");
    await hardhatERCX.deployed();

    let tokenId = 0;
    while (tokenId < 3*3) {
      await hardhatERCX.mint(owner.address, tokenId);
      await hardhatERCX.mint(addr1.address, tokenId+1);
      await hardhatERCX.mint(addr2.address, tokenId+2);
      tokenId += 3;
    }

    await hardhatERCX.connect(addr1).approveLayawayControl(owner.address, 1);
    await hardhatERCX.connect(owner).startLayaway(1, addr2.address, Math.round((Date.now()+300000)/1000));

    return { ERCX, hardhatERCX, owner, addr1, addr2, addr3, addr4 };
  }

  async function deployAndRentFixture() {
    const ERCX = await ethers.getContractFactory("ERCX_demo");
    const [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("ERCXCollection", "ERCX");
    await hardhatERCX.deployed();

    let tokenId = 0;
    while (tokenId < 3*3) {
      await hardhatERCX.mint(owner.address, tokenId);
      await hardhatERCX.mint(addr1.address, tokenId+1);
      await hardhatERCX.mint(addr2.address, tokenId+2);
      tokenId += 3;
    }

    await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
    await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

    return { ERCX, hardhatERCX, owner, addr1, addr2, addr3, addr4 };
  }

  async function deployAndSubrentFixture() {
    const ERCX = await ethers.getContractFactory("ERCX_demo");
    const [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("ERCXCollection", "ERCX");
    await hardhatERCX.deployed();

    let tokenId = 0;
    while (tokenId < 3*3) {
      await hardhatERCX.mint(owner.address, tokenId);
      await hardhatERCX.mint(addr1.address, tokenId+1);
      await hardhatERCX.mint(addr2.address, tokenId+2);
      tokenId += 3;
    }

    await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);
    await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+250000)/1000));
    await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000));

    return { ERCX, hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 };
  }



  describe("Deployment", function () {

    it("Should mint 3 tokens per address", async function () {      
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      expect(await hardhatERCX.balanceOf(owner.address)).to.equal(3);
      expect(await hardhatERCX.balanceOf(addr1.address)).to.equal(3);
      expect(await hardhatERCX.balanceOf(addr2.address)).to.equal(3);
    });

  });



  describe("Layaway start", function () {

    it("Token owner should not be able to layaway", async function () {
      const { hardhatERCX, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1).startLayaway(1, addr2.address, Math.round((Date.now()+300000)/1000)))
        .to.be.revertedWith("ERCX: Can be called only by address approved for layaway");

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);
    });

    it("Approved address should be able to layaway", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(owner).approveLayawayControl(addr1.address, 0);
      await hardhatERCX.connect(addr1).startLayaway(0, addr2.address, Math.round((Date.now()+300000)/1000));

      expect(await hardhatERCX.ownerOf(0)).to.equal(addr2.address);
    });

    it("Unapproved address should not be able to layaway", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .startLayaway(0, addr2.address, Math.round((Date.now()+300000)/1000)))
        .to.be.revertedWith("ERCX: Can be called only by address approved for layaway");
    });

    it("Tokens should not be sublayawayed", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndLayawayFixture);

      await expect(hardhatERCX.connect(owner)
        .startLayaway(1, owner.address, Math.round((Date.now()+30000)/1000)))
        .to.be.revertedWith("ERCX: Cannot start layaway on a layawayed or rented token");
    });

    it("Rented token should not be layawayed", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+30000)/1000), true, true);

      await expect(hardhatERCX.connect(addr2).approveLayawayControl(owner.address, 1))
        .to.be.revertedWith("ERCX: cannot approve layawayed or rented token");

      await expect(hardhatERCX.connect(addr2)
        .startLayaway(1, owner.address, Math.round((Date.now()+30000)/1000)))
        .to.be.revertedWith("ERCX: Can be called only by address approved for layaway");
    });

    it("Layaway deadline should not be set in the past", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address, 1);
      await expect(hardhatERCX.connect(owner)
        .startLayaway(1, addr2.address, Math.round((Date.now()-30000)/1000)))
        .to.be.revertedWith("ERCX: layaway deadline expired yet");
    });

    it("Should not Layaway to the zero address", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address, 1);
      await expect(hardhatERCX.connect(owner)
        .startLayaway(1, ethers.constants.AddressZero, Math.round((Date.now()+30000)/1000)))
        .to.be.revertedWith("ERCX: cannot layaway to the zero address");
    });

  });

  

  describe("Layaway update", function () {
    
    it("Token layawayer should not be able to update deadline", async function () {
      const { hardhatERCX, addr1 } = await loadFixture(deployAndLayawayFixture);

      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await expect(hardhatERCX.connect(addr1).updateLayaway(1, newDeadline))
        .to.be.revertedWith("ERCX: Can be called only by address approved for layaway");

      //var deadline = await hardhatERCX.getLayawayDeadline(1);
      //expect(deadline).to.equal(newDeadline);
    });

    it("Approved address should be able to update deadline", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address,  1);
      await hardhatERCX.connect(owner).startLayaway(1, addr2.address, Math.round((Date.now()+300000)/1000));
      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await hardhatERCX.connect(owner).updateLayaway(1, newDeadline);

      var deadline = await hardhatERCX.getLayawayDeadline(1);
      expect(deadline).to.equal(newDeadline);
    });
    
    it("Unapproved address should not be able to update deadline", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndLayawayFixture);

      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await expect(hardhatERCX.connect(addr3).updateLayaway(1, newDeadline))
        .to.be.revertedWith("ERCX: Can be called only by address approved for layaway");

    });

    it("Deadline should not be anticipated", async function () {
      const { hardhatERCX, owner } = await loadFixture(deployAndLayawayFixture);

      let newDeadline = Math.round((Date.now() + 100000)/1000);
      await expect(hardhatERCX.connect(owner).updateLayaway(1, newDeadline))
        .to.be.revertedWith("ERCX: Cannot anticipate deadline");

    });
  });



  describe("Layaway termination", function () {

    it("Layaway should not be terminated before deadline", async function () {
      const { hardhatERCX } = await loadFixture(deployAndLayawayFixture);

      await expect(hardhatERCX.endLayaway(1, false)).to.be.revertedWith("ERCX: layaway not expired yet");
    });

    it("Approved address should be able to end layaway after deadline; token should be returned if layaway payment was not completed", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      let deadline = (Date.now()+15000)/1000;
      //console.log("deadline: %s", deadline);
      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address,  1);
      await hardhatERCX.connect(owner).startLayaway(1, addr2.address, Math.round(deadline));
      await time.increase(20);
      
      //console.log("Before endLayaway call: %s", Date.now());
      await hardhatERCX.endLayaway(1, false);
      //console.log("After endLayaway call: %s", Date.now());

      await expect(hardhatERCX.getLayawayDeadline(1)).to.be.revertedWith("ERCX: Token must be currently layawayed");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);
    });

    it("Approved address should be able to end layaway after deadline; token should not be returned if layaway payment was completed", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      let deadline = (Date.now()+15000)/1000;
      //console.log("deadline: %s", deadline);
      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address,  1);
      await hardhatERCX.connect(owner).startLayaway(1, addr2.address, Math.round(deadline));
      await time.increase(20);
      
      //console.log("Before endLayaway call: %s", Date.now());
      await hardhatERCX.endLayaway(1, true);
      //console.log("After endLayaway call: %s", Date.now());

      await expect(hardhatERCX.getLayawayDeadline(1)).to.be.revertedWith("ERCX: Token must be currently layawayed");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);
    });

    it("Unapproved address should be not able to end layaway (even if deadline expired)", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      let deadline = (Date.now()+15000)/1000;
      //console.log("deadline: %s", deadline);
      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address,  1);
      await hardhatERCX.connect(owner).startLayaway(1, addr2.address, Math.round(deadline));
      await time.increase(20);
      
      //console.log("Before endLayaway call: %s", Date.now());
      await expect(hardhatERCX.connect(addr2).endLayaway(1, true)).to.be
        .revertedWith("ERCX: layaway can be terminated only by approved address");
    });

  });



  describe("Transfers during Layaway", function () {

    it("Layawayed token should be transferable by layaway receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndLayawayFixture);

      await hardhatERCX.connect(addr2).approveLayawayTransfer(owner.address, 1);

      await hardhatERCX.connect(owner).transferLayawayedToken(addr3.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

      await time.increase(500);

      await hardhatERCX.connect(owner).endLayaway(1, true);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

    });

    it("Layawayed token should be transferable by address approved by layaway provider", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndLayawayFixture);

      await hardhatERCX.connect(addr1).approveLayawayTransfer(owner.address, 1);

      await hardhatERCX.connect(owner).transferLayaway(addr3.address, 1);

      expect(await hardhatERCX.getLayawayProvider(1)).to.equal(addr3.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);

      await time.increase(500);

      await hardhatERCX.connect(owner).endLayaway(1, false);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

    });

    it("Layawayed token should be transferable by layaway provider", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndLayawayFixture);

      await hardhatERCX.connect(addr1).transferLayaway(addr3.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);

      await time.increase(500);

      await hardhatERCX.connect(owner).endLayaway(1, false);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

    });

    it("Layawayed token should be transferable by address approved by layaway receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndLayawayFixture);

      await hardhatERCX.connect(addr2).approveLayawayTransfer(owner.address, 1);

      await hardhatERCX.connect(owner).transferLayawayedToken(addr3.address, 1);

      expect(await hardhatERCX.getLayawayProvider(1)).to.equal(addr1.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

      await time.increase(500);

      await hardhatERCX.connect(owner).endLayaway(1, false);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);

    });

  });


  
  describe("Rental start", function () {
    
    it("Token owner should be able to rent", async function () {
      const { hardhatERCX, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);
    });

    it("Approved address should be able to rent", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(owner).approveRentalControl(0, addr1.address);
      await hardhatERCX.connect(addr1).startRental(0, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      expect(await hardhatERCX.ownerOf(0)).to.equal(addr2.address);
    });

    it("Unapproved address should not be able to rent", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .startRental(0, addr2.address, Math.round((Date.now()+300000)/1000), true, true))
        .to.be.revertedWith("ERCX: Can be called only by owner or address approved for rental");
    });

    it("Tokens should be subrented", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndRentFixture);

      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+30000)/1000));

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);
    });

    it("Layawayed token should not be rented", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndLayawayFixture);

      await expect(hardhatERCX.connect(addr2)
        .startRental(1, owner.address, Math.round((Date.now()+30000)/1000), true, true))
        .to.be.revertedWith("ERCX: Cannot start rental on a layawayed token");
    });

    it("Rental deadline should not be set in the past", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .startRental(1, addr2.address, Math.round((Date.now()-30000)/1000), true, true))
        .to.be.revertedWith("ERCX: Rental deadline expired yet");
    });

    it("Should not rent to the zero address", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .startRental(1, ethers.constants.AddressZero, Math.round((Date.now()+30000)/1000), true, true))
        .to.be.revertedWith("ERCX: cannot rent to the zero address");
    });

    it("Tokens should not be subrented to an account that is currently renting them", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndRentFixture);

      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+100000)/1000));

      await expect(hardhatERCX.connect(addr3).startSubrental(1, addr1.address, Math.round((Date.now()+50000)/1000)))
        .to.be.revertedWith("ERCX: cannot rent token to an account that previously rented it");
    });

    it("Tokens should not be subrented for a period longer than existing rental period", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4 } = await loadFixture(deployAndRentFixture);

      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+100000)/1000));

      await expect(hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000)))
        .to.be.revertedWith("ERCX: Cannot subrent for a period longer than your rental period");
    });

  });
  
  
  
  describe("Rental update", function () {

    it("Token ex owner should be able to update deadline", async function () {
      const { hardhatERCX, addr1 } = await loadFixture(deployAndRentFixture);

      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await hardhatERCX.connect(addr1).updateRental(1, newDeadline, addr1.address);

      var deadline = await hardhatERCX.getRentalDeadline(1, addr1.address);
      expect(deadline).to.equal(newDeadline);
    });

    it("Approved address should be able to update deadline", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndRentFixture);

      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await hardhatERCX.connect(owner).updateRental(1, newDeadline, addr1.address);

      var deadline = await hardhatERCX.getRentalDeadline(1, addr1.address);
      expect(deadline).to.equal(newDeadline);
    });
    
    it("Unapproved address should not be able to update deadline", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndRentFixture);

      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await expect(hardhatERCX.connect(addr3).updateRental(1, newDeadline, addr1.address))
        .to.be.revertedWith("ERCX: Can be called only by renter or address approved for rental");

    });

    it("Deadline should not be anticipated", async function () {
      const { hardhatERCX, owner, addr1 } = await loadFixture(deployAndRentFixture);

      let newDeadline = Math.round((Date.now() + 100000)/1000);
      await expect(hardhatERCX.connect(owner).updateRental(1, newDeadline, addr1.address))
        .to.be.revertedWith("ERCX: Cannot anticipate deadline");

    });

    it("Subrent deadline should not be anticipated", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndRentFixture);

      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+100000)/1000));

      let newDeadline = Math.round((Date.now() + 50000)/1000);
      await expect(hardhatERCX.connect(addr2).updateRental(1, newDeadline, addr2.address))
        .to.be.revertedWith("ERCX: Cannot anticipate deadline");

    });

    it("Subrent deadline should not be updated for a period longer than existing rental period", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndRentFixture);

      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+100000)/1000));

      let newDeadline = Math.round((Date.now() + 500000)/1000);
      await expect(hardhatERCX.connect(owner).updateRental(1, newDeadline, addr2.address))
        .to.be.revertedWith("ERCX: Cannot set subrent deadline after your rental deadline");

    });

    it("Subrent deadline should be updated for a period shorter than existing rental period", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndRentFixture);

      await hardhatERCX.connect(addr2).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startSubrental(1, addr3.address, Math.round((Date.now()+100000)/1000));

      let newDeadline = Math.round((Date.now() + 150000)/1000);
      await hardhatERCX.connect(owner).updateRental(1, newDeadline, addr2.address);

      var deadline = await hardhatERCX.getRentalDeadline(1, addr2.address);
      expect(deadline).to.equal(newDeadline);
    });
  });
  
  
  
  describe("Rental termination", function () {

    it("Rental should not be terminated before deadline", async function () {
      const { hardhatERCX, addr1 } = await loadFixture(deployAndRentFixture);

      await expect(hardhatERCX.endRental(1, addr1.address)).to.be.revertedWith("ERCX: rental not expired yet");
    });

    it("Subrental should not be terminated before deadline", async function () {
      const { hardhatERCX, addr1, addr2 } = await loadFixture(deployAndSubrentFixture);

      await expect(hardhatERCX.endRental(1, addr2.address)).to.be.revertedWith("ERCX: rental not expired yet");
    });

    it("Any address should be able to end rental after deadline and token should be returned to ex owner", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndMintFixture);

      let deadline = (Date.now()+15000)/1000;
      //console.log("deadline: %s", deadline);
      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round(deadline), true, true);
      await time.increase(20);
      
      //console.log("Before endLayaway call: %s", Date.now());
      await hardhatERCX.connect(addr3).endRental(1, addr1.address);
      //console.log("After endLayaway call: %s", Date.now());

      await expect(hardhatERCX.getRentalDeadline(1, addr1.address)).to.be.revertedWith("ERCX: Token must be currently rented");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);
    });

    it("Any address should be able to end subrental after deadline and token should be returned to correct owner", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4 } = await loadFixture(deployAndSubrentFixture);

      await time.increase(400);
      
      //console.log("Before endLayaway call: %s", Date.now());
      await hardhatERCX.connect(owner).endRental(1, addr1.address);
      //console.log("After endLayaway call: %s", Date.now());

      await expect(hardhatERCX.getRentalDeadline(1, addr1.address)).to.be.revertedWith("ERCX: Token must be currently rented");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);

      var timestamp = Date.now() + 400000;


      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((timestamp+300000)/1000), true, true);
      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((timestamp+250000)/1000));
      await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((timestamp+200000)/1000));


      await time.increase(275);

      await hardhatERCX.connect(owner).endRental(1, addr2.address);

      await expect(hardhatERCX.getRentalDeadline(1, addr2.address)).to.be.revertedWith("ERCX: Specified rental does not exist");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);

      await hardhatERCX.connect(addr1).updateRental(1, Math.round((timestamp+999999999)/1000), addr1.address);

      timestamp = Date.now() + 400000 + 275000;

      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((timestamp+250000)/1000));
      await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((timestamp+200000)/1000));


      await time.increase(999999999);
      await hardhatERCX.connect(owner).endRental(1, addr1.address);

      await expect(hardhatERCX.getRentalDeadline(1, addr1.address)).to.be.revertedWith("ERCX: Token must be currently rented");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);
    });

    it("Rental termination should delete approvals of terminated rentals providers", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      var timestamp = Date.now();

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((timestamp+300000)/1000), true, true);

      await hardhatERCX.connect(addr2).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startSubrental(1, addr3.address, Math.round((timestamp+200000)/1000));

      await hardhatERCX.connect(addr3).approveRentalControl(1, addr5.address);
      await hardhatERCX.connect(addr5).startSubrental(1, addr4.address, Math.round((timestamp+100000)/1000));

      await time.increase(250);

      await hardhatERCX.endRental(1, addr2.address);

      await expect(hardhatERCX.connect(addr5).startSubrental(1, addr4.address, Math.round((timestamp+250000+25000)/1000)))
        .to.be.revertedWith("ERCX: Can be called only by owner or address approved for rental");
      
    });

  });



  describe("Transfers during rental", function () {

    it("Rented token should be transferable by rental receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await hardhatERCX.connect(addr2).transferRentedToken(addr3.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

      await time.increase(500);

      await hardhatERCX.endRental(1, addr1.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);

    });

    it("Rented token should be transferable by subrental receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);
      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+250000)/1000));
      await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000));

      await hardhatERCX.connect(addr4).transferRentedToken(addr5.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr5.address);

      await time.increase(500);

      await hardhatERCX.endRental(1, addr3.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

    });
    
    it("Rented token should be transferable by address approved by rental receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await hardhatERCX.connect(addr2).approveRentalTransfer(owner.address, 1);

      await hardhatERCX.connect(owner).transferRentedToken(addr5.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr5.address);

      await time.increase(500);

      await hardhatERCX.endRental(1, addr1.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);

    });
    
    it("Rented token should be transferable by address aprroved by subrental receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);
      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+250000)/1000));
      await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000));

      await hardhatERCX.connect(addr4).approveRentalTransfer(owner.address, 1);

      await hardhatERCX.connect(owner).transferRentedToken(addr5.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr5.address);

      await time.increase(500);

      await hardhatERCX.endRental(1, addr2.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);

    });

    it("Rented token should be transferable by rental provider", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await hardhatERCX.connect(addr1).transferRental(addr3.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);

      await time.increase(500);

      await hardhatERCX.endRental(1, addr3.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

    });

    it("Rented token should be transferable by subrental provider", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);
      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+250000)/1000));
      await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000));

      await hardhatERCX.connect(addr3).transferRental(addr5.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);

      await time.increase(500);

      await hardhatERCX.endRental(1, addr5.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr5.address);

    });

    it("Rented token should be transferable by address approved by rental provider", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await hardhatERCX.connect(addr1).approveRentalTransfer(owner.address, 1);

      await hardhatERCX.connect(owner).transferRental(addr3.address, 1);

      //expect(await hardhatERCX.getLayawayProvider(1)).to.equal(addr3.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);

      await time.increase(500);

      await hardhatERCX.endRental(1, addr3.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

    });

    it("Subrented token should be transferable by address approved by rental provider", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);
      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+250000)/1000));
      await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000));

      await hardhatERCX.connect(addr3).approveRentalTransfer(owner.address, 1);

      await hardhatERCX.connect(owner).transferRental(addr5.address, 1);

      //expect(await hardhatERCX.getLayawayProvider(1)).to.equal(addr5.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);

      await time.increase(500);

      await hardhatERCX.endRental(1, addr5.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr5.address);

    });

  });



  describe("Rented token cession", function () {

    it("Rental provider should be able to cede rented token to rental receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await hardhatERCX.connect(addr1).cedeRentedToken(1);

      await expect(hardhatERCX.getRentalDeadline(1, addr1.address)).to.be.revertedWith("ERCX: Token must be currently rented");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);
    });

    it("Address approved by rental provider should be able to cede rented token to rental receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await hardhatERCX.connect(owner).cedeRentedToken(1);

      await expect(hardhatERCX.getRentalDeadline(1, addr1.address)).to.be.revertedWith("ERCX: Token must be currently rented");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);
    });

    /** 
    it("Last subrental level provider should be able to cede rented token to subrental receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);
      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+250000)/1000));
      await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000));

      await hardhatERCX.connect(addr3).cedeRentedToken(1);

      await expect(hardhatERCX.getRentalDeadline(1, addr3.address)).to.be.revertedWith("ERCX: Specified rental does not exist");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);
    });

    it("Address approved by last subrental level provider should be able to cede rented token to subrental receiver", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);
      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+250000)/1000));
      
      await hardhatERCX.connect(addr3).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000));

      await hardhatERCX.connect(owner).cedeRentedToken(1);

      await expect(hardhatERCX.getRentalDeadline(1, addr3.address)).to.be.revertedWith("ERCX: Specified rental does not exist");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);
    });*/

    it("Intermediate subrental level provider should not be able to cede rented token", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);
      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+250000)/1000));
      await hardhatERCX.connect(addr3).startSubrental(1, addr4.address, Math.round((Date.now()+200000)/1000));

      await expect(hardhatERCX.connect(addr2).cedeRentedToken(1))
        .to.be.revertedWith("ERCX: Unrented or subrented tokens cannot be sold");
    });

    it("Unapproved address should not be able to cede rented token", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await expect(hardhatERCX.connect(addr3).cedeRentedToken(1))
        .to.be.revertedWith("ERCX: can be called only by rental provider or address approved for rental");
    });

  });
  
  

  describe("Transfer", function () {

    it("Layawayed token should not be transferable", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address, 1);
      await hardhatERCX.connect(owner).startLayaway(1, addr2.address, Math.round((Date.now()+300000)/1000));

      await expect(hardhatERCX.connect(addr2).transferFrom(addr2.address, owner.address, 1)).to.be.revertedWith("ERCX: use transferLayawayedToken function to transfer a layawayed token");
    });

    it("Rented token should not be transferable", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await expect(hardhatERCX.connect(addr2).transferFrom(addr2.address, owner.address, 1)).to.be.revertedWith("ERCX: Cannot transfer rented token. If rental expired call endRental before");
    });

  });



  describe("Approval", function () {

    it("Layawayed token should not be approved (also for rental and layaway)", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address, 1);
      await hardhatERCX.connect(owner).startLayaway(1, addr2.address, Math.round((Date.now()+300000)/1000));

      await expect(hardhatERCX.connect(addr2).approve(owner.address, 1)).to.be.revertedWith("ERCX: cannot approve layawayed or rented token");
      await expect(hardhatERCX.connect(addr2).approveLayawayControl(owner.address, 1)).to.be.revertedWith("ERCX: cannot approve layawayed or rented token");
      await expect(hardhatERCX.connect(addr2).approveRentalControl(1, owner.address)).to.be.revertedWith("ERCX: Cannot rent layawayed token");
    });

    it("Rented token should not be approved (also for layaway)", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await expect(hardhatERCX.connect(addr2).approve(owner.address, 1)).to.be.revertedWith("ERCX: cannot approve layawayed or rented token");
      await expect(hardhatERCX.connect(addr2).approveLayawayControl(owner.address, 1)).to.be.revertedWith("ERCX: cannot approve layawayed or rented token");
    });

    it("Rented token should be approved for subrental", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await hardhatERCX.connect(addr2).approveRentalControl(1, owner.address);

      expect(await hardhatERCX.getRentalApproved(1, addr2.address)).to.equal(owner.address);
    });

    it("Free token should be approved (also for rental and layaway)", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approve(owner.address, 1);
      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address, 1);
      await hardhatERCX.connect(addr1).approveRentalControl(1, owner.address)

      expect(await hardhatERCX.getApproved(1)).to.equal(owner.address);
      expect(await hardhatERCX.getLayawayApproved(1)).to.equal(owner.address);
      expect(await hardhatERCX.getRentalApproved(1, addr1.address)).to.equal(owner.address);
    });
  });



  describe("Misc", function () {

    it("Token layaway and rental operations should not interfere with each other", async function () {
      const { hardhatERCX, owner, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);
      
      var timestamp = Date.now();

      await hardhatERCX.connect(addr1).approveLayawayControl(owner.address, 1);
      await hardhatERCX.connect(owner).startLayaway(1, addr2.address, Math.round((timestamp+300000)/1000));

      let newDeadline = Math.round((timestamp + 600000)/1000);
      await hardhatERCX.connect(owner).updateLayaway(1, newDeadline);
      var deadline = await hardhatERCX.getLayawayDeadline(1);
      expect(deadline).to.equal(newDeadline);

      await hardhatERCX.connect(addr2).approveLayawayTransfer(owner.address, 1);
      await hardhatERCX.connect(owner).transferLayawayedToken(addr4.address, 1);
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);

      await hardhatERCX.connect(addr1).approveLayawayTransfer(owner.address, 1);
      await expect(hardhatERCX.connect(owner).transferLayaway(addr4.address, 1))
        .to.be.revertedWith("ERCX: Cannot transfer to layaway receiver");
      await hardhatERCX.connect(owner).transferLayaway(addr3.address, 1);
      expect(await hardhatERCX.getLayawayProvider(1)).to.equal(addr3.address);
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);

      await time.increase(650);
      await hardhatERCX.connect(owner).endLayaway(1, true);
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);

      await hardhatERCX.connect(addr4).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startRental(1, addr3.address, Math.round((timestamp+650000+300000)/1000), true, true);
      await hardhatERCX.connect(addr3).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startSubrental(1, addr2.address, Math.round((timestamp+650000+200000)/1000));
      await hardhatERCX.connect(addr2).approveRentalControl(1, owner.address);
      await hardhatERCX.connect(owner).startSubrental(1, addr1.address, Math.round((timestamp+650000+100000)/1000));

      await time.increase(150);
      await hardhatERCX.endRental(1, addr2.address);
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);

      await hardhatERCX.connect(addr2).startSubrental(1, addr5.address, Math.round((timestamp+650000+150000 + 50000)/1000));
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr5.address);
      await time.increase(150);
      await hardhatERCX.endRental(1, addr2.address);
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);


      await time.increase(999999999);
      await hardhatERCX.endRental(1, addr4.address);
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);
    });

  });



  describe("Rental allowances", function () {
    
    it("First rental provider of a token should be able to forbid subrentals and transfers furing rental", async function () {
      const { hardhatERCX, addr1, addr2, addr3 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), false, false);

      await expect(hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+200000)/1000)))
        .to.be.revertedWith("ERCX: Subrental is not allowed on this token");

      await expect(hardhatERCX.connect(addr2).transferRentedToken(addr3.address, 1))
        .to.be.revertedWith("ERCX: transfers during rental not allowed on this token");
      
      await expect(hardhatERCX.connect(addr1).transferRental(addr3.address, 1))
        .to.be.revertedWith("ERCX: transfers during rental not allowed on this token");
    });

    it("First rental provider of a token should be able to allow subrentals and transfers furing rental", async function () {
      const { hardhatERCX, addr1, addr2, addr3, addr4, addr5 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startRental(1, addr2.address, Math.round((Date.now()+300000)/1000), true, true);

      await hardhatERCX.connect(addr2).startSubrental(1, addr3.address, Math.round((Date.now()+200000)/1000));

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr3.address);

      await hardhatERCX.connect(addr3).transferRentedToken(addr4.address, 1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr4.address);

      await hardhatERCX.connect(addr2).transferRental(addr5.address, 1);

      await time.increase(250);

      await hardhatERCX.endRental(1, addr5.address);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr5.address);
    });

  });


});