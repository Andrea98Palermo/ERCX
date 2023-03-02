require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1
      }
    }
  },
  gasReporter: {
    enabled: true
  }

  /**settings: { optimizer: { enabled: true, runs: 200 } }*/
};
