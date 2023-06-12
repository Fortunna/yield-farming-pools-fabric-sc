const { emptyStage } = require('../helpers');
module.exports = emptyStage('Debug stage...');
module.exports.tags = ["debug"];
module.exports.dependencies = [
  // "<some stages>",
  "update_tracer_names"
];
module.exports.runAtTheEnd = true;
