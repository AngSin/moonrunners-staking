import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`deploying contract with ${deployer.address}`);
  const Trophies = await ethers.getContractFactory("Trophies");
  const trophies = await upgrades.deployProxy(Trophies, { kind: 'uups' });

  await trophies.deployed();

  console.log(`Deployed trophies proxy at ${trophies.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
