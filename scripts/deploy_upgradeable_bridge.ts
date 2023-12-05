import { ethers, upgrades } from "hardhat";

async function main() {
  const Bridge = await ethers.getContractFactory("Bridge");
  console.log("Deploying Bridge...");
  const bridge = await upgrades.deployProxy(Bridge, {
    initializer: "initialize",
  });
  await bridge.waitForDeployment();
  console.log("Bridge deployed to:", await bridge.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
