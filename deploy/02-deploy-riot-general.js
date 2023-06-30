const { verify } = require("../utils/verify")

const { ethers } = require("hardhat")
const { constructorParams } = require("../utils/helper")

const developmentChains = ["localhost", "hardhat"]

const deployGeneral = async function (hre) {
    // @ts-ignore
    const { getNamedAccounts, deployments, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    log("----------------------------------------------------")
    log("Deploying TheRiotProtocolGeneral and waiting for confirmations...")
    const riot = await deploy("TheRiotProtocolGeneral", {
        from: deployer,
        args: [
            constructorParams[network.config.chainId].gatewayAddress,
            "0x71B43a66324C7b80468F1eE676E7FCDaF63eB6Ac",
        ],
        log: true,
        waitConfirmations: developmentChains.includes(network.name) ? 1 : 5,
    })
    log(`TheRiotProtocolGeneral at ${riot.address}`)
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        await verify(riot.address, [
            constructorParams[network.config.chainId].gatewayAddress,
            "0x71B43a66324C7b80468F1eE676E7FCDaF63eB6Ac",
        ])
    }
}

module.exports = deployGeneral
deployGeneral.tags = ["all", "general"]
