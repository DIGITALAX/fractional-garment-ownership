// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../fgo/FGOLibrary.sol";
import "../fgo/FGOErrors.sol";
import "../interfaces/IFGOContracts.sol";
import "./../futures/FGOFuturesAccessControl.sol";
import "./FGOMarketLibrary.sol";

contract FGOFuturesCoordination is ERC1155 {
    using SafeERC20 for IERC20;
    FGOFuturesAccessControl public futuresAccess;
    string public symbol;
    string public name;
    address public factory;
    address public lpTreasury;
    address public protocolTreasury;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_Settlement_REWARD_BPS = 100;
    uint256 public constant MAX_Settlement_REWARD_BPS = 300;
    uint256 private _protocolFeeBPS;
    uint256 private _lpFeeBPS;

    mapping(address => mapping(uint256 => mapping(address => uint256)))
        private _futuresCredits;
    mapping(address => mapping(uint256 => FGOMarketLibrary.FuturesPosition))
        private _futuresPositions;
    mapping(uint256 => uint256) private _settlementRewardPool;
    mapping(address => mapping(uint256 => mapping(address => FGOMarketLibrary.FuturesSellOrder[])))
        private _sellOrders;
    mapping(address => mapping(uint256 => uint256)) private _nextOrderId;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        private _pendingPurchases;
    mapping(address => mapping(uint256 => uint256)) private _futureTokenIds;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        private _reservedTokenAmounts;
    mapping(uint256 => FGOMarketLibrary.TokenMetadata) private _tokenInfo;

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

    event SettlementInitiated(
        address indexed childContract,
        uint256 indexed childId,
        address indexed settler,
        uint256 rewardAmount
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
    event FeesCollected(
        uint256 indexed orderId,
        uint256 protocolFee,
        uint256 lpFee
    );
    event FeesCollectedFuture(
        uint256 indexed tokenId,
        uint256 settlementFee,
        uint256 protocolFee,
        uint256 lpFee
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

    modifier onlyAdmin() {
        if (!futuresAccess.isAdmin(msg.sender)) {
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

    constructor(
        uint256 protocolFeeBPS,
        uint256 lpFeeBPS,
        address _futuresAccess,
        address _factory,
        address _lpTreasury,
        address _protocolTreasury
    ) ERC1155("") {
        factory = _factory;

        if (protocolFeeBPS > 1000) revert FGOErrors.InvalidAmount();
        if (lpFeeBPS > 1000) revert FGOErrors.InvalidAmount();
        if (_futuresAccess == address(0)) revert FGOErrors.InvalidAmount();
        if (_factory == address(0)) revert FGOErrors.InvalidAmount();
        if (_lpTreasury == address(0)) revert FGOErrors.InvalidAmount();
        if (_protocolTreasury == address(0)) revert FGOErrors.InvalidAmount();

        lpTreasury = _lpTreasury;
        protocolTreasury = _protocolTreasury;
        futuresAccess = FGOFuturesAccessControl(_futuresAccess);
        _protocolFeeBPS = protocolFeeBPS;
        _lpFeeBPS = lpFeeBPS;
        symbol = "FGOFC";
        name = "FGOFuturesCoordination";
    }

    function createFuturesPosition(
        address supplier,
        uint256 childId,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 deadline,
        uint256 settlementRewardBPS
    ) external onlyChildContract {
        FGOLibrary.ChildMetadata memory child = IFGOChild(msg.sender)
            .getChildMetadata(childId);

        if (!child.futures.isFutures) {
            revert FGOErrors.InvalidStatus();
        }

        if (amount == 0 || pricePerUnit == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (
            settlementRewardBPS < MIN_Settlement_REWARD_BPS ||
            settlementRewardBPS > MAX_Settlement_REWARD_BPS
        ) revert FGOFuturesErrors.InvalidSettlementReward();

        if (_futuresPositions[msg.sender][childId].isActive) {
            revert FGOErrors.InvalidStatus();
        }

        _getOrCreateTokenId(msg.sender, childId);

        _futuresPositions[msg.sender][childId] = FGOMarketLibrary
            .FuturesPosition({
                supplier: supplier,
                totalAmount: amount,
                soldAmount: 0,
                pricePerUnit: pricePerUnit,
                settlementRewardBPS: settlementRewardBPS,
                deadline: deadline,
                isSettled: false,
                isActive: true,
                isClosed: false
            });

        emit FuturesPositionCreated(
            msg.sender,
            childId,
            supplier,
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
        uint256 tokenId = _getOrCreateTokenId(childContract, childId);

        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (!position.isActive || position.isClosed) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.deadline > 0 && block.timestamp >= position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (position.soldAmount + amount > position.totalAmount) {
            revert FGOErrors.InsufficientSupply();
        }

        FGOAccessControl childAccessControl = IFGOChild(childContract)
            .accessControl();
        address paymentToken = childAccessControl.PAYMENT_TOKEN();

        uint256 basePrice = amount * position.pricePerUnit;
        uint256 settlementFee = 0;
        uint256 protocolFee = 0;
        uint256 lpFee = 0;
        uint256 sellerProceeds = 0;

        if (position.deadline > 0) {
            settlementFee = (basePrice * position.settlementRewardBPS) /
                BASIS_POINTS;
            protocolFee = ((basePrice - settlementFee) * _protocolFeeBPS) /
                BASIS_POINTS;
            lpFee = ((basePrice - settlementFee) * _lpFeeBPS) /
                BASIS_POINTS;
            sellerProceeds = basePrice -
                settlementFee -
                protocolFee -
                lpFee;
        } else {
            protocolFee = (basePrice * _protocolFeeBPS) / BASIS_POINTS;
            lpFee = (basePrice * _lpFeeBPS) / BASIS_POINTS;
            sellerProceeds = basePrice - protocolFee - lpFee;
        }

        if (paymentToken == address(0)) {
            if (msg.value != basePrice) {
                revert FGOErrors.InsufficientPayment();
            }

            (bool successSeller, ) = payable(position.supplier).call{
                value: sellerProceeds
            }("");
            if (!successSeller) {
                revert FGOErrors.InsufficientPayment();
            }

            (bool successProtocol, ) = payable(protocolTreasury).call{
                value: protocolFee
            }("");
            if (!successProtocol) {
                revert FGOErrors.InsufficientPayment();
            }

            (bool successLP, ) = payable(lpTreasury).call{value: lpFee}("");
            if (!successLP) {
                revert FGOErrors.InsufficientPayment();
            }
        } else {
            IERC20(paymentToken).safeTransferFrom(
                msg.sender,
                address(this),
                basePrice
            );

            IERC20(paymentToken).safeTransfer(
                position.supplier,
                sellerProceeds
            );

            IERC20(paymentToken).safeTransfer(protocolTreasury, protocolFee);

            IERC20(paymentToken).safeTransfer(lpTreasury, lpFee);
        }

        if (position.deadline > 0) {
            _settlementRewardPool[tokenId] += settlementFee;
        }

        position.soldAmount += amount;

        _pendingPurchases[childContract][childId][msg.sender] += amount;

        _mint(msg.sender, tokenId, amount, "");

        emit FuturesPurchased(
            childContract,
            childId,
            msg.sender,
            amount,
            basePrice
        );
        emit FeesCollectedFuture(tokenId, settlementFee, protocolFee, lpFee);
    }

    function settleFutures(
        address childContract,
        uint256 childId,
        address buyer,
        uint256 amount
    ) external {
        uint256 tokenId = _getOrCreateTokenId(childContract, childId);
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (position.deadline == 0) {
            if (msg.sender != buyer) {
                revert FGOErrors.Unauthorized();
            }

            if (amount == 0) {
                revert FGOErrors.ZeroValue();
            }

            uint256 balance = balanceOf(buyer, tokenId);
            uint256 reserved = _reservedTokenAmounts[childContract][childId][
                buyer
            ];
            uint256 availableToSettle = balance - reserved;

            if (amount > availableToSettle) {
                revert FGOErrors.InsufficientSupply();
            }

            _futuresCredits[childContract][childId][buyer] += amount;
            _pendingPurchases[childContract][childId][buyer] -= amount;
            _burn(buyer, tokenId, amount);

            emit FuturesSettled(childContract, childId, buyer, amount);
        } else {
            if (!position.isActive) {
                revert FGOErrors.InvalidStatus();
            }

            if (block.timestamp < position.deadline) {
                revert FGOErrors.InvalidStatus();
            }

            if (position.isSettled) {
                revert FGOErrors.InvalidStatus();
            }

            FGOAccessControl childAccessControl = IFGOChild(childContract)
                .accessControl();
            address paymentToken = childAccessControl.PAYMENT_TOKEN();

            position.isSettled = true;

            uint256 rewardAmount = _settlementRewardPool[tokenId];
            if (rewardAmount > 0) {
                _settlementRewardPool[tokenId] = 0;

                if (paymentToken == address(0)) {
                    (bool success, ) = payable(msg.sender).call{
                        value: rewardAmount
                    }("");
                    if (!success) {
                        revert FGOErrors.InsufficientPayment();
                    }
                } else {
                    IERC20(paymentToken).safeTransfer(msg.sender, rewardAmount);
                }
            }

            emit SettlementInitiated(childContract, childId, msg.sender, rewardAmount);
        }
    }

    function claimFuturesCredits(
        address childContract,
        uint256 childId
    ) external {
        uint256 tokenId = _getOrCreateTokenId(childContract, childId);
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (!position.isSettled) {
            revert FGOErrors.InvalidStatus();
        }

        uint256 balance = balanceOf(msg.sender, tokenId);
        if (balance == 0) {
            revert FGOErrors.ZeroValue();
        }

        _futuresCredits[childContract][childId][msg.sender] += balance;
        _burn(msg.sender, tokenId, balance);

        emit FuturesSettled(childContract, childId, msg.sender, balance);
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

        if (position.isClosed) {
            revert FGOErrors.InvalidStatus();
        }

        position.isClosed = true;

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

        if (!position.isActive && position.deadline > 0) {
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

        uint256 tokenId = _getOrCreateTokenId(childContract, childId);
        uint256 reservedAmount = _reservedTokenAmounts[childContract][childId][
            msg.sender
        ];
        uint256 ownedBalance = balanceOf(msg.sender, tokenId);

        if (ownedBalance < reservedAmount + amount) {
            revert FGOErrors.InsufficientSupply();
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

        _reservedTokenAmounts[childContract][childId][msg.sender] =
            reservedAmount +
            amount;

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
        uint256 tokenId = _getOrCreateTokenId(childContract, childId);
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            childContract
        ][childId];

        if (!position.isActive && position.deadline > 0) {
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
        uint256 protocolFee = (totalCost * _protocolFeeBPS) / BASIS_POINTS;
        uint256 lpFee = (totalCost * _lpFeeBPS) / BASIS_POINTS;
        uint256 sellerProceeds = totalCost - protocolFee - lpFee;

        if (balanceOf(seller, tokenId) < order.amount) {
            revert FGOErrors.InsufficientSupply();
        }

        if (paymentToken == address(0)) {
            if (msg.value != totalCost) {
                revert FGOErrors.InsufficientPayment();
            }

            (bool sellerSuccess, ) = payable(seller).call{
                value: sellerProceeds
            }("");
            if (!sellerSuccess) {
                revert FGOErrors.InsufficientPayment();
            }
            (bool lpSuccess, ) = payable(lpTreasury).call{value: lpFee}("");
            if (!lpSuccess) {
                revert FGOErrors.InsufficientPayment();
            }
            (bool protocolSuccess, ) = payable(protocolTreasury).call{
                value: protocolFee
            }("");
            if (!protocolSuccess) {
                revert FGOErrors.InsufficientPayment();
            }
        } else {
            IERC20(paymentToken).safeTransferFrom(
                msg.sender,
                seller,
                sellerProceeds
            );
            IERC20(paymentToken).safeTransferFrom(
                msg.sender,
                protocolTreasury,
                protocolFee
            );
            IERC20(paymentToken).safeTransferFrom(
                msg.sender,
                lpTreasury,
                lpFee
            );
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

        uint256 reserved = _reservedTokenAmounts[childContract][childId][
            seller
        ];
        if (reserved >= order.amount) {
            _reservedTokenAmounts[childContract][childId][seller] =
                reserved -
                order.amount;
        } else {
            _reservedTokenAmounts[childContract][childId][seller] = 0;
        }

        _safeTransferFrom(seller, msg.sender, tokenId, order.amount, "");

        emit FuturesSellOrderFilled(
            childContract,
            childId,
            seller,
            msg.sender,
            orderId,
            order.amount,
            totalCost
        );
        emit FeesCollected(orderId, protocolFee, lpFee);
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

        uint256 reserved = _reservedTokenAmounts[childContract][childId][
            msg.sender
        ];
        uint256 release = orders[orderIndex].amount;
        if (reserved >= release) {
            _reservedTokenAmounts[childContract][childId][msg.sender] =
                reserved -
                release;
        } else {
            _reservedTokenAmounts[childContract][childId][msg.sender] = 0;
        }

        emit FuturesSellOrderCancelled(
            childContract,
            childId,
            msg.sender,
            orderId
        );
    }

    function getLpFee() public view returns (uint256) {
        return _lpFeeBPS;
    }

    function getProtocolFee() public view returns (uint256) {
        return _protocolFeeBPS;
    }

    function setLpTreasury(address _lpTreasury) external onlyAdmin {
        if (_lpTreasury == address(0)) revert FGOErrors.InvalidAmount();
        lpTreasury = _lpTreasury;
    }

    function setProtocolTreasury(address _protocolTreasury) external onlyAdmin {
        if (_protocolTreasury == address(0)) revert FGOErrors.InvalidAmount();
        protocolTreasury = _protocolTreasury;
    }

    function setFuturesAccess(address _futuresAccess) external onlyAdmin {
        if (_futuresAccess == address(0)) revert FGOErrors.InvalidAmount();
        futuresAccess = FGOFuturesAccessControl(_futuresAccess);
    }

    function set_protocolFeeBPS(uint256 protocolFeeBPS) external onlyAdmin {
        if (protocolFeeBPS > 1000) revert FGOErrors.InvalidAmount();
        _protocolFeeBPS = protocolFeeBPS;
    }

    function set_lpFeeBPS(uint256 lpFeeBPS) external onlyAdmin {
        if (lpFeeBPS > 1000) revert FGOErrors.InvalidAmount();
        _lpFeeBPS = lpFeeBPS;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        _handleTransfer(from, to, id, amount);
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function getSettlementRewardPool(
        uint256 tokenId
    ) external view returns (uint256) {
        return _settlementRewardPool[tokenId];
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        for (uint256 i = 0; i < ids.length; i++) {
            _handleTransfer(from, to, ids[i], amounts[i]);
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _handleTransfer(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) internal {
        if (from == address(0) || to == address(0) || amount == 0) {
            return;
        }

        (address childContract, uint256 childId) = _decodeTokenId(id);

        uint256 reserved = _reservedTokenAmounts[childContract][childId][from];
        uint256 balance = balanceOf(from, id);
        if (amount > balance - reserved) {
            revert FGOErrors.InsufficientSupply();
        }

        uint256 pendingFrom = _pendingPurchases[childContract][childId][from];
        if (pendingFrom < amount) {
            revert FGOErrors.InsufficientSupply();
        }
        _pendingPurchases[childContract][childId][from] = pendingFrom - amount;
        _pendingPurchases[childContract][childId][to] += amount;
    }

    function _computeTokenId(
        address childContract,
        uint256 childId
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(childContract, childId)));
    }

    function _getOrCreateTokenId(
        address childContract,
        uint256 childId
    ) internal returns (uint256) {
        uint256 tokenId = _futureTokenIds[childContract][childId];
        if (tokenId == 0) {
            tokenId = _computeTokenId(childContract, childId);
            _futureTokenIds[childContract][childId] = tokenId;
            _tokenInfo[tokenId] = FGOMarketLibrary.TokenMetadata({
                childContract: childContract,
                childId: childId
            });
        } else if (_tokenInfo[tokenId].childContract == address(0)) {
            _tokenInfo[tokenId] = FGOMarketLibrary.TokenMetadata({
                childContract: childContract,
                childId: childId
            });
        }
        return tokenId;
    }

    function getFutureTokenId(
        address childContract,
        uint256 childId
    ) external view returns (uint256) {
        return _futureTokenIds[childContract][childId];
    }

    function _decodeTokenId(
        uint256 tokenId
    ) internal view returns (address childContract, uint256 childId) {
        FGOMarketLibrary.TokenMetadata memory meta = _tokenInfo[tokenId];
        if (meta.childContract == address(0)) {
            revert FGOErrors.InvalidAmount();
        }
        return (meta.childContract, meta.childId);
    }

    function getTokenVariables(
        uint256 tokenId
    ) public view returns (FGOMarketLibrary.TokenMetadata memory) {
        return _tokenInfo[tokenId];
    }
}
