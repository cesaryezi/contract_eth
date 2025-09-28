
const { ethers } = require("hardhat");

//script 需要手动执行 js脚本  npx hardhat run scripts/deploy.js --network sepolia
async function main(){
    // create factory
    const factoryNFT = await ethers.getContractFactory("NFT");
    console.log("Deploying NFT...");
    //deploy  contract from  factory
    const nft = await factoryNFT.deploy("MyNFT","ZJC");
    await nft.waitForDeployment();
    console.log("NFT deployed to:", nft.target);

    /*if (hre.network.config.chainId === 1115515 && process.env.ETHERSCAN_API_KEY) {
        console.log("Waiting for block confirmations...");
        await nft.deployTransaction().wait(5);
        //verify
        await verify(nft.target, ["MyNFT","ZJC"])
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

