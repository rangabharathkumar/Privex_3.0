require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.19",
  networks: {
    holesky: {                            // Define Holesky network
      url: process.env.ALCHEMY_API_URL,   // Use Alchemy RPC URL
      chainId: 17000,                     // Holesky Chain ID
      accounts: [process.env.PRIVATE_KEY] // Your Metamask private key
    }
  },
  paths: {
    artifacts: "./client/src/artifacts"
  }
};
