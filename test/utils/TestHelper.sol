// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IUniswapV2ERC20} from "../../src/interfaces/IUniswapV2ERC20.sol";

contract TestHelper is Test {
    address owner = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    uint256 alicePrivateKey = 0xA11CE;
    uint256 bobPrivateKey = 0xB0B;

    address alice = vm.addr(alicePrivateKey);
    address bob = vm.addr(bobPrivateKey);

    function getApprovalDigest(
        IUniswapV2ERC20 token,
        address _owner,
        address _spender,
        uint256 _value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            token.PERMIT_TYPEHASH(),
                            _owner,
                            _spender,
                            _value,
                            nonce,
                            deadline
                        )
                    )
                )
            );
    }

    function getCreate2Address(
        address factory,
        address tokenA,
        address tokenB,
        bytes memory bytecode
    ) internal view returns (address addr) {
        (tokenA, tokenB) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        bytes32 h = keccak256(
            abi.encodePacked(
                type(uint8).max,
                factory,
                keccak256(abi.encode(tokenA, tokenB)),
                keccak256(bytecode)
            )
        );
        assembly {
            h := shl(96, h)
        }
        addr = address(bytes20(h));
    }
}
