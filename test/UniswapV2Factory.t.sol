// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/TestHelper.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";
import {UniswapV2Factory} from "../src/UniswapV2Factory.sol";
import {TestERC20} from "./utils/TestERC20.sol";

contract UniswapV2FactoryTest is TestHelper {
    IUniswapV2Factory factory;
    TestERC20 tokenA;
    TestERC20 tokenB;

    uint256 constant TOTALSUPPLY = 10000e18;

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
    }

    function test_createPair() public {
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        address create2Address = getCreate2Address(
            address(factory),
            address(tokenA),
            address(tokenB),
            bytecode
        );

        factory.createPair(address(tokenA), address(tokenB));
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));

        assertEq(pairAddress, create2Address);

        // sort token address
        (tokenA, tokenB) = address(tokenA) < address(tokenB)
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
    }

    // feeTo, feeToSetter, allPairsLength
    function test_feeTo_feeToSetter_allPairsLength() public {
        assertEq(factory.feeTo(), address(0));
        assertEq(factory.feeToSetter(), owner);
        assertEq(factory.allPairsLength(), 0);
    }

    // setFeeTo
    function test_setFeeTo() public {
        vm.prank(alice);
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeTo(alice);

        vm.prank(owner);
        factory.setFeeTo(alice);
        assertEq(factory.feeTo(), alice);
    }

    // setFeeToSetter
    function test_setFeeToSetter() public {
        vm.prank(alice);
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeToSetter(alice);

        vm.prank(owner);
        factory.setFeeToSetter(alice);
        assertEq(factory.feeToSetter(), alice);
    }
}
