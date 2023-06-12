const { emptyStage } = require('../helpers');
module.exports = emptyStage('General fixture...');
module.exports.tags = ["general_test_fixtures"];
module.exports.dependencies = [
    // "<some fixtures tags>",
    "update_tracer_names"
];
module.exports.runAtTheEnd = true;
