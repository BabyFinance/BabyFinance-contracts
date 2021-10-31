import { ethers } from "hardhat";
import { TestERC721__factory } from "../typechain";

async function deploy() {
  console.log();
  console.log("Deploying Test Collection");
  const signers = await ethers.getSigners();
  const testCollectionFactory = (await ethers.getContractFactory(
    "TestERC721",
    signers[0]
  )) as TestERC721__factory;
  const testCollection = await testCollectionFactory.deploy();
  await testCollection.deployed();
  console.log("Address:", testCollection.address);
  console.log();
}

deploy();
