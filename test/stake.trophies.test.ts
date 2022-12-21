import hre from "hardhat";
import {deployContract} from "./utils";
import {Runners, Trophies} from "../typechain-types";
import {expect} from "chai";
import {BigNumber} from "ethers";

describe('staking', () => {
	it("should not stake if user does not own them", async() => {
		const runnersContract = await deployContract("Runners") as Runners;
		const [_, anotherAccount] = await hre.ethers.getSigners();
		const trophies = await deployContract("Trophies") as Trophies;
		await trophies.setRunnersContract(runnersContract.address);
		await runnersContract.setApprovalForAll(trophies.address, true);
		await expect(trophies.connect(anotherAccount).stake([1, 2]))
			.to.be.revertedWith('ERC721: transfer from incorrect owner');
	});

	it("should stake", async () => {
		const runnersContract = await deployContract("Runners") as Runners;
		const [owner] = await hre.ethers.getSigners();
		const trophies = await deployContract("Trophies") as Trophies;
		await trophies.setRunnersContract(runnersContract.address);
		await runnersContract.setApprovalForAll(trophies.address, true);
		await trophies.stake([1, 2]);
		const blockNum = await hre.ethers.provider.getBlockNumber();
		const timestamp = (await hre.ethers.provider.getBlock(blockNum)).timestamp;
		expect(await trophies.getStake(owner.address)).to.eql([
			[1,2],
			BigNumber.from(timestamp),
		]);
	});

	it("should add to stake without changing timestamp", async () => {
		const runnersContract = await deployContract("Runners") as Runners;
		const [owner] = await hre.ethers.getSigners();
		const trophies = await deployContract("Trophies") as Trophies;
		await trophies.setRunnersContract(runnersContract.address);
		await runnersContract.setApprovalForAll(trophies.address, true);
		await trophies.stake([1, 2]);
		const blockNum = await hre.ethers.provider.getBlockNumber();
		const timestamp = (await hre.ethers.provider.getBlock(blockNum)).timestamp;
		expect(await trophies.getStake(owner.address)).to.eql([
			[1,2],
			BigNumber.from(timestamp),
		]);
		await trophies.stake([1,2,3]);
		expect(await trophies.getStake(owner.address)).to.eql([
			[1,2,3],
			BigNumber.from(timestamp),
		]);
		await trophies.stake([1,2]);
		expect(await trophies.getStake(owner.address)).to.eql([
			[1,2,3],
			BigNumber.from(timestamp),
		]);
		await trophies.stake([5]);
		expect(await trophies.getStake(owner.address)).to.eql([
			[1,2,3,5],
			BigNumber.from(timestamp),
		]);
	});
});