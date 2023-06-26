const { lazyObject } = require("hardhat/plugins");

require("dotenv").config();
require("hardhat-deploy");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("hardhat-docgen");
require('hardhat-abi-exporter');
require("hardhat-tracer");
require("@nomicfoundation/hardhat-chai-matchers");

require("./tasks/accounts")(task);
require("./tasks/get_all_artifacts")(task);

const mainnetUrl = `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_MAINNET_API_KEY}`;
const sepoliaUrl = `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_SEPOLIA_API_KEY}`;

const mainnetChainId = 1;
const sepoliaChainId = 11155111;

const optimizer = {
  enabled: true,
  runs: 200,
}

const compilers = [
  {
    version: "0.8.20",
    settings: {
      optimizer
    }
  },
  {
    version: "0.7.6",
    settings: {
      optimizer
    }
  }
]

extendEnvironment(async (hre) => {
  // This is for the deploy artifacts stage management.
  // The Deployments space is used for dependency injection for deploy scripts and test/fixtures scripts.
  // Example: For fixtures we have to have different artifacts for LP interface and IPair interface but still
  // logically it's one contract in the production stage. We also have our own contracts and the external ones,
  // that also have to be accesible from the Deployments space. This object is to organize the artifacts names
  // similar to the localization frameworks (in the "get" function of the "deployments" instance we use keys from
  // the hre.names object).
  // There are two groups of artifact names: internal (our own and local libraries) and external (like Uniswap or etc.). The internal
  // ones are populated automatically. The external ones and their subgroups are defined in the "external_artifacts_names.json"
  // file.
  //
  // Code example:
  // const <someContractInstanceVariable> = await hre.ethers.getContractAt(
  //   hre.names.internal.<valid valid deployments artifact>,
  //   (await deployments.get(hre.names.<full valid deployments artifact name>)).address
  // );
  //
  // Or:
  // const apeSwapPoolInstance = await hre.ethers.getContractAt(
  //   hre.names.internal.apeSwapPool,
  //   (await deployments.get(hre.names.internal.apeSwapPool)).address
  // );
  //
  // Or for tests/fixtures:
  // const busdInstance = await hre.ethers.getContractAt(
  //   hre.names.external.tokens.busd,
  //   (await deployments.get(hre.names.external.tokens.busd)).address
  // );
  //
  // Or for production:
  // const busdInstance = await hre.ethers.getContractAt(
  //   hre.names.internal.iERC20,
  //   (await deployments.get(hre.names.external.tokens.busd)).address
  // );
  // 
  // There is also a support for Diamond (EIP 2535) contracts
  // The "interface" key is for the name of the collective facets interface (could not be used to acquire an address),
  // and the "proxy" key is for the Hardhat named multi-facet proxy contract name.
  // To differ the standard contract between diamond contract the collective interface should be prefixed with word "Diamond".
  // Like: DiamondDiscountHub.sol
  // Example of the name usage:
  // const <diamond instance> = await ethers.getContractAt(
  //   hre.names.internal.diamonds.<diamond instance interface postfix>.interface,
  //   (await deployments.get(hre.names.internal.diamonds.<diamond instance interface postfix>.proxy)).address
  // );
  //
  // "names" object contains all names of all types for the artifacts.
  const allArtifacts = await hre.run("get_all_artifacts");
  const toCamelCase = e => e[0].toLowerCase() + e.slice(1);
  const prefix = 'diamond';
  hre.names = {
    external: lazyObject(() => require('./external_artifacts_names.json')),
    internal: lazyObject(() => {
      // Gathering all our internal artifacts names and making them public
      const result = {
        diamonds: {}
      };
      allArtifacts
        .map(e => e.split(':')[1])
        .forEach(e => {
          const name = toCamelCase(e);
          if (name.startsWith(prefix)) {
            const diamondName = name.slice(prefix.length); 
            result.diamonds[toCamelCase(diamondName)] = {
              interface: e,
              proxy: diamondName + "_DiamondProxy"
            };
          } else {
            result[name] = e;
          }
        });
      return result;
    })
  };
});

module.exports = {
  solidity: {
    compilers,
    overrides: {
      "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol": {
        version: "0.7.6",
        settings: {
          optimizer
        }
      }
    }
  },
  mocha: {
    timeout: '100000'
  },
  networks: {
    hardhat: {
      forking: {
        url: mainnetUrl,
        chainId: mainnetChainId
      },
      saveDeployments: true
    },
    mainnet: {
      url: mainnetUrl,
      chainId: mainnetChainId,
      accounts: { mnemonic: process.env.MAINNET_DEPLOY_MNEMONIC },
      saveDeployments: true
    },
    sepolia: {
      url: sepoliaUrl,
      chainId: sepoliaChainId,
      accounts: { mnemonic: process.env.MNEMONIC },
      saveDeployments: true
    },
  },
  namedAccounts: {
    deployer: 0
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true" ? true : false,
    currency: "USD"
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  verify: {
    etherscan: {
      apiKey: process.env.ETHERSCAN_API_KEY
    }
  },
  docgen: {
    path: './docs',
    clear: true,
    runOnCompile: process.env.DOCGEN === "true" ? true : false
  },
  abiExporter: {
    path: './abis',
    flat: false,
    pretty: true
  }
};
