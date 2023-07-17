// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // deploy impl
  // const implc = await ethers.getContractFactory("ERC721SeaDropCloneable");
  // const impl = await implc.deploy();
  // await impl.deployed();

  // console.log("impl address is:", impl.address);

  // const sdc = await ethers.getContractFactory("EZDrop721");
  // const seadrop = await sdc.deploy(impl.address);
  // await seadrop.deployed();

  // console.log("deploy address is:", seadrop.address);

  // 
  const ts20c = await ethers.getContractFactory("TestERC20");
  const ts20 = await ts20c.deploy();
  await ts20.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
