import { expect } from "chai";
import { ethers, upgrades, run } from "hardhat";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import dotenv from "dotenv";

dotenv.config();

const initialOwner = process.env.ETHEREUM_INITIAL_OWNER;
const uniswapRouter = process.env.ETHEREUM_UNISWAP_ROUTER;
const liquidityReceiver = process.env.ETHEREUM_LIQUIDITY_RECEIVER;
const treasuryReceiver = process.env.ETHEREUM_TREASURY_RECEIVER;
const essrReceiver = process.env.ETHEREUM_ESSR_RECEIVER;

async function main() {
  const InstanceFactory = await ethers.getContractFactory("Eutopia");

  const instance = await upgrades.deployProxy(InstanceFactory, [
    initialOwner,
    uniswapRouter,
    liquidityReceiver,
    treasuryReceiver,
    essrReceiver
  ]);
  await instance.waitForDeployment();

  const instanceAddress = await instance.getAddress();
  console.log(" --- Proxy deployed to " + instanceAddress);

  const implementationAddress = await getImplementationAddress(ethers.provider, instanceAddress);
  console.log(" --- Implementation deployed to " + implementationAddress);

  try {
    await run("verify:verify", {
      address: implementationAddress,
      constructorArguments: [],
    });
    console.log(" --- Implementation verified on Etherscan");
  } catch (error) {
    console.error(" --- Error verifying :", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
