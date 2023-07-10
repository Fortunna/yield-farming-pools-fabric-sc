const hre = require('hardhat');
const approvalsForPool = require("./reusable/approvals_for_pool");
module.exports = approvalsForPool(
    hre.names.internal.fortunnaPoolUniswapV3,
    async (deployScriptParams) => {
        const { deployments } = deployScriptParams;
        const { get } = deployments;
        return [
            (await get(hre.names.external.usdt)).address,
            (await get(hre.names.external.weth)).address
        ];
    }
);
module.exports.tags = ["approvals_for_uniswap_v3_pool", "approvals_u3"];
