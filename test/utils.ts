import {ethers} from "hardhat";

export const deployContract = async (name: string) => {
	const contractFactory = await ethers.getContractFactory(name);
	return await contractFactory.deploy();
};