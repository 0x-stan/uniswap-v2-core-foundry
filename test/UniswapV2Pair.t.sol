// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/TestHelper.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Pair} from "../src/UniswapV2Pair.sol";

contract UniswapV2PairTest is TestHelper {

    IUniswapV2Pair pair;
    
    function setUp() public {
        pair = new UniswapV2Pair();
        console.log("UniswapV2PairTest setUp");
    }

}
