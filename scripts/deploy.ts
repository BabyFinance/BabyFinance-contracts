import dotenv from "dotenv";
import { ethers } from "hardhat";
import { ERC721Stake__factory } from "../typechain";

dotenv.config();

function startTime() {
  const envStartTime = process.env.STARTTIME;
  if (envStartTime?.toLowerCase() === "now") {
    return Math.floor(Date.now() / 1000);
  }
  return envStartTime!;
}

async function deploy() {
  console.log();
  console.log("Deploying Staking");
  const signers = await ethers.getSigners();
  const stakingFactory = (await ethers.getContractFactory(
    "ERC721Stake",
    signers[0]
  )) as ERC721Stake__factory;
  const staking = await stakingFactory.deploy(startTime());
  await staking.deployed();
  console.log("Address:", staking.address);
  console.log();
}

deploy();
