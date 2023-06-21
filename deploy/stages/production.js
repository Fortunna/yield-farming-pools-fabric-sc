const { emptyStage } = require('../helpers');
module.exports = emptyStage('Production stage...');
module.exports.tags = ["production"];
module.exports.dependencies = [
  "external_tokens",
  "prototypes",
  "main",
  "pool",
  "update_tracer_names"
];
module.exports.runAtTheEnd = true;
