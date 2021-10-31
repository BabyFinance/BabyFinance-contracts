import { BigNumber } from "@ethersproject/bignumber";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers, waffle } from "hardhat";
import {
  ERC721Stake,
  ERC721Stake__factory,
  TestERC721,
  TestERC721__factory,
} from "../typechain";

chai.use(solidity);

const { expect } = chai;
const { constants, utils } = ethers;
const { provider } = waffle;

async function deployTestNFT() {
  const signers = await ethers.getSigners();
  const testNFTFactory = (await ethers.getContractFactory(
    "TestERC721",
    signers[0]
  )) as TestERC721__factory;
  const testNFT = (await testNFTFactory.deploy()) as TestERC721;
  await testNFT.deployed();

  return testNFT;
}

async function deployStaking() {
  const signers = await ethers.getSigners();
  const stakingFactory = (await ethers.getContractFactory(
    "ERC721Stake",
    signers[0]
  )) as ERC721Stake__factory;
  const staking = (await stakingFactory.deploy(
    Math.floor(Date.now() / 1000)
  )) as ERC721Stake;
  await staking.deployed();

  return staking;
}

describe("ERC721 Staking", () => {
  it("Should stake tokens 0-1", async () => {
    const testNFT = await deployTestNFT();

    await testNFT.mint();
    await testNFT.mint();

    const staking = await deployStaking();

    await staking.addCollection(testNFT.address, 1);

    console.log(await staking.collectionInfo(0));

    await testNFT.setApprovalForAll(staking.address, true);

    await staking.stake(0, 0);
    await staking.stake(0, 1);

    const signers = await ethers.getSigners();
    const numStaked = await staking.userTokenStakes(signers[0].address);

    const userStakedTokens = [];

    let head = BigNumber.from(0);
    for (let i = BigNumber.from(0); i.lt(numStaked); i = i.add(1)) {
      const stakedToken = await staking.userStakedToken(
        signers[0].address,
        head
      );
      userStakedTokens.push(stakedToken);
      head = stakedToken.id;
    }

    expect(userStakedTokens[0].id.toString()).to.equal("2");
    expect(userStakedTokens[1].id.toString()).to.equal("1");

    expect(userStakedTokens[0].tokenId.toString()).to.equal("1");
    expect(userStakedTokens[1].tokenId.toString()).to.equal("0");
  });

  it("Should stake tokens 0-2 & Unstake token 1, then 2, then 0", async () => {
    const testNFT = await deployTestNFT();

    await testNFT.mint();
    await testNFT.mint();
    await testNFT.mint();

    const staking = await deployStaking();

    await staking.addCollection(testNFT.address, 1);

    await testNFT.setApprovalForAll(staking.address, true);

    await staking.stake(0, 0);
    await staking.stake(0, 1);
    await staking.stake(0, 2);

    await staking.unstake(2);

    const signers = await ethers.getSigners();
    let numStaked = await staking.userTokenStakes(signers[0].address);

    let userStakedTokens = [];

    let head = BigNumber.from(0);
    for (let i = BigNumber.from(0); i.lt(numStaked); i = i.add(1)) {
      const stakedToken = await staking.userStakedToken(
        signers[0].address,
        head
      );
      userStakedTokens.push(stakedToken);
      head = stakedToken.id;
    }

    expect(userStakedTokens[0].id.toString()).to.equal("3");
    expect(userStakedTokens[1].id.toString()).to.equal("1");

    expect(userStakedTokens[0].tokenId.toString()).to.equal("2");
    expect(userStakedTokens[1].tokenId.toString()).to.equal("0");

    await staking.unstake(3);

    numStaked = await staking.userTokenStakes(signers[0].address);

    userStakedTokens = [];

    head = BigNumber.from(0);
    for (let i = BigNumber.from(0); i.lt(numStaked); i = i.add(1)) {
      const stakedToken = await staking.userStakedToken(
        signers[0].address,
        head
      );
      userStakedTokens.push(stakedToken);
      head = stakedToken.id;
    }

    expect(userStakedTokens[0].id.toString()).to.equal("1");

    expect(userStakedTokens[0].tokenId.toString()).to.equal("0");

    await staking.unstake(1);

    numStaked = await staking.userTokenStakes(signers[0].address);

    expect(numStaked.toString()).to.equal("0");
  });

  it("Should Emergency Withdraw", async () => {
    const testNFT = await deployTestNFT();

    await testNFT.mint();

    let staking = await deployStaking();

    await staking.addCollection(testNFT.address, 1);

    await testNFT.setApprovalForAll(staking.address, true);

    await staking.stake(0, 0);
    await staking.emergencyWithdraw(testNFT.address, 0);

    staking = await deployStaking();

    await staking.addCollection(testNFT.address, 1);

    const signers = await ethers.getSigners();

    await testNFT.transferFrom(signers[0].address, staking.address, 0);

    await staking.emergencyWithdraw(testNFT.address, 0);
  });

  it("Should correctly calculate scores", async () => {
    const testNFTCol1 = await deployTestNFT();
    const testNFTCol2 = await deployTestNFT();

    const staking = await deployStaking();

    await testNFTCol1.setApprovalForAll(staking.address, true);
    await testNFTCol2.setApprovalForAll(staking.address, true);

    await staking.addCollection(testNFTCol1.address, 5);
    await staking.addCollection(testNFTCol2.address, 10);

    const signers = await ethers.getSigners();

    staking.setPhaseUpdater(signers[0].address, true);

    await testNFTCol1.mint();
    await testNFTCol2.mint();

    const testNFTCol21 = testNFTCol2.connect(signers[1]);
    const staking1 = staking.connect(signers[1]);

    await testNFTCol21.mint();

    await testNFTCol21.setApprovalForAll(staking1.address, true);

    await staking.stake(0, 0);

    const blockNo = await provider.getBlockNumber();
    const block = await provider.getBlock(blockNo);
    let nextBlockTimestamp = block.timestamp;

    nextBlockTimestamp += 60;
    await provider.send("evm_setNextBlockTimestamp", [nextBlockTimestamp]);

    await staking.stake(1, 0);

    nextBlockTimestamp += 120;
    await provider.send("evm_setNextBlockTimestamp", [nextBlockTimestamp]);

    await staking1.stake(1, 1);

    nextBlockTimestamp += 60;
    await provider.send("evm_setNextBlockTimestamp", [nextBlockTimestamp]);

    await staking.unstake(1);

    nextBlockTimestamp += 300;
    await provider.send("evm_setNextBlockTimestamp", [nextBlockTimestamp]);
    await provider.send("evm_mine", []);

    expect(
      (await staking.userPhaseScore(signers[0].address, 0)).toString()
    ).to.equal("6000");

    expect(
      (await staking.userPhaseScore(signers[1].address, 0)).toString()
    ).to.equal("3600");

    expect((await staking.totalPhaseScore(0)).toString()).to.equal("9600");

    nextBlockTimestamp += 60;
    await provider.send("evm_setNextBlockTimestamp", [nextBlockTimestamp]);

    await staking.nextPhase(true);

    nextBlockTimestamp += 300;
    await provider.send("evm_setNextBlockTimestamp", [nextBlockTimestamp]);

    await staking.nextPhase(false);

    expect(
      (await staking.userPhaseScore(signers[0].address, 0)).toString()
    ).to.equal("6600");

    expect(
      (await staking.userPhaseScore(signers[0].address, 1)).toString()
    ).to.equal("3000");

    expect(
      (await staking.userPhaseScore(signers[1].address, 0)).toString()
    ).to.equal("4200");

    expect(
      (await staking.userPhaseScore(signers[1].address, 1)).toString()
    ).to.equal("3000");

    expect((await staking.totalPhaseScore(0)).toString()).to.equal("10800");
    expect((await staking.totalPhaseScore(1)).toString()).to.equal("6000");

    nextBlockTimestamp += 60;
    await provider.send("evm_setNextBlockTimestamp", [nextBlockTimestamp]);

    await staking.unstake(2);

    nextBlockTimestamp += 60;
    await provider.send("evm_setNextBlockTimestamp", [nextBlockTimestamp]);
    await provider.send("evm_mine", []);

    expect(
      (await staking.userPhaseScore(signers[0].address, 1)).toString()
    ).to.equal("3000");
    expect(
      (await staking.userPhaseScore(signers[1].address, 1)).toString()
    ).to.equal("3000");
    expect((await staking.totalPhaseScore(1)).toString()).to.equal("6000");

    expect(
      (await staking.userPhaseScore(signers[0].address, 2)).toString()
    ).to.equal("600");
    expect(
      (await staking.userPhaseScore(signers[1].address, 2)).toString()
    ).to.equal("1200");
    expect((await staking.totalPhaseScore(2)).toString()).to.equal("1800");

    for (let i = 0; i < 2; i++) {
      const phase1Score = await staking.userPhaseScore(signers[i].address, 1);
      const phase2Score = await staking.userPhaseScore(signers[i].address, 2);

      const allPhaseScore = await staking.userScore(signers[i].address);

      expect(allPhaseScore.toString()).to.equal(
        phase1Score.add(phase2Score).toString()
      );
    }

    const phase1TotalScore = await staking.totalPhaseScore(1);
    const phase2TotalScore = await staking.totalPhaseScore(2);

    const allPhaseTotalScore = await staking.totalScore();

    expect(allPhaseTotalScore.toString()).to.equal(
      phase1TotalScore.add(phase2TotalScore).toString()
    );
  });
});
