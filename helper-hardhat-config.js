const DECIMAL = 8
const INITIAL_ANSWER = 300000000000// 3000
//本地链
const devlopmentChains = ["hardhat", "local"]
const CONFIRMATIONS = 5
const networkConfig = {
    11155111: {
        ethUsdDataFeed: "0x694AA1769357215DE4FAC081bf1f309aDC325306",

        linkUsdDataFeed: "0xc59E3633BAAC79493d908e63626716e204A45EdF",
        linkToken: "0x51491557b8c812165985155d50381557b8c81216"

    },
    97: {
        ethUsdDataFeed: "0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7"
    }
}

module.exports = {
    DECIMAL,
    INITIAL_ANSWER,
    devlopmentChains,
    networkConfig,
    CONFIRMATIONS
}