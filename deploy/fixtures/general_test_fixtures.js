const { emptyStage } = require('../helpers');
module.exports = emptyStage('General fixture...');
module.exports.tags = ["general_test_fixtures"];
module.exports.dependencies = [
    "prototypes",
    "main",
    "update_tracer_names"
];
module.exports.runAtTheEnd = true;
