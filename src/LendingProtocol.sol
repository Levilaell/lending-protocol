// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOracle {
    function getPrice() external view returns (uint);
}

contract LendingProtocol {
    address public collateralToken;
    address public borrowToken;
    address public oracle;
    uint public constant LTV = 75;
    uint public constant LIQUIDATION_BONUS = 110;

    struct Position {
        uint collateral;
        uint debt;
    }

    mapping(address => Position) public positions;

    event Deposit(address indexed user, uint amount);
    event Borrow(address indexed user, uint amount);
    event Repay(address indexed user, uint amount);

    constructor(
        address _collateralToken,
        address _borrowToken,
        address _oracle
    ) {
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
        oracle = _oracle;
    }

    function deposit(uint amount) public {
        require(amount > 0, "insufficient value");

        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].collateral += amount;

        emit Deposit(msg.sender, amount);
    }

    function borrow(uint amount) public {
        require(amount > 0, "invalid amount");
        require(positions[msg.sender].collateral > 0, "no collateral");

        uint collateralPrice = IOracle(oracle).getPrice();
        uint debtAvailable = ((((positions[msg.sender].collateral *
            collateralPrice) / 1e18) * LTV) / 100) -
            (positions[msg.sender].debt);

        require(amount <= debtAvailable, "insufficient collateral");

        IERC20(borrowToken).transfer(msg.sender, amount);
        positions[msg.sender].debt += amount;

        emit Borrow(msg.sender, amount);
    }

    function repay(uint amount) public {
        require(amount > 0, "invalid amount");
        require(amount <= positions[msg.sender].debt, "more than debt");

        IERC20(borrowToken).transferFrom(msg.sender, address(this), amount);

        positions[msg.sender].debt -= amount;

        emit Repay(msg.sender, amount);
    }

    function liquidate(address borrower, uint debtToPay) public {
        require(debtToPay > 0, "invalid amount");
        require(debtToPay <= positions[borrower].debt);

        uint collateralPrice = IOracle(oracle).getPrice();
        uint collateralValue = (positions[borrower].collateral *
            collateralPrice) / 1e18;
        uint maxBorrow = (collateralValue * LTV) / 100;

        require(positions[borrower].debt > maxBorrow, "position is healthy");

        uint collateralAmount = (debtToPay * 1e18) / collateralPrice;

        IERC20(borrowToken).transferFrom(msg.sender, address(this), debtToPay);
        IERC20(collateralToken).transfer(
            msg.sender,
            (collateralAmount * LIQUIDATION_BONUS) / 100
        );

        positions[borrower].debt -= debtToPay;
        positions[borrower].collateral -=
            (collateralAmount * LIQUIDATION_BONUS) /
            100;
    }
}
