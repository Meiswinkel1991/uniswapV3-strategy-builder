// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV3SwapActions} from "../contracts/action/UniswapV3SwapActions.sol";
import {IAction} from "strategy-builder-plugin/contracts/interfaces/IAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

contract UniswapV3SwapActionsTest is Test {
    error ExecutionFailed(IAction.PluginExecution execution);

    UniswapV3SwapActions public uniswapV3Actions;

    address public constant SWAP_ROUTER =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 3000;

    address public WALLET = makeAddr("wallet");

    function setUp() public {
        // Fork mainnet at latest block
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        uniswapV3Actions = new UniswapV3SwapActions(SWAP_ROUTER, WETH9);
    }

    function test_SwapExactInputSingle_TokenIn_Success(uint256 _amount) public {
        uint256 amountIn = bound(_amount, 1e15, 1e24);

        console2.log("code", SWAP_ROUTER.code.length);

        deal(DAI, WALLET, amountIn);

        IAction.PluginExecution[] memory executions = uniswapV3Actions
            .swapExactInputSingle(WALLET, amountIn, 0, DAI, WETH9, poolFee);

        execute(executions);

        assertEq(IERC20(DAI).balanceOf(WALLET), 0);
        assertTrue(IERC20(WETH9).balanceOf(WALLET) > 0);
    }

    function test_swapExactInputSingle_ETHIn_Success(uint256 _amount) public {
        uint256 amountIn = bound(_amount, 1e15, 1e24);
        deal(WALLET, amountIn);

        IAction.PluginExecution[] memory executions = uniswapV3Actions
            .swapExactInputSingle(WALLET, amountIn, 0, WETH9, DAI, poolFee);

        execute(executions);

        assertTrue(WALLET.balance == 0);
        assertTrue(IERC20(DAI).balanceOf(WALLET) > 0);
    }

    function test_swapExactInput_ETHIn_Success(uint256 _amount) public {
        uint256 amountIn = bound(_amount, 1e15, 1e24);
        deal(WALLET, amountIn);
        IAction.PluginExecution[] memory executions = uniswapV3Actions
            .swapExactInput(
                WALLET,
                amountIn,
                0,
                abi.encodePacked(WETH9, uint24(500), USDC, uint24(100), DAI)
            );

        execute(executions);

        assertTrue(WALLET.balance == 0);
        assertTrue(IERC20(DAI).balanceOf(WALLET) > 0);
    }

    function test_swapExactInput_TokenIn_Success(uint256 _amountIn) public {
        uint256 amountIn = bound(_amountIn, 1e15, 1e24);
        deal(DAI, WALLET, amountIn);
        IAction.PluginExecution[] memory executions = uniswapV3Actions
            .swapExactInput(
                WALLET,
                amountIn,
                0,
                abi.encodePacked(DAI, uint24(100), USDC, uint24(500), WETH9)
            );

        execute(executions);
        assertTrue(IERC20(DAI).balanceOf(WALLET) == 0);
        assertTrue(IERC20(WETH9).balanceOf(WALLET) > 0);
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
}
