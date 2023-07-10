const hre = require('hardhat');
const approvalsForPool = require("./reusable/approvals_for_pool");
module.exports = approvalsForPool(
    hre.names.internal.fortunnaUniswapV3Pool,
    async (deployScriptParams) => {
        return [

        ];
    }
);
module.exports.tags = ["approvals_for_uniswap_v3_pool", "approvals_u3"];
