const { verify } = require("../utils/verify")

const { ethers } = require("hardhat")

const developmentChains = ["localhost", "hardhat"]

const deployPolygon = async function (hre) {
    // @ts-ignore
    const { getNamedAccounts, deployments, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    log("----------------------------------------------------")
    log("Deploying TheRiotProtocolPolygon and waiting for confirmations...")
    const riot = await deploy("TheRiotProtocolPolygon", {
        from: deployer,
        args: [
            "0x94caA85bC578C05B22BDb00E6Ae1A34878f047F7",
            "0x71B43a66324C7b80468F1eE676E7FCDaF63eB6Ac",
        ],
        log: true,
        waitConfirmations: developmentChains.includes(network.name) ? 1 : 5,
    })
    log(`TheRiotProtocolPolygon at ${riot.address}`)
    if (!developmentChains.includes(network.name) && process.env.POLYGONSCAN_API_KEY) {
        await verify(riot.address, [
            "0x94caA85bC578C05B22BDb00E6Ae1A34878f047F7",
            "0x71B43a66324C7b80468F1eE676E7FCDaF63eB6Ac",
        ])
    }
}

module.exports = deployPolygon
deployPolygon.tags = ["all", "polygon"]
