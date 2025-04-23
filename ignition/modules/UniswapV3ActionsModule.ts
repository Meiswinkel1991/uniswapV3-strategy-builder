import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UniswapV3ActionsModule = buildModule("UniswapV3ActionsModule", (m) => {
  const factory = m.getParameter("factory");
  const poositionManager = m.getParameter("positionManager");

  const lpAction = m.contract("UniswapV3LPActions", [
    poositionManager,
    factory,
  ]);

  return {
    lpAction,
  };
});

export default UniswapV3ActionsModule;
