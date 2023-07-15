import {deployContract, deployProxy} from "./utils";
import {DragonsV2, Runners, TrophiesV2} from "../typechain-types";
import hre, {ethers} from "hardhat";
import {BigNumber} from "ethers";
import {expect} from "chai";

const fakeProof = ["0xd5b5f64d66cc31c622be4bdc9e83b48fafd599c8e2dcd4402032ab1c9f89dece"];

describe('staking & unstaking dragons', () => {
	it('should transfer dragons on staking and unstaking', async () => {
		const [owner] = await ethers.getSigners()
		const dragonsContract = await deployProxy("DragonsV2", [owner.address, BigNumber.from("0")]) as DragonsV2;
		const trophiesContract = await deployProxy("TrophiesV2") as TrophiesV2;
		await trophiesContract.setDragonsContract(dragonsContract.address);
		const runnersContract = await deployContract("Runners") as Runners;
		await trophiesContract.setRunnersContract(runnersContract.address);
		await runnersContract.setApprovalForAll(trophiesContract.address, true);
		await dragonsContract.setPublicMinting(true, 1);
		await dragonsContract.setMaxPerWallet(10);
		await dragonsContract.mint(fakeProof, { value: 10 });
		await dragonsContract.setApprovalForAll(trophiesContract.address, true);
		// stake runners
		await trophiesContract.stake([1, 2, 3]);
		const blockNumAfterStakingRunners = await hre.ethers.provider.getBlockNumber();
		const timestampAfterStakingRunners = (await hre.ethers.provider.getBlock(blockNumAfterStakingRunners)).timestamp;
		expect(await trophiesContract.getStake(owner.address)).to.eql([
			[BigNumber.from('1'),BigNumber.from('2'), BigNumber.from('3')],
			BigNumber.from(timestampAfterStakingRunners),
		]);
		// stake dragons
		await trophiesContract.stakeDragons([0, 1, 2]);
		expect(await trophiesContract.getStake(owner.address)).to.eql([
			[BigNumber.from('1'),BigNumber.from('2'),BigNumber.from('3'),BigNumber.from('20000'),BigNumber.from('20001'),BigNumber.from('20002')],
			BigNumber.from(timestampAfterStakingRunners),
		]);
		for (let i = 0; i < 3; i++) {
			expect(await dragonsContract.ownerOf(i)).to.equal(trophiesContract.address);
		}
		// unstake dragons
		await trophiesContract.unstakeDragons([1]);
		expect(await trophiesContract.getStake(owner.address)).to.eql([
			[BigNumber.from('1'),BigNumber.from('2'),BigNumber.from('3'),BigNumber.from('20000'),BigNumber.from('20002')],
			BigNumber.from(timestampAfterStakingRunners),
		]);
	});
});