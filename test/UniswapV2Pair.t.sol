// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/TestHelper.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {UniswapV2Factory} from "../src/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";
import {TestERC20} from "./utils/TestERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract UniswapV2PairTest is TestHelper {
    using SafeMath for uint256;

    IUniswapV2Factory factory;
    TestERC20 tokenA;
    TestERC20 tokenB;
    UniswapV2Pair pair;
    address pairAddress;

    uint256 constant MINIMUM_LIQUIDITY = 1e3;
    uint256 constant TOTALSUPPLY = 10000e18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function setUp() public {
        tokenA = new TestERC20(
            owner,
            "tokenA",
            "tokenA",
            uint8(18),
            TOTALSUPPLY
        );
        tokenB = new TestERC20(
            owner,
            "tokenB",
            "tokenB",
            uint8(18),
            TOTALSUPPLY
        );

        (tokenA, tokenB) = address(tokenA) < address(tokenB)
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        factory = new UniswapV2Factory(owner);
        pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = UniswapV2Pair(pairAddress);
    }

    function addLiquidity(
        address minter,
        uint256 tokenAmount0,
        uint256 tokenAmount1
    ) internal {
        vm.prank(owner);
        tokenA.mint(owner, tokenAmount0);
        tokenB.mint(owner, tokenAmount1);
        tokenA.transfer(pairAddress, tokenAmount0);
        tokenB.transfer(pairAddress, tokenAmount1);
        pair.mint(minter);
    }

    function calc_expectedOutputAmount(uint256 inputAmount, uint256 inputIndex)
        internal
        view
        returns (uint256 outputAmount)
    {
        (uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves(); // gas savings
        uint256 reserve0 = uint256(_reserve0).mul(1000);
        uint256 reserve1 = uint256(_reserve1).mul(1000);
        uint256 k = reserve0.mul(reserve1);

        uint256 balanceInputAfter = inputIndex == 0
            ? reserve0.add(inputAmount.mul(997))
            : reserve1.add(inputAmount.mul(997));

        outputAmount = k.div(balanceInputAfter);
        outputAmount = inputIndex == 0
            ? reserve1.sub(outputAmount).div(1000)
            : reserve0.sub(outputAmount).div(1000);
    }

    function test_mint() public {
        uint256 tokenAmount0 = 1e18;
        uint256 tokenAmount1 = 4e18;
        vm.prank(owner);
        tokenA.transfer(pairAddress, tokenAmount0);
        tokenB.transfer(pairAddress, tokenAmount1);

        uint256 expectedLiquidity = 2e18;
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(0), MINIMUM_LIQUIDITY);
        vm.expectEmit(true, true, true, true);
        emit Transfer(
            address(0),
            address(owner),
            expectedLiquidity - MINIMUM_LIQUIDITY
        );
        vm.expectEmit(true, true, true, true);
        emit Sync(uint112(tokenAmount0), uint112(tokenAmount1));
        vm.expectEmit(true, true, true, true);
        emit Mint(address(owner), tokenAmount0, tokenAmount1);

        pair.mint(address(owner));

        assertEq(pair.totalSupply(), expectedLiquidity);
        assertEq(
            pair.balanceOf(address(owner)),
            expectedLiquidity - MINIMUM_LIQUIDITY
        );
        assertEq(tokenA.balanceOf(pairAddress), tokenAmount0);
        assertEq(tokenB.balanceOf(pairAddress), tokenAmount1);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, tokenAmount0);
        assertEq(reserve1, tokenAmount1);
    }

    function test_burn() public {
        uint256 tokenAmount0 = 3e18;
        uint256 tokenAmount1 = 3e18;

        addLiquidity(owner, tokenAmount0, tokenAmount1);
        uint256 expectedLiquidity = 3e18;
        pair.transfer(pairAddress, expectedLiquidity - MINIMUM_LIQUIDITY);

        vm.expectEmit(true, true, true, true);
        emit Transfer(
            pairAddress,
            address(0),
            expectedLiquidity - MINIMUM_LIQUIDITY
        );
        vm.expectEmit(true, true, true, true);
        emit Transfer(pairAddress, owner, tokenAmount0 - 1000);
        vm.expectEmit(true, true, true, true);
        emit Transfer(pairAddress, owner, tokenAmount1 - 1000);
        vm.expectEmit(true, true, true, true);
        emit Sync(1000, 1000);
        vm.expectEmit(true, true, true, true);
        emit Burn(owner, tokenAmount0 - 1000, tokenAmount1 - 1000, owner);

        pair.burn(owner);

        assertEq(pair.balanceOf(owner), 0);
        assertEq(pair.totalSupply(), MINIMUM_LIQUIDITY);
        assertEq(tokenA.balanceOf(pairAddress), 1000);
        assertEq(tokenB.balanceOf(pairAddress), 1000);

        assertEq(tokenA.balanceOf(owner), tokenA.totalSupply() - 1000);
        assertEq(tokenB.balanceOf(owner), tokenB.totalSupply() - 1000);
    }

    // swap:token0
    function test_swap_token0() public {
        uint256 tokenAmount0 = 5e18;
        uint256 tokenAmount1 = 10e18;
        addLiquidity(owner, tokenAmount0, tokenAmount1);

        uint256 swapAmount = 1e18;
        uint256 expectedOutputAmount = calc_expectedOutputAmount(swapAmount, 0);
        tokenA.transfer(pairAddress, swapAmount);

        vm.expectEmit(true, true, true, true);
        emit Transfer(pairAddress, owner, expectedOutputAmount);
        vm.expectEmit(true, true, true, true);
        emit Sync(
            uint112(tokenAmount0 + swapAmount),
            uint112(tokenAmount1 - expectedOutputAmount)
        );
        vm.expectEmit(true, true, true, true);
        emit Swap(owner, swapAmount, 0, 0, expectedOutputAmount, owner);

        pair.swap(0, expectedOutputAmount, owner, "");

        (uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves();
        assertEq(_reserve0, uint112(tokenAmount0 + swapAmount));
        assertEq(_reserve1, uint112(tokenAmount1 - expectedOutputAmount));

        assertEq(tokenA.balanceOf(pairAddress), tokenAmount0 + swapAmount);
        assertEq(
            tokenB.balanceOf(pairAddress),
            tokenAmount1 - expectedOutputAmount
        );

        assertEq(
            tokenA.balanceOf(owner),
            tokenA.totalSupply() - tokenAmount0 - swapAmount
        );
        assertEq(
            tokenB.balanceOf(owner),
            tokenB.totalSupply() - tokenAmount1 + expectedOutputAmount
        );
    }

    function test_swap_token0_fuzzing(
        uint112 swapAmount,
        uint112 tokenAmount0,
        uint112 tokenAmount1
    ) public {
        vm.assume(tokenAmount0 >= 1e18 && tokenAmount0 < type(uint112).max);
        vm.assume(tokenAmount1 >= 1e18 && tokenAmount1 < type(uint112).max);
        vm.assume(
            swapAmount > 5e17 && swapAmount < type(uint112).max - tokenAmount0
        );

        addLiquidity(owner, uint256(tokenAmount0), uint256(tokenAmount1));
        uint256 expectedOutputAmount = calc_expectedOutputAmount(
            uint256(swapAmount),
            0
        );

        vm.prank(owner);
        tokenA.mint(owner, swapAmount);
        tokenA.transfer(pairAddress, uint256(swapAmount));

        vm.expectRevert("UniswapV2: K");
        pair.swap(0, expectedOutputAmount.add(1), owner, "");

        pair.swap(0, expectedOutputAmount, owner, "");
    }

    function test_swap_token1_fuzzing(
        uint112 swapAmount,
        uint112 tokenAmount0,
        uint112 tokenAmount1
    ) public {
        vm.assume(tokenAmount0 >= 1e18 && tokenAmount0 < type(uint112).max);
        vm.assume(tokenAmount1 >= 1e18 && tokenAmount1 < type(uint112).max);
        vm.assume(
            swapAmount > 5e17 && swapAmount < type(uint112).max - tokenAmount1
        );

        addLiquidity(owner, uint256(tokenAmount0), uint256(tokenAmount1));
        uint256 expectedOutputAmount = calc_expectedOutputAmount(
            uint256(swapAmount),
            1
        );

        vm.prank(owner);
        tokenB.mint(owner, swapAmount);
        tokenB.transfer(pairAddress, uint256(swapAmount));

        vm.expectRevert("UniswapV2: K");
        pair.swap(expectedOutputAmount.add(1), 0, owner, "");

        pair.swap(expectedOutputAmount, 0, owner, "");
    }
}
