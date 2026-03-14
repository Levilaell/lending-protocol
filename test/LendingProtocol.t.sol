// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOracle} from "../src/MockOracle.sol";
import {LendingProtocol} from "../src/LendingProtocol.sol";

contract LendingProtocolTest is Test {
    LendingProtocol public lp;
    MockOracle public oracle;
    MockERC20 public collateralToken;
    MockERC20 public borrowToken;
    address public alice;
    address public bob;

    function setUp() public {
        oracle = new MockOracle();
        oracle.setPrice(2000e18);

        collateralToken = new MockERC20("ETH", "Ethereum");
        borrowToken = new MockERC20("USD", "Dolar");

        lp = new LendingProtocol(
            address(collateralToken),
            address(borrowToken),
            address(oracle)
        );

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        collateralToken.mint(alice, 1000 ether);
        collateralToken.mint(bob, 1000 ether);

        borrowToken.mint(alice, 1000 ether);
        borrowToken.mint(bob, 1000 ether);

        vm.prank(alice);
        collateralToken.approve(address(lp), type(uint256).max);

        vm.prank(alice);
        borrowToken.approve(address(lp), type(uint256).max);

        vm.prank(bob);
        borrowToken.approve(address(lp), type(uint256).max);

        borrowToken.mint(address(lp), 10000 ether);
    }

    function test_Deposit() public {
        vm.prank(alice);
        lp.deposit(1000 ether);

        (uint collateral, ) = lp.positions(alice);
        assertEq(collateral, 1000 ether);
    }

    function test_Borrow() public {
        vm.prank(alice);
        lp.deposit(1 ether);

        vm.prank(alice);
        lp.borrow(1000 ether);

        (, uint debt) = lp.positions(alice);
        assertEq(debt, 1000 ether);
        assertGt(borrowToken.balanceOf(alice), 1000 ether);
    }

    function test_Repay() public {
        vm.prank(alice);
        lp.deposit(1 ether);

        vm.prank(alice);
        lp.borrow(1000 ether);

        vm.prank(alice);
        lp.repay(1000 ether);

        (, uint debt) = lp.positions(alice);
        assertEq(debt, 0);
    }

    function test_Liquidate() public {
        vm.prank(alice);
        lp.deposit(1 ether);

        vm.prank(alice);
        lp.borrow(1000 ether);

        // ETH cai para $1,200 — posição fica insolvente
        oracle.setPrice(1200e18);

        vm.prank(bob);
        lp.liquidate(alice, 500 ether);

        (, uint debt) = lp.positions(alice);
        assertLt(debt, 1000 ether);
        assertGt(collateralToken.balanceOf(bob), 0);
    }

    function test_RevertWhen_BorrowExceedsLTV() public {
        vm.prank(alice);
        lp.deposit(1 ether);

        vm.expectRevert("insufficient collateral");
        vm.prank(alice);
        lp.borrow(1600 ether);
    }

    function test_RevertWhen_LiquidateHealthyPosition() public {
        vm.prank(alice);
        lp.deposit(1 ether);

        vm.prank(alice);
        lp.borrow(1000 ether);

        vm.expectRevert("position is healthy");
        vm.prank(bob);
        lp.liquidate(alice, 500 ether);
    }

    function test_RevertWhen_RepayMoreThanDebt() public {
        vm.prank(alice);
        lp.deposit(1 ether);

        vm.prank(alice);
        lp.borrow(500 ether);

        vm.expectRevert("more than debt");
        vm.prank(alice);
        lp.repay(1000 ether);
    }
}
