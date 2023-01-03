const { ethers } = require("hardhat");
const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const setTimeout = require("timers/promises").setTimeout;


describe("ERCX contract", function () {

  async function deployFixture() {
    const ERCX = await ethers.getContractFactory("ERCXDemo");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("ERCXCollection", "ERCX");
    await hardhatERCX.deployed();

    return { ERCX, hardhatERCX, owner, addr1, addr2 };
  }

  async function deployAndMintFixture() {
    const ERCX = await ethers.getContractFactory("ERCXDemo");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("ERCXCollection", "ERCX");
    await hardhatERCX.deployed();

    let tokenId = 0;
    while (tokenId < 3*3) {
      await hardhatERCX.mint(owner.address, tokenId);
      await hardhatERCX.mint(addr1.address, tokenId+1);
      await hardhatERCX.mint(addr2.address, tokenId+2);
      tokenId += 3;
    }

    return { ERCX, hardhatERCX, owner, addr1, addr2 };
  }

  async function deployAndRentFixture() {
    const ERCX = await ethers.getContractFactory("ERCXDemo");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("ERCXCollection", "ERCX");
    await hardhatERCX.deployed();

    let tokenId = 0;
    while (tokenId < 3*3) {
      await hardhatERCX.mint(owner.address, tokenId);
      await hardhatERCX.mint(addr1.address, tokenId+1);
      await hardhatERCX.mint(addr2.address, tokenId+2);
      tokenId += 3;
    }

    await hardhatERCX.connect(addr1).rent(addr2.address, 1, Math.round((Date.now()+300000)/1000));

    return { ERCX, hardhatERCX, owner, addr1, addr2 };
  }



  describe("Deployment", function () {

    it("Should mint 3 tokens per address", async function () {      
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      expect(await hardhatERCX.balanceOf(owner.address)).to.equal(3);
      expect(await hardhatERCX.balanceOf(addr1.address)).to.equal(3);
      expect(await hardhatERCX.balanceOf(addr2.address)).to.equal(3);
    });

  });



  describe("Rental", function () {

    it("Token owner should be able to rent", async function () {
      const { hardhatERCX, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).rent(addr2.address, 1, Math.round((Date.now()+30000)/1000));

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);
    });

    it("Approved address should be able to rent", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(owner).approveRentalControl(addr1.address, 0);
      await hardhatERCX.connect(addr1).rent(addr2.address, 0, Math.round((Date.now()+30000)/1000));

      expect(await hardhatERCX.ownerOf(0)).to.equal(addr2.address);
    });

    it("Unapproved address should not be able to rent", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .rent(addr2.address, 0, Math.round((Date.now()+30000)/1000)))
        .to.be.revertedWith("ERCX: Can be called only by owner or address approved for rental");
    });

    it("Tokens should not be subrented", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndRentFixture);

      await expect(hardhatERCX.connect(addr2)
        .rent(owner.address, 1, Math.round((Date.now()+30000)/1000)))
        .to.be.revertedWith("ERCX: Cannot subrent");
    });

    it("Rental deadline should not be set in the past", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .rent(addr2.address, 1, Math.round((Date.now()-30000)/1000)))
        .to.be.revertedWith("ERCX: Rental deadline expired yet");
    });

    it("Should not rent to the zero address", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .rent(ethers.constants.AddressZero, 1, Math.round((Date.now()+30000)/1000)))
        .to.be.revertedWith("ERCX: cannot rent to the zero address");
    });

  });

  


  describe("Deadline update", function () {
    it("Token renter should be able to update deadline", async function () {
      const { hardhatERCX, addr1 } = await loadFixture(deployAndRentFixture);

      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await hardhatERCX.connect(addr1).deadlineUpdate(1, newDeadline);

      var [exOwner, deadline] = await hardhatERCX.rentalInfo(1);
      expect(deadline).to.equal(newDeadline);
    });

    it("Approved address should be able to update deadline", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveRentalControl(owner.address,  1);
      await hardhatERCX.connect(owner).rent(addr2.address, 1, Math.round((Date.now()+300000)/1000));
      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await hardhatERCX.connect(owner).deadlineUpdate(1, newDeadline);

      var [exOwner, deadline] = await hardhatERCX.rentalInfo(1);
      expect(deadline).to.equal(newDeadline);
    });
    
    it("Unapproved address should not be able to update deadline", async function () {
      const { hardhatERCX, owner } = await loadFixture(deployAndRentFixture);

      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await expect(hardhatERCX.connect(owner).deadlineUpdate(1, newDeadline))
        .to.be.revertedWith("ERCX: Can be called only by renter or address approved for rental");

    });

    it("Deadline should not be anticipated", async function () {
      const { hardhatERCX, owner } = await loadFixture(deployAndRentFixture);

      let newDeadline = Math.round((Date.now() + 600000)/1000);
      await expect(hardhatERCX.connect(owner).deadlineUpdate(1, newDeadline))
        .to.be.revertedWith("ERCX: Can be called only by renter or address approved for rental");

    });
  });





  describe("Rental termination", function () {

    it("Rental should not be terminated before deadline", async function () {
      const { hardhatERCX } = await loadFixture(deployAndRentFixture);

      await expect(hardhatERCX.endRental(1)).to.be.revertedWith("ERCX: Rental not expired yet");
    });

    it("Rental should be terminated after deadline", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).rent(addr2.address, 1, Math.round((Date.now()+15000)/1000));
      await setTimeout(16000);
      await hardhatERCX.endRental(1);

      await expect(hardhatERCX.rentalInfo(1)).to.be.revertedWith("ERCX: Token must be currently rented");
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);
    });

  });





  describe("Transfer", function () {

    it("Rented token should not be transferable", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndRentFixture);

      await expect(hardhatERCX.connect(addr2).transferFrom(addr2.address, owner.address, 1)).to.be.revertedWith("ERCX: Cannot trasfer rented token. If rental expired call endRental before");
    });
  });




  describe("Approval", function () {
    it("Rented token should not be approved", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndRentFixture);

      await expect(hardhatERCX.connect(addr2).approve(owner.address, 1)).to.be.revertedWith("ERCX: Cannot approve rented token");
      await expect(hardhatERCX.connect(addr2).approveRentalControl(owner.address, 1)).to.be.revertedWith("ERCX: Cannot approve rented token");
    });

    it("Unrented token should be approved", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approve(owner.address, 1);
      await hardhatERCX.connect(addr1).approveRentalControl(owner.address, 1);

      expect(await hardhatERCX.getApproved(1)).to.equal(owner.address);
      expect(await hardhatERCX.getRentalApproved(1)).to.equal(owner.address);
    });
  });

});