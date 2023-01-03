const { ethers } = require("hardhat");
const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const setTimeout = require("timers/promises").setTimeout;


describe("ERCX_loan contract", function () {

  async function deployFixture() {
    const ERCX = await ethers.getContractFactory("ERCX_loan_demo");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("T", "T");
    await hardhatERCX.deployed();

    return { ERCX, hardhatERCX, owner, addr1, addr2 };
  }

  async function deployAndMintFixture() {
    const ERCX = await ethers.getContractFactory("ERCX_loan_demo");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const hardhatERCX = await ERCX.deploy("T", "T");
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

  async function deployAndLoanFixture() {
    const ERCX = await ethers.getContractFactory("ERCX_loan_demo");
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

    await hardhatERCX.connect(addr1).approveLoanControl(owner.address, 1);
    await hardhatERCX.connect(owner).startLoan(1, addr2.address, ethers.utils.parseEther("0.001"), 20, 2, { value: ethers.utils.parseEther("0.001") });

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



  describe("Loan", function () {

    it("Token owner should be able to loan", async function () {
      const { hardhatERCX, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).startLoan(1, addr2.address, ethers.utils.parseEther("0.001"), 20, 2);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);
    });

    it("Approved address should be able to loan paying first installment", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(owner).approveLoanControl(addr1.address, 0);
      await hardhatERCX.connect(addr1).startLoan(0, addr2.address, ethers.utils.parseEther("0.001"), 20, 2, { value: ethers.utils.parseEther("0.001") });

      expect(await hardhatERCX.ownerOf(0)).to.equal(addr2.address);
    });

    it("Approved address should not be able to loan without paying first installment", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(owner).approveLoanControl(addr1.address, 0);
      
      await expect(hardhatERCX.connect(addr1)
        .startLoan(0, addr2.address, ethers.utils.parseEther("0.001"), 20, 2, { value: ethers.utils.parseEther("0.0001") }))
        .to.be.revertedWith("ERCX: First installment must be paid to start the loan");
      
    });

    it("Unapproved address should not be able to loan", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .startLoan(0, addr2.address, ethers.utils.parseEther("0.001"), 20, 2))
        .to.be.revertedWith("ERCX: Can be called only by owner or address approved for loan");
    });

    it("Tokens should not be subloaned", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndLoanFixture);

      await expect(hardhatERCX.connect(addr2)
        .startLoan(1, owner.address, ethers.utils.parseEther("0.001"), 20, 2))
        .to.be.revertedWith("ERCX: Cannot subloan");
    });

    it("Should not loan to the zero address", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await expect(hardhatERCX.connect(addr1)
        .startLoan(1, ethers.constants.AddressZero, ethers.utils.parseEther("0.001"), 20, 2))
        .to.be.revertedWith("ERCX: cannot loan to the zero address");
    });

  });



  describe("Loan termination", function () {

    it("Loan should not be terminated before installment deadline", async function () {
      const { hardhatERCX } = await loadFixture(deployAndLoanFixture);

      await expect(hardhatERCX.endLoan(1)).to.be.revertedWith("ERCX: loan not yet terminated");
    });

    it("Loan should be terminated after installment deadline and token should be returned to loaner", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndLoanFixture);

      await setTimeout(25000);
      await hardhatERCX.endLoan(1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);
    });

    it("Loan should be terminated after all installments have been paid and token should be transfered to new owner", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndLoanFixture);

      await hardhatERCX.connect(addr2).payInstallment(1, { value: ethers.utils.parseEther("0.001") })
      await hardhatERCX.endLoan(1);

      expect(await hardhatERCX.ownerOf(1)).to.equal(addr2.address);
    });

    it("If user pays multiple installments before deadline, the loan should not be terminated for all the period that was paid and should be terminated afterfawrds", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndMintFixture);

      await hardhatERCX.connect(addr1).approveLoanControl(owner.address, 1);
      await hardhatERCX.connect(owner).startLoan(1, addr2.address, ethers.utils.parseEther("0.001"), 5, 5, { value: ethers.utils.parseEther("0.001") });
  

      for(var i = 0; i < 3; i++) { 
        await hardhatERCX.connect(addr2).payInstallment(1, { value: ethers.utils.parseEther("0.001") }) 
      }
      
      await expect(hardhatERCX.endLoan(1)).to.be.revertedWith("ERCX: loan not yet terminated");

      await setTimeout(10000);

      await expect(hardhatERCX.endLoan(1)).to.be.revertedWith("ERCX: loan not yet terminated");

      await setTimeout(10000);

      await hardhatERCX.endLoan(1);
      expect(await hardhatERCX.ownerOf(1)).to.equal(addr1.address);
    });

  });

  
  
  describe("Transfers", function () {

    it("Loaned token should not be ", async function () {
      const { hardhatERCX, owner, addr1, addr2 } = await loadFixture(deployAndRentFixture);

      await expect(hardhatERCX.connect(addr2).transferFrom(addr2.address, owner.address, 1)).to.be.revertedWith("ERCX: Cannot trasfer rented token. If rental expired call endRental before");
    });
  });


 
/** 
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
  */

});