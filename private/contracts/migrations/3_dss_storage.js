var dss_storage = artifacts.require("./DSS_Storage.sol");

module.exports = function(deployer) {
  deployer.deploy(dss_storage, {gas: 5000000});
};
