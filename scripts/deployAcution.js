
const { ethers } = require("hardhat");

//script 需要手动执行 js脚本  npx hardhat run scripts/deploy.js --network sepolia
async function main(){
    // create factory
    const factoryAuction = await ethers.getContractFactory("Auction");
    console.log("Deploying Auction...");
    //deploy  contract from  factory
    const auction = await factoryAuction.deploy();
    await auction.waitForDeployment();
    console.log("Auction deployed to:", auction.target);

    /*if (hre.network.config.chainId === 1115515 && process.env.ETHERSCAN_API_KEY) {
        console.log("Waiting for block confirmations...");
        await auction.deployTransaction().wait(5);
        //verify
        await verify(auction.target, [])
    } else {
        console.log("Not on sepolia network. No need to verify");
    }*/

}

async function verify(address, args){

    console.log("Verifying contract...");
    try{
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: args,
        })
    } catch (e) {
        if(e.message.toLowerCase().includes("already verified")){
            console.log("Already Verified!");
        } else {
            console.log(e);
        }
    }
}


// call main function
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })

