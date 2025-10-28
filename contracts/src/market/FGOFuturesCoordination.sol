// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../fgo/FGOLibrary.sol";
import "../fgo/FGOErrors.sol";
import "../interfaces/IFGOContracts.sol";
import "./FGOMarketLibrary.sol";

contract FGOFuturesCoordination {
    address public factory;

    mapping(address => mapping(uint256 => mapping(address => uint256)))
        private _futuresCredits;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        private _pendingPurchases;
    mapping(address => mapping(uint256 => FGOMarketLibrary.FuturesPosition))
        private _futuresPositions;
    mapping(address => mapping(uint256 => mapping(address => FGOMarketLibrary.FuturesSellOrder[])))
        private _sellOrders;
    mapping(address => mapping(uint256 => uint256)) private _nextOrderId;

    event FuturesPositionCreated(
        address indexed childContract,
        uint256 indexed childId,
        address indexed supplier,
        uint256 totalAmount,
        uint256 pricePerUnit,
        uint256 deadline
    );

    event FuturesPurchased(
        address indexed childContract,
        uint256 indexed childId,
        address indexed buyer,
        uint256 amount,
        uint256 totalCost
    );

    event FuturesSettled(
        address indexed childContract,
        uint256 indexed childId,
        address indexed buyer,
        uint256 credits
    );

    event FuturesCreditsConsumed(
        address indexed childContract,
        uint256 indexed childId,
        address indexed consumer,
        uint256 amount
    );

    event FuturesPositionClosed(
        address indexed childContract,
        uint256 indexed childId,
        address indexed supplier
    );

    event FuturesSellOrderCreated(
        address indexed childContract,
        uint256 indexed childId,
        address indexed seller,
        uint256 orderId,
        uint256 amount,
        uint256 pricePerUnit
    );

    event FuturesSellOrderFilled(
        address indexed childContract,
        uint256 indexed childId,
        address indexed seller,
        address buyer,
        uint256 orderId,
        uint256 amount,
        uint256 totalCost
    );

    event FuturesSellOrderCancelled(
        address indexed childContract,
        uint256 indexed childId,
        address indexed seller,
        uint256 orderId
    );

    modifier onlyApprovedContract() {
        if (
            factory == address(0) ||
            !IFGOFactory(factory).isValidContract(msg.sender)
        ) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    modifier onlyChildContract() {
        if (
            factory == address(0) ||
            !IFGOFactory(factory).isValidChild(msg.sender)
        ) {
            revert FGOErrors.Unauthorized();
        }
        _;
    }

    constructor(address _factory) {
        factory = _factory;
    }

    function createFuturesPosition(
        address childContract,
        uint256 childId,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 deadline
    ) external onlyChildContract {
        FGOLibrary.ChildMetadata memory child = IFGOChild(childContract)
            .getChildMetadata(childId);

        if (!child.futures.isFutures) {
            revert FGOErrors.InvalidStatus();
        }

        if (_futuresPositions[childContract][childId].isActive) {
            revert FGOErrors.InvalidStatus();
        }

        _futuresPositions[childContract][childId] = FGOMarketLibrary
            .FuturesPosition({
                supplier: msg.sender,
                totalAmount: amount,
                soldAmount: 0,
                pricePerUnit: pricePerUnit,
                deadline: deadline,
                isSettled: false,
                isActive: true
            });

        emit FuturesPositionCreated(
            childContract,
            childId,
            msg.sender,
            amount,
            pricePerUnit,
            deadline
        );
    }

    function buyFutures(
        address childContract,
        uint256 childId,
        uint256 amount
    ) external payable {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (!position.isActive) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.deadline > 0 && block.timestamp >= position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (amount > 0) {
            if (position.soldAmount + amount > position.totalAmount) {
                revert FGOErrors.InsufficientSupply();
            }
        }

        uint256 totalCost = amount * position.pricePerUnit;

        FGOAccessControl childAccessControl = IFGOChild(childContract)
            .accessControl();
        address paymentToken = childAccessControl.PAYMENT_TOKEN();

        if (paymentToken == address(0)) {
            if (msg.value != totalCost) {
                revert FGOErrors.InsufficientPayment();
            }

            (bool success, ) = payable(position.supplier).call{
                value: totalCost
            }("");
            if (!success) {
                revert FGOErrors.InsufficientPayment();
            }
        } else {
            IERC20(paymentToken).transferFrom(
                msg.sender,
                position.supplier,
                totalCost
            );
        }

        position.soldAmount += amount;

        _pendingPurchases[childContract][childId][msg.sender] += amount;

        emit FuturesPurchased(
            childContract,
            childId,
            msg.sender,
            amount,
            totalCost
        );
    }

    function settleFutures(
        address childContract,
        uint256 childId,
        address buyer,
        uint256 amount
    ) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (!position.isActive) {
            revert FGOErrors.InvalidStatus();
        }

        uint256 purchaseAmount = _pendingPurchases[childContract][childId][
            buyer
        ];

        if (purchaseAmount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (position.deadline == 0) {
            if (msg.sender != buyer) {
                revert FGOErrors.Unauthorized();
            }

            if (amount == 0) {
                revert FGOErrors.ZeroValue();
            }

            FGOMarketLibrary.FuturesSellOrder[] storage orders = _sellOrders[
                childContract
            ][childId][buyer];

            uint256 totalInOrders = 0;
            for (uint256 i = 0; i < orders.length; ) {
                if (orders[i].isActive) {
                    totalInOrders += orders[i].amount;
                }
                unchecked {
                    ++i;
                }
            }

            uint256 availableToSettle = purchaseAmount - totalInOrders;

            if (amount > availableToSettle) {
                revert FGOErrors.InsufficientSupply();
            }
            _pendingPurchases[childContract][childId][buyer] -= amount;
            _futuresCredits[childContract][childId][buyer] += amount;

            emit FuturesSettled(childContract, childId, buyer, amount);
        } else {
            if (block.timestamp < position.deadline) {
                revert FGOErrors.InvalidStatus();
            }

            FGOMarketLibrary.FuturesSellOrder[] storage orders = _sellOrders[
                childContract
            ][childId][buyer];

            for (uint256 i = 0; i < orders.length; ) {
                if (orders[i].isActive) {
                    _futuresCredits[childContract][childId][buyer] += orders[i]
                        .amount;
                    _pendingPurchases[childContract][childId][buyer] -= orders[
                        i
                    ].amount;

                    emit FuturesSettled(
                        childContract,
                        childId,
                        buyer,
                        orders[i].amount
                    );

                    orders[i].isActive = false;

                    emit FuturesSellOrderCancelled(
                        childContract,
                        childId,
                        buyer,
                        orders[i].orderId
                    );
                }
                unchecked {
                    ++i;
                }
            }

            _futuresCredits[childContract][childId][buyer] += _pendingPurchases[childContract][childId][buyer];
         
            if (_pendingPurchases[childContract][childId][
            buyer
        ] > 0) {
                emit FuturesSettled(
                    childContract,
                    childId,
                    buyer,
                    _pendingPurchases[childContract][childId][
            buyer
        ]
                );
            }

            delete _pendingPurchases[childContract][childId][buyer];

            if (
                position.soldAmount == position.totalAmount
            ) {
                position.isSettled = true;
            }
        }
    }

    function getFuturesCredits(
        address childContract,
        uint256 childId,
        address designer
    ) external view returns (uint256) {
        return _futuresCredits[childContract][childId][designer];
    }

    function consumeFuturesCredits(
        address childContract,
        uint256 childId,
        address consumer,
        uint256 amount
    ) external onlyApprovedContract {
        if (_futuresCredits[childContract][childId][consumer] < amount) {
            revert FGOErrors.InsufficientSupply();
        }
        _futuresCredits[childContract][childId][consumer] -= amount;
        emit FuturesCreditsConsumed(childContract, childId, consumer, amount);
    }

    function getFuturesPosition(
        address childContract,
        uint256 childId
    ) external view returns (FGOMarketLibrary.FuturesPosition memory) {
        return _futuresPositions[childContract][childId];
    }

    function closeFuturesPosition(
        address childContract,
        uint256 childId
    ) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (!position.isActive) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.supplier != msg.sender) {
            revert FGOErrors.Unauthorized();
        }

        if (position.deadline > 0 && block.timestamp < position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        position.isActive = false;

        emit FuturesPositionClosed(childContract, childId, msg.sender);
    }

    function createSellOrder(
        address childContract,
        uint256 childId,
        uint256 amount,
        uint256 pricePerUnit
    ) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (!position.isActive) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.deadline > 0 && block.timestamp >= position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (pricePerUnit == 0) {
            revert FGOErrors.ZeroValue();
        }

        uint256 totalPending = _pendingPurchases[childContract][childId][
            msg.sender
        ];

        if (totalPending == 0) {
            revert FGOErrors.ZeroValue();
        }

        uint256 totalInOrders = 0;
        FGOMarketLibrary.FuturesSellOrder[] storage orders = _sellOrders[
            childContract
        ][childId][msg.sender];

        for (uint256 i = 0; i < orders.length; ) {
            if (orders[i].isActive) {
                totalInOrders += orders[i].amount;
            }
            unchecked {
                ++i;
            }
        }

        if (totalPending < totalInOrders + amount) {
            revert FGOErrors.InsufficientSupply();
        }

        uint256 orderId = _nextOrderId[childContract][childId];
        _nextOrderId[childContract][childId]++;

        orders.push(
            FGOMarketLibrary.FuturesSellOrder({
                seller: msg.sender,
                amount: amount,
                pricePerUnit: pricePerUnit,
                orderId: orderId,
                isActive: true
            })
        );

        emit FuturesSellOrderCreated(
            childContract,
            childId,
            msg.sender,
            orderId,
            amount,
            pricePerUnit
        );
    }

    function buySellOrder(
        address childContract,
        uint256 childId,
        address seller,
        uint256 orderId
    ) external payable {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (!position.isActive) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.deadline > 0 && block.timestamp >= position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        if (msg.sender == seller) {
            revert FGOErrors.Unauthorized();
        }

        FGOMarketLibrary.FuturesSellOrder[] storage orders = _sellOrders[
            childContract
        ][childId][seller];

        uint256 orderIndex = type(uint256).max;
        for (uint256 i = 0; i < orders.length; ) {
            if (orders[i].orderId == orderId && orders[i].isActive) {
                orderIndex = i;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (orderIndex == type(uint256).max) {
            revert FGOErrors.InvalidStatus();
        }

        FGOMarketLibrary.FuturesSellOrder storage order = orders[orderIndex];

        uint256 totalCost = order.amount * order.pricePerUnit;

        FGOAccessControl childAccessControl = IFGOChild(childContract)
            .accessControl();
        address paymentToken = childAccessControl.PAYMENT_TOKEN();

        if (paymentToken == address(0)) {
            if (msg.value != totalCost) {
                revert FGOErrors.InsufficientPayment();
            }

            (bool success, ) = payable(seller).call{value: totalCost}("");
            if (!success) {
                revert FGOErrors.InsufficientPayment();
            }
        } else {
            IERC20(paymentToken).transferFrom(msg.sender, seller, totalCost);
        }

        uint256 sellerPurchase = _pendingPurchases[childContract][childId][
            seller
        ];
        uint256 buyerPurchase = _pendingPurchases[childContract][childId][
            msg.sender
        ];

        sellerPurchase -= order.amount;
        buyerPurchase += order.amount;
        _pendingPurchases[childContract][childId][seller] = sellerPurchase;
        _pendingPurchases[childContract][childId][msg.sender] = buyerPurchase;
        order.isActive = false;

        emit FuturesSellOrderFilled(
            childContract,
            childId,
            seller,
            msg.sender,
            orderId,
            order.amount,
            totalCost
        );
    }

    function cancelSellOrder(
        address childContract,
        uint256 childId,
        uint256 orderId
    ) external {
        FGOMarketLibrary.FuturesSellOrder[] storage orders = _sellOrders[
            childContract
        ][childId][msg.sender];

        uint256 orderIndex = type(uint256).max;
        for (uint256 i = 0; i < orders.length; ) {
            if (orders[i].orderId == orderId && orders[i].isActive) {
                orderIndex = i;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (orderIndex == type(uint256).max) {
            revert FGOErrors.InvalidStatus();
        }

        orders[orderIndex].isActive = false;

        emit FuturesSellOrderCancelled(
            childContract,
            childId,
            msg.sender,
            orderId
        );
    }
}
