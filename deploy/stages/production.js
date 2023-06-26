const { emptyStage } = require('../helpers');
module.exports = emptyStage('Production stage...');
module.exports.tags = ["production"];
module.exports.dependencies = [
  "external",
  "prototypes",
  "main",
  "pool",
  "uniswap_v3_pool",
  "update_tracer_names"
];
module.exports.runAtTheEnd = true;
