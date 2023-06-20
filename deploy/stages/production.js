const { emptyStage } = require('../helpers');
module.exports = emptyStage('Production stage...');
module.exports.tags = ["production"];
module.exports.dependencies = [
  "deploy_prototypes",
  "main_stage",
  "pools",
  "update_tracer_names"
];
module.exports.runAtTheEnd = true;
