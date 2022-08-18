// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/TestHelper.sol";
import {IUniswapV2ERC20} from "../src/interfaces/IUniswapV2ERC20.sol";
import {UniswapV2ERC20} from "../src/UniswapV2ERC20.sol";

contract UniswapV2ERC20Test is TestHelper {
    IUniswapV2ERC20 uniswapERC20;
    uint256 constant TOTALSUPPLY = 10000e18;
    uint256 constant TEST_AMOUNT = 10e18;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        uniswapERC20 = new UniswapV2ERC20();
    }

    // name, symbol, decimals, totalSupply, balanceOf, DOMAIN_SEPARATOR, PERMIT_TYPEHASH
    function test_atribbutes() public {
        assertEq(uniswapERC20.name(), "Uniswap V2");
        assertEq(uniswapERC20.decimals(), 18);
        assertEq(uniswapERC20.totalSupply(), TOTALSUPPLY);

        assertEq(uniswapERC20.balanceOf(owner), TOTALSUPPLY);

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        assertEq(
            uniswapERC20.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("Uniswap V2")),
                    keccak256(bytes("1")),
                    chainId,
                    address(uniswapERC20)
                )
            )
        );

        assertEq(
            uniswapERC20.PERMIT_TYPEHASH(),
            keccak256(
                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
            )
        );
    }

    // apporve
    function test_approve() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, alice, TEST_AMOUNT);
        uniswapERC20.approve(alice, TEST_AMOUNT);

        assertEq(uniswapERC20.allowance(owner, alice), TEST_AMOUNT);
    }

    // transfer
    function test_transfer() public {
        vm.prank(owner);
        uniswapERC20.transfer(alice, TEST_AMOUNT);

        assertEq(uniswapERC20.balanceOf(alice), TEST_AMOUNT);
    }

    // transfer:fail
    function test_transfer_fail() public {
        vm.prank(owner);
        // expect an arithmetic error on the next call (e.g. underflow)
        vm.expectRevert(stdError.arithmeticError);
        uniswapERC20.transfer(alice, TOTALSUPPLY + 1);

        vm.prank(alice);
        vm.expectRevert(stdError.arithmeticError);
        uniswapERC20.transfer(owner, 1);
    }

    // transferFrom
    function test_transferFrom() public {
        vm.prank(owner);
        uniswapERC20.approve(alice, TEST_AMOUNT);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, alice, TEST_AMOUNT);
        uniswapERC20.transferFrom(owner, alice, TEST_AMOUNT);

        assertEq(uniswapERC20.allowance(owner, alice), 0);
        assertEq(uniswapERC20.balanceOf(alice), TEST_AMOUNT);
        assertEq(uniswapERC20.balanceOf(owner), TOTALSUPPLY - TEST_AMOUNT);
    }

    // transferFrom:max
    function test_transferFrom_max() public {
        vm.prank(owner);
        uniswapERC20.approve(alice, type(uint256).max);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, alice, TEST_AMOUNT);
        uniswapERC20.transferFrom(owner, alice, TEST_AMOUNT);

        assertEq(uniswapERC20.allowance(owner, alice), type(uint256).max);
        assertEq(uniswapERC20.balanceOf(owner), TOTALSUPPLY - TEST_AMOUNT);
        assertEq(uniswapERC20.balanceOf(alice), TEST_AMOUNT);
    }

    // permit
    function test_permit() public {

        uint256 nonce = vm.getNonce(alice);
        uint256 deadline = type(uint256).max;

        bytes32 digest = getApprovalDigest(
            uniswapERC20,
            alice,
            bob,
            TEST_AMOUNT,
            nonce,
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, TEST_AMOUNT);
        uniswapERC20.permit(alice, bob, TEST_AMOUNT, deadline, v, r, s);

        assertEq(uniswapERC20.allowance(alice, bob), TEST_AMOUNT);
        // assertEq(vm.getNonce(alice), nonce + 1); // nonce not increase?
    }
}
