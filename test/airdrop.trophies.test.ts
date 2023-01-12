import {deployProxy} from "./utils";
import {Trophies} from "../typechain-types";
import hre from "hardhat";
import { BigNumber } from "ethers";
import { expect } from "chai";

describe('airdrop', () => {
	it('should airdrop a trophy to a user', async () => {
		const trophies = await deployProxy("Trophies") as Trophies;
		const [owner, account1] = await hre.ethers.getSigners();
		await trophies.airdropTrophy(99, account1.address);
		expect(await trophies.balanceOf(account1.address, 99)).to.equal(BigNumber.from("1"));

		await expect(trophies.connect(account1).airdropTrophy(1, owner.address))
			.to.be.revertedWith('Ownable: caller is not the owner');
	});
});