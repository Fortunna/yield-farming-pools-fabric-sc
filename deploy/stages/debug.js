const { emptyStage } = require('../helpers');
module.exports = emptyStage('Debug stage...');
module.exports.tags = ["debug"];
module.exports.dependencies = [
  "external",
  "prototypes",
  "main",
  "pool",
  "uniswap_v3_pool",
  "approvals_u3",
  "update_tracer_names"
];
module.exports.runAtTheEnd = true;
