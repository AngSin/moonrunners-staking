import {deployContract} from "./utils";
import {Runners, Trophies} from "../typechain-types";
import hre from "hardhat";
import {expect} from "chai";
import {BigNumber} from "ethers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe('claim', () => {
	it('should let users claim the highest possible trophy', async () => {
		const runnersContract = await deployContract("Runners") as Runners;
		const [account, account1, account2] = await hre.ethers.getSigners();
		const trophies = await deployContract("Trophies") as Trophies;
		await trophies.setRunnersContract(runnersContract.address);
		await runnersContract.setApprovalForAll(trophies.address, true);
		await runnersContract.connect(account1).setApprovalForAll(trophies.address, true);
		await runnersContract.connect(account2).setApprovalForAll(trophies.address, true);
		for (let i = 1; i < 6; i++) {
			await runnersContract.transferFrom(account.address, account1.address, i);
		}

		// claim does not work before 30 days
		await trophies.connect(account1).stake([1, 2, 3, 4, 5,]);
		await expect(trophies.connect(account1).claim()).to.be.revertedWith('No claim is possible for you!');
		expect(await trophies.connect(account1).balanceOf(account1.address, 2)).to.equal(0);

		// claim silver
		await trophies.setStakingPeriod(1);
		expect(await trophies.connect(account1).balanceOf(account1.address, 2)).to.equal(0);
		await trophies.connect(account1).claim();
		expect(await trophies.connect(account1).balanceOf(account1.address, 2)).to.equal(1);

		// repeated claims do not work
		// await trophies.connect(account1).claim()
		await expect(trophies.connect(account1).claim()).to.be.revertedWith('No claim is possible for you!');
		expect(await trophies.connect(account1).balanceOf(account1.address, 2)).to.equal(1);

		// having & staking more runners makes user eligible for gold trophy
		for (let i = 6; i < 11; i++) {
			await runnersContract.transferFrom(account.address, account1.address, i);
		}
		await trophies.connect(account1).stake([6,7,8,9,10]);
		await trophies.connect(account1).claim();
		expect(await trophies.connect(account1).balanceOf(account1.address, 3)).to.equal(1);

		// having & staking 25 runners makes user eligible for diamond trophy
		const tokenIds = [];
		for (let i = 11; i < 36; i++) {
			tokenIds.push(i);
		}
		await trophies.stake(tokenIds);
		await trophies.setStakingPeriod(1);
		await trophies.claim();
		expect(await trophies.balanceOf(account.address, 4)).to.equal(1);
	});

	it('should let users claim a bronze trophy', async () => {
		const runnersContract = await deployContract("Runners") as Runners;
		const [account] = await hre.ethers.getSigners();
		const trophies = await deployContract("Trophies") as Trophies;
		await trophies.setRunnersContract(runnersContract.address);
		await runnersContract.setApprovalForAll(trophies.address, true);
		await trophies.stake([1]);
		await trophies.setStakingPeriod(1);
		await trophies.claim();
		expect(await trophies.balanceOf(account.address, 1)).to.equal(1);
	});

	it('should let users downgrade', async () => {
		const runnersContract = await deployContract("Runners") as Runners;
		const trophies = await deployContract("Trophies") as Trophies;
		const [account] = await hre.ethers.getSigners();
		await trophies.setRunnersContract(runnersContract.address);
		await trophies.setStakingPeriod(1);
		await runnersContract.setApprovalForAll(trophies.address, true);
		// having & staking 25 runners makes user eligible for diamond trophy
		const tokenIds = [];
		for (let i = 1; i < 26; i++) {
			tokenIds.push(i);
		}
		await trophies.stake(tokenIds);
		await time.increase(100);
		expect(await trophies.getPossibleTrophyClaim()).to.equal(BigNumber.from("4")); // diamond
		await trophies.claim();
		expect(await trophies.balanceOf(account.address, 4)).to.equal(1);
		const trophiesToRemove = [1];
		await trophies.unstake(trophiesToRemove);
		await time.increase(100);
		expect(await trophies.getPossibleTrophyClaim()).to.equal(BigNumber.from("3"));
		await trophies.claim();
		expect(await trophies.balanceOf(account.address, 3)).to.equal(1);
		expect(await trophies.getPossibleTrophyClaim()).to.equal(BigNumber.from(0));
		await trophies.unstake([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
		expect(await trophies.getPossibleTrophyClaim()).to.equal(BigNumber.from("2"));
	});
});