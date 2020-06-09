var compiledFactory = artifacts.require("ElectionFactory");
var compiledRegistrationAuthority = artifacts.require("RegistrationAuthority")

module.exports = function(deployer) {
  deployer.deploy(compiledRegistrationAuthority).then(function() {
    return deployer.deploy(compiledFactory, compiledRegistrationAuthority.address);
  });
};
