import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe("Eutopia", function () {
  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("Eutopia");

    const [initialOwner, router, liquidityReceiver, treasuryReceiver, riskFreeValueReceiver] = await ethers.getSigners();

    const instance = await upgrades.deployProxy(ContractFactory, [
      initialOwner.address,
      router.address,
      liquidityReceiver.address,
      treasuryReceiver.address,
      riskFreeValueReceiver.address
    ]);
    await instance.deployed();

    expect(await instance.name()).to.equal("Eutopia");
  });
});