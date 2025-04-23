// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IAction} from "strategy-builder-plugin/contracts/interfaces/IAction.sol";
import {UniswapV3LPActions} from "contracts/action/UniswapV3LPActions.sol";
import {IUniswapV3LPActions} from "contracts/action/interfaces/IUniswapV3LPActions.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV3LPActionsTest is Test {
    error ExecutionFailed(IAction.PluginExecution execution);

    UniswapV3LPActions public uniswapV3Actions;

    address public constant POSITION_MANAGER =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public constant FACTORY =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    address public WALLET = makeAddr("WALLET");

    function setUp() public {
        // Fork mainnet at latest block
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        uniswapV3Actions = new UniswapV3LPActions(POSITION_MANAGER, FACTORY);
    }

    function test_mint_Success() external {
        address pool = IUniswapV3Factory(FACTORY).getPool(WETH9, DAI, poolFee);

        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        uint256 amount0 = 100e18;
        uint256 amount1 = 1e18;

        deal(DAI, WALLET, amount0);
        deal(WETH9, WALLET, amount1);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: DAI,
                token1: WETH9,
                fee: poolFee,
                tickLower: (int24(-887272) / tickSpacing) * tickSpacing,
                tickUpper: (int24(887272) / tickSpacing) * tickSpacing,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: WALLET,
                deadline: block.timestamp
            });

        IAction.PluginExecution[] memory executions = uniswapV3Actions.mint(
            params
        );

        execute(executions);

        uint256 tokenId = INonfungiblePositionManager(POSITION_MANAGER)
            .tokenOfOwnerByIndex(WALLET, 0);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 currentLiqudity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        assertTrue(currentLiqudity > 0);
        assertTrue(amount0 > IERC20(DAI).balanceOf(address(WALLET)));
        assertTrue(amount1 > IERC20(WETH9).balanceOf(address(WALLET)));
    }

    function test_increaseLiquidity_Success() external {
        // mint 50%
        address pool = IUniswapV3Factory(FACTORY).getPool(WETH9, DAI, poolFee);

        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        uint256 amount0 = 100e18;
        uint256 amount1 = 1e18;

        deal(DAI, WALLET, amount0);
        deal(WETH9, WALLET, amount1);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: DAI,
                token1: WETH9,
                fee: poolFee,
                tickLower: (int24(-887272) / tickSpacing) * tickSpacing,
                tickUpper: (int24(887272) / tickSpacing) * tickSpacing,
                amount0Desired: (amount0 * 50) / 100,
                amount1Desired: (amount1 * 50) / 100,
                amount0Min: 0,
                amount1Min: 0,
                recipient: WALLET,
                deadline: block.timestamp
            });

        IAction.PluginExecution[] memory executions = uniswapV3Actions.mint(
            params
        );

        execute(executions);

        //act
        uint256 tokenId = INonfungiblePositionManager(POSITION_MANAGER)
            .tokenOfOwnerByIndex(WALLET, 0);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 liquidityBefore,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        IAction.PluginExecution[] memory executions2 = uniswapV3Actions
            .increaseLiquidity(
                INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: (amount0 * 50) / 100,
                    amount1Desired: (amount1 * 50) / 100,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: 0
                })
            );
        execute(executions2);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 currentLiqudity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        assertTrue(currentLiqudity > liquidityBefore);
    }

    function test_decreaseLiquidity_Success() external {
        address pool = IUniswapV3Factory(FACTORY).getPool(WETH9, DAI, poolFee);

        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        uint256 amount0 = 100e18;
        uint256 amount1 = 1e18;

        deal(DAI, WALLET, amount0);
        deal(WETH9, WALLET, amount1);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: DAI,
                token1: WETH9,
                fee: poolFee,
                tickLower: (int24(-887272) / tickSpacing) * tickSpacing,
                tickUpper: (int24(887272) / tickSpacing) * tickSpacing,
                amount0Desired: (amount0),
                amount1Desired: (amount1),
                amount0Min: 0,
                amount1Min: 0,
                recipient: WALLET,
                deadline: block.timestamp
            });

        IAction.PluginExecution[] memory executions = uniswapV3Actions.mint(
            params
        );

        execute(executions);

        uint256 tokenId = INonfungiblePositionManager(POSITION_MANAGER)
            .tokenOfOwnerByIndex(WALLET, 0);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 liquidityBefore,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        uint128 decreaseLiqudity = (liquidityBefore * 50) / 100;

        IAction.PluginExecution[] memory executions2 = uniswapV3Actions
            .decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: decreaseLiqudity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: 0
                })
            );
        execute(executions2);

        assertTrue(liquidityBefore > decreaseLiqudity);
    }

    function test_AddLiqudity_Success_AlreadyMinted(
        uint256 _amount0,
        uint256 _amount1
    ) external {
        uint256 amount0 = bound(_amount0, 100e18, 1000e18);
        uint256 amount1 = bound(_amount1, 1e18, 100e18);
        deal(DAI, WALLET, amount0);
        deal(WETH9, WALLET, amount1);

        address pool = IUniswapV3Factory(FACTORY).getPool(DAI, WETH9, poolFee);
        (, int24 actualTick, , , , , ) = IUniswapV3Pool(pool).slot0();
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        IAction.PluginExecution[] memory executions = uniswapV3Actions
            .addLiqudity(
                IUniswapV3LPActions.AddLiqudityParams({
                    token0: DAI,
                    token1: WETH9,
                    fee: poolFee,
                    tickLower: ((actualTick - 10 * tickSpacing) / tickSpacing) *
                        tickSpacing,
                    tickUpper: ((actualTick + 10 * tickSpacing) / tickSpacing) *
                        tickSpacing,
                    amount0Desired: (amount0 * 50) / 100,
                    amount1Desired: (amount1 * 50) / 100,
                    amount0Min: 0,
                    amount1Min: 0,
                    wallet: WALLET
                })
            );

        execute(executions);
        uint256 tokenId = INonfungiblePositionManager(POSITION_MANAGER)
            .tokenOfOwnerByIndex(WALLET, 0);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 liquidityBefore,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        IAction.PluginExecution[] memory executions2 = uniswapV3Actions
            .addLiqudity(
                IUniswapV3LPActions.AddLiqudityParams({
                    token0: DAI,
                    token1: WETH9,
                    fee: poolFee,
                    tickLower: ((actualTick - 10 * tickSpacing) / tickSpacing) *
                        tickSpacing,
                    tickUpper: ((actualTick + 10 * tickSpacing) / tickSpacing) *
                        tickSpacing,
                    amount0Desired: (amount0 * 50) / 100,
                    amount1Desired: (amount1 * 50) / 100,
                    amount0Min: 0,
                    amount1Min: 0,
                    wallet: WALLET
                })
            );
        execute(executions2);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 currentLiqudity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        assertTrue(currentLiqudity > liquidityBefore);
    }

    function test_addLiqudityPercentage_Success(
        uint256 _amount0,
        uint256 _amount1,
        uint256 _percentage
    ) external {
        uint256 amount0 = bound(_amount0, 100e18, 1000e18);
        uint256 amount1 = bound(_amount1, 1e18, 100e18);
        uint256 percentage = bound(
            _percentage,
            1,
            uniswapV3Actions.PERCENTAGE_FACTOR()
        );
        deal(DAI, WALLET, amount0);
        deal(WETH9, WALLET, amount1);

        // get the expected amount of tokens
        address pool = IUniswapV3Factory(FACTORY).getPool(DAI, WETH9, poolFee);
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(
            (int24(-887272) / tickSpacing) * tickSpacing
        );
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(
            (int24(887272) / tickSpacing) * tickSpacing
        );

        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }

        uint160 expLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            amount0,
            amount1
        );

        IAction.PluginExecution[] memory executions = uniswapV3Actions
            .addLiqudityPercentage(
                IUniswapV3LPActions.AddLiqudityPercentageParams({
                    token0: DAI,
                    token1: WETH9,
                    fee: poolFee,
                    wallet: WALLET,
                    percentage: percentage,
                    tickLower: (int24(-887272) / tickSpacing) * tickSpacing,
                    tickUpper: (int24(887272) / tickSpacing) * tickSpacing
                })
            );

        execute(executions);

        uint256 tokenId = INonfungiblePositionManager(POSITION_MANAGER)
            .tokenOfOwnerByIndex(WALLET, 0);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 currentLiqudity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        assertTrue(
            isApproximatelyEqual(
                currentLiqudity,
                (expLiquidity * percentage) /
                    uniswapV3Actions.PERCENTAGE_FACTOR(),
                100
            )
        );

        assertTrue(amount0 > IERC20(DAI).balanceOf(address(WALLET)));
        assertTrue(amount1 > IERC20(WETH9).balanceOf(address(WALLET)));
    }

    function test_removeLiquidity_Success(
        uint256 _amount0,
        uint256 _amount1
    ) external {
        uint256 amount0 = bound(_amount0, 100e18, 1000e18);
        uint256 amount1 = bound(_amount1, 1e18, 100e18);
        deal(DAI, WALLET, amount0);
        deal(WETH9, WALLET, amount1);

        //Add liquidity
        address pool = IUniswapV3Factory(FACTORY).getPool(DAI, WETH9, poolFee);
        // (, int24 actualTick,,,,, ) = IUniswapV3Pool(pool).slot0();
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        IAction.PluginExecution[] memory executions = uniswapV3Actions
            .addLiqudity(
                IUniswapV3LPActions.AddLiqudityParams({
                    token0: DAI,
                    token1: WETH9,
                    fee: poolFee,
                    tickLower: (TickMath.MIN_TICK / tickSpacing) * tickSpacing,
                    tickUpper: (TickMath.MAX_TICK / tickSpacing) * tickSpacing,
                    amount0Desired: (amount0 * 50) / 100,
                    amount1Desired: (amount1 * 50) / 100,
                    amount0Min: 0,
                    amount1Min: 0,
                    wallet: WALLET
                })
            );

        execute(executions);
        uint256 tokenId = INonfungiblePositionManager(POSITION_MANAGER)
            .tokenOfOwnerByIndex(WALLET, 0);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 liquidityBefore,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        IAction.PluginExecution[] memory executions2 = uniswapV3Actions
            .removeLiquidity(
                IUniswapV3LPActions.RemoveLiquidityParams({
                    token0: DAI,
                    token1: WETH9,
                    fee: poolFee,
                    tickLower: (TickMath.MIN_TICK / tickSpacing) * tickSpacing,
                    tickUpper: (TickMath.MAX_TICK / tickSpacing) * tickSpacing,
                    liquidity: (liquidityBefore * 50) / 100,
                    amount0Min: 0,
                    amount1Min: 0,
                    wallet: WALLET
                })
            );

        execute(executions2);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 currentLiqudity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(POSITION_MANAGER).positions(tokenId);

        assertTrue(liquidityBefore > currentLiqudity);
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃       HELPER         ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━┛

    function execute(IAction.PluginExecution[] memory executions) internal {
        for (uint256 i = 0; i < executions.length; i++) {
            IAction.PluginExecution memory execution = executions[i];

            vm.prank(WALLET);
            (bool success, ) = payable(execution.target).call{
                value: execution.value
            }(execution.data);
            if (!success) {
                revert ExecutionFailed(execution);
            }
        }
    }

    function isApproximatelyEqual(
        uint256 target,
        uint256 current,
        uint256 tolerance
    ) public pure returns (bool) {
        if (target > current) {
            return (target - current) <= tolerance;
        } else {
            return (current - target) <= tolerance;
        }
    }
}
