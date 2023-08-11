const { emptyStage } = require('../helpers');
module.exports = emptyStage('Goerli Deploy stage...');
module.exports.tags = ["goerli"];
module.exports.dependencies = [
  "external_goerli",
  "prototypes",
  "main",
  "mint",
  "pool",
  "uniswap_v3_pool",
  "approvals_u3",
  "update_tracer_names"
];
module.exports.runAtTheEnd = true;
