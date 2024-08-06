import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import dotenv from "dotenv";

dotenv.config();

const initialOwner = process.env.SEPOLIA_INITIAL_OWNER;
const uniswapRouter = process.env.SEPOLIA_UNISWAP_ROUTER;
const liquidityReceiver = process.env.SEPOLIA_LIQUIDITY_RECEIVER;
const treasuryReceiver = process.env.SEPOLIA_TREASURY_RECEIVER;
const essrReceiver = process.env.SEPOLIA_ESSR_RECEIVER;

describe("Eutopia", function () {
  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("Eutopia");

    const instance = await upgrades.deployProxy(ContractFactory, [
      initialOwner,
      uniswapRouter,
      liquidityReceiver,
      treasuryReceiver,
      essrReceiver
    ]);
    await instance.waitForDeployment();

    expect(await instance.name()).to.equal("Eutopia");
  });
});