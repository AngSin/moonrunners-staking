import hre from "hardhat";
import {deployContract} from "./utils";
import {Runners, Trophies} from "../typechain-types";
import {expect} from "chai";
import {BigNumber} from "ethers";

describe('unstaking', () => {
	it("should un-stake tokens if they were staked by the same user", async() => {
		const runnersContract = await deployContract("Runners") as Runners;
		const [account, anotherAccount] = await hre.ethers.getSigners();
		const trophies = await deployContract("Trophies") as Trophies;
		await trophies.setRunnersContract(runnersContract.address);
		await runnersContract.setApprovalForAll(trophies.address, true);
		await trophies.stake([1, 2, 3, 4, 5, 6, 7, 8]);
		const blockNum = await hre.ethers.provider.getBlockNumber();
		const timestamp = (await hre.ethers.provider.getBlock(blockNum)).timestamp;
		expect(await runnersContract.ownerOf(1)).to.equal(trophies.address);

		await trophies.unstake([1,4]);
		expect(await runnersContract.ownerOf(1)).to.equal(account.address);
		expect(await trophies.getStake(account.address)).to.eql([
			[
				BigNumber.from("2"),
				BigNumber.from("3"),
				BigNumber.from("5"),
				BigNumber.from("6"),
				BigNumber.from("7"),
				BigNumber.from("8"),
			],
			BigNumber.from(timestamp),
		]);

		await expect(trophies.unstake([]));
		expect(await trophies.getStake(account.address)).to.eql([
			[
				BigNumber.from("2"),
				BigNumber.from("3"),
				BigNumber.from("5"),
				BigNumber.from("6"),
				BigNumber.from("7"),
				BigNumber.from("8"),
			],
			BigNumber.from(timestamp),
		]);
	});
});