const { emptyStage } = require('../helpers');
module.exports = emptyStage('Debug stage...');
module.exports.tags = ["debug"];
module.exports.dependencies = [
  "prototypes",
  "main",
  "update_tracer_names"
];
module.exports.runAtTheEnd = true;
