import { Network } from "./networks";
import { PluginContractDeployments, PluginContracts } from "./types";

export const deployedPluginContracts: PluginContractDeployments = {
  [Network.ARBITRUM_SEPOLIA]: {
    [PluginContracts.FEE_HANDLER]: "0x8804615641422382359690192207736354395780",
    [PluginContracts.FEE_CONTROLLER]:
      "0x0120811264322271481810714614225099001790",
    [PluginContracts.PRICE_ORACLE]:
      "0x7865283127140966149241704597935173581970",
    [PluginContracts.STRATEGY_BUILDER_PLUGIN]:
      "0x9955190000000000000000000000000000000000",
  },
};

export const uniswapV3Contracts: {
  [key in Network]?: { [key in string]: string };
} = {
  [Network.ARBITRUM_SEPOLIA]: {
    swapRouterV2: "0x101F443B4d1b059569D643917553c771E1b9663E",
    positionManager: "0x6b2937Bde17889EDCf8fbD8dE31C3C2a70Bc4d65",
  },
};
