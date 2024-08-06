import { expect } from "chai";
import { ethers, upgrades, run } from "hardhat";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import dotenv from "dotenv";

dotenv.config();

const uniswapRouter = process.env.SEPOLIA_UNISWAP_ROUTER;

describe("Eutopia", function () {

  it("Test", async function () {
    const InstanceFactory = await ethers.getContractFactory("Eutopia");

    const [initialOwner, liquidityReceiver, treasuryReceiver, essrReceiver] = await ethers.getSigners();

    const instance = await upgrades.deployProxy(InstanceFactory, [
      await initialOwner.getAddress(),
      uniswapRouter,
      await liquidityReceiver.getAddress(),
      await treasuryReceiver.getAddress(),
      await essrReceiver.getAddress(),
    ]);
    await instance.waitForDeployment();

    const instanceAddress = await instance.getAddress();
    console.log("Proxy deployed to " + instanceAddress);

    const implementationAddress = await getImplementationAddress(ethers.provider, instanceAddress);
    console.log("Implementation deployed to " + implementationAddress);

    expect(await instance.name()).to.equal("Eutopia");
  });
});