import { ethers, upgrades, run } from "hardhat";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

async function main() {
    const proxyAddress = "0x9A2BAF3997A80ffCf303C8e5BB35f71c600fB362";

    console.log("Upgrading...");

    const InstanceFactory = await ethers.getContractFactory("Eutopia");
    const upgraded = await upgrades.upgradeProxy(proxyAddress, InstanceFactory);

    const instanceAddress = await upgraded.getAddress();
    const implementationAddress = await getImplementationAddress(ethers.provider, instanceAddress)

    console.log("Upgraded");
    console.log("Instance address:", instanceAddress);
    console.log("Implementation address:", implementationAddress);

    try {
        await run("verify:verify", {
            address: implementationAddress,
            constructorArguments: [],
        });
        console.log("Implementation verified on Etherscan");
    } catch (error) {
        console.error("Error verifying :", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });