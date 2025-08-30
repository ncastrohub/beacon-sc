import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contract with account:", deployer.address);

  // Get the contract factory
  const MedicineRegistry = await ethers.getContractFactory("MedicineRegistry");

  // Deploy the contract
  const contract = await MedicineRegistry.deploy();
  await contract.waitForDeployment();

  // Log the contract address
  const contractAddress = await contract.getAddress();
  console.log("MedicineRegistry deployed to:", contractAddress);

  // Optional: Print the explorer link
  console.log(`Verify on Coston2 Scan: https://coston2-scan.flare.network/address/${contractAddress}`);
}

// Run the deployment and catch any errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error during deployment:", error);
    process.exit(1);
  });