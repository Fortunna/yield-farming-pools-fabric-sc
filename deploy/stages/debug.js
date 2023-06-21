const { emptyStage } = require('../helpers');
module.exports = emptyStage('Debug stage...');
module.exports.tags = ["debug"];
module.exports.dependencies = [
  "external_tokens",
  "prototypes",
  "main",
  "pool",
  "update_tracer_names"
];
module.exports.runAtTheEnd = true;
