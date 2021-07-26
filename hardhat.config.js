/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require("@nomiclabs/hardhat-ethers");
 require("@nomiclabs/hardhat-truffle5");
 require("@nomiclabs/hardhat-etherscan");
 require('@openzeppelin/hardhat-upgrades');
 require("solidity-coverage");
 
 module.exports = {
   solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true
      }
    }
   },
   networks: {}
 };
 