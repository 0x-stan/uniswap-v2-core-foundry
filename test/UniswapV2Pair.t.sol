// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/TestHelper.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {UniswapV2Factory} from "../src/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";
import {TestERC20} from "./utils/TestERC20.sol";

contract UniswapV2PairTest is TestHelper {
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

    // mint
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

    function addLiquidity(
        address minter,
        uint256 tokenAmount0,
        uint256 tokenAmount1
    ) internal {
        tokenA.transfer(pairAddress, tokenAmount0);
        tokenB.transfer(pairAddress, tokenAmount1);
        pair.mint(minter);
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
}
