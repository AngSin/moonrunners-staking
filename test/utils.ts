import { ethers, upgrades } from "hardhat";

export const deployContract = async (name: string) => {
	const contractFactory = await ethers.getContractFactory(name);
	return await contractFactory.deploy();
};

export const deployProxy = async (name: string, args: unknown[] = []) => {
	const contractFactory = await ethers.getContractFactory(name);
	return await upgrades.deployProxy(contractFactory, args,{ kind: 'uups' });
};