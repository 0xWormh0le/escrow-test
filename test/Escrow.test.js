const chai = require("chai")
const { solidity } = require("ethereum-waffle")
const { BigNumber, ethers } = require("hardhat")
const { expect } = chai

chai.use(solidity)

const expiration = 3600

const increaseTime = async duration => {
  await ethers.provider.send("evm_increaseTime", [duration]);
  await ethers.provider.send("evm_mine");
}

describe("Escrow", function () {
  beforeEach(async function () {
    const Escrow = await ethers.getContractFactory("Escrow")
    
    this.escrow = await Escrow.deploy(expiration)
    await this.escrow.deployed();

    const users = await ethers.getSigners()
    this.owner = users[0]
    this.approver = users[1]
    this.depositor = users[2]
    this.receiver = users[3]

    const withOwner = await this.escrow.connect(this.owner)
    await withOwner.addApprover(this.approver.address);
  })

  it("works", async function () {
    const withDepositor = await this.escrow.connect(this.depositor)
    const withApprover = await this.escrow.connect(this.approver)
    const withReceiver = await this.escrow.connect(this.receiver)

    // first deposit for approval
    await expect(withDepositor.depositFor(
      100,
      this.receiver.address,
      this.approver.address,
      { value: 100 }
    )).to.emit(withDepositor, "Deposited")
      .withArgs(100, this.receiver.address, this.approver.address);

    // second deposit for refund
    await withDepositor.depositFor(
      50,
      this.receiver.address,
      this.approver.address,
      { value: 50 }
    );

    // third deposit for reclaim expired

    await withDepositor.depositFor(
      75,
      this.receiver.address,
      this.approver.address,
      { value: 75 }
    );

    // check mismatch amount when depositFor

    await expect(withDepositor.depositFor(
      75,
      this.receiver.address,
      this.approver.address,
      { value: 10 }
    )).to.be.revertedWith("Amount mismatch")

    // get ether balance

    const receiverBalance = await ethers.provider.getBalance(this.receiver.address)
    const depositorBalance = await ethers.provider.getBalance(this.depositor.address)

    // check approve

    await expect(withApprover.approve(1))
      .to.emit(withApprover, "Approved")
      .withArgs(100, this.receiver.address)

    // check receiver received escrow after approval
 
    expect(await ethers.provider.getBalance(this.receiver.address))
      .to.equal(receiverBalance.add(100))

    // check refund

    await expect(withApprover.refund(2))
      .to.emit(withApprover, "Refunded")
      .withArgs(50, this.depositor.address, this.receiver.address)

    // check depositor got refund

    expect(await ethers.provider.getBalance(this.depositor.address))
      .to.equal(depositorBalance.add(50))

    // check reclaimExpired before expiration to reclaim nothing

    await expect(withDepositor.reclaimExpired())
      .to.emit(withDepositor, "Reclaimed")
      .withArgs(0, this.depositor.address)

    // check reclaimExpired after expiration

    await increaseTime(4000)

    await expect(withDepositor.reclaimExpired())
      .to.emit(withDepositor, "Reclaimed")
      .withArgs(75, this.depositor.address)

    // check approve reverted when id is invalid

    await expect(withApprover.approve(99))
      .to.be.revertedWith("Invalid id")

    // try to reapprove and it reverts

    await expect(withApprover.approve(1))
      .to.be.revertedWith("Deposit status already touched")
    
    // try to approve with non-approver

    await expect(withReceiver.approve(1))
      .to.be.revertedWith("You are not an approver")
  })
})
