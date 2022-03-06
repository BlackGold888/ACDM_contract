import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { ethers, network } from "hardhat";

describe("ACDM Platform", function () {
  let ACDMToken: ContractFactory;
  let acdmTokneInstance: Contract;
  let ACDMPlatform: ContractFactory;
  let acdmPlatformInstance: Contract;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addr3: SignerWithAddress;
  beforeEach(async () => {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    ACDMToken = await ethers.getContractFactory("ACDMToken");
    acdmTokneInstance = await ACDMToken.deploy();
    await acdmTokneInstance.deployed();

    ACDMPlatform = await ethers.getContractFactory('ACDMPlatform');
    acdmPlatformInstance = await ACDMPlatform.deploy(acdmTokneInstance.address, 259200)// 3 days
    await acdmPlatformInstance.deployed();
    await acdmTokneInstance.transferOwnership(acdmPlatformInstance.address);
  });

  it("Register on platform", async function () {
    await acdmPlatformInstance.connect(addr1).register(addr2.address);
    expect(await acdmPlatformInstance.connect(addr1).getReferrer()).to.equal(addr2.address);
  });

  it("startSaleRound", async function() {
    await acdmPlatformInstance.connect(addr1).register(addr2.address);
    await acdmPlatformInstance.startSaleRound();
    await acdmPlatformInstance.connect(addr1).buyACDM(1000, {value: ethers.utils.parseEther("100")});
    expect(await acdmTokneInstance.connect(owner).balanceOf(addr1.address)).to.equal(ethers.utils.parseEther("1000"));
  })

  it("startTradeRound", async function() {
    await acdmPlatformInstance.startSaleRound();
    await network.provider.send("evm_increaseTime", [259200]);// 3 days
    await acdmPlatformInstance.startTradeRound();
    expect(await acdmPlatformInstance.getStatusRound()).to.equal(1);
  })

  it("addOrder", async function() {
    await acdmPlatformInstance.connect(addr1).register(addr2.address);
    await acdmPlatformInstance.startSaleRound();
    await acdmPlatformInstance.connect(addr3).buyACDM(1000, {value: ethers.utils.parseEther("100")});
    await network.provider.send("evm_increaseTime", [259200]);// 3 days
    await acdmPlatformInstance.startTradeRound();
    await acdmTokneInstance.connect(addr3).approve(acdmPlatformInstance.address, ethers.utils.parseUnits("1000", 18));
    await acdmPlatformInstance.connect(addr3).addOrder(1000, ethers.utils.parseUnits("0.01", 18));
    await acdmPlatformInstance.connect(addr2).reedemOrder(1, 1000, {value: ethers.utils.parseEther("10")});
    expect(await acdmTokneInstance.balanceOf(addr2.address)).to.equal(ethers.utils.parseEther("1000"));
  })
});
