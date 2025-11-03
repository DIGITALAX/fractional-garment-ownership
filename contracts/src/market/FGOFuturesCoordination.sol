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
    uint256 private _orderCount;

    mapping(uint256 => mapping(address => uint256))
        private _futuresCredits;
    mapping(uint256 => FGOMarketLibrary.FuturesPosition)
        private _futuresPositions;
    mapping(uint256 => uint256) private _settlementRewardPool;
    mapping(uint256 => FGOMarketLibrary.FuturesSellOrder) private _sellOrders;
    mapping(uint256 => mapping(address => uint256)) private _pendingPurchases;
    mapping(uint256 => mapping(address => uint256))  private _reservedTokenAmounts;
    

    event FuturesPositionCreated(
        address indexed childContract,
        uint256 indexed childId,
        address indexed supplier,
        uint256 totalAmount,
        uint256 pricePerUnit,
        uint256 tokenId
    );

    event FuturesPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 amount,
        uint256 totalCost
    );

    event FuturesSettled(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 credits
    );

    event SettlementInitiated(
        uint256 indexed tokenId,
        address indexed settler,
        uint256 rewardAmount
    );

    event FuturesCreditsConsumed(
        address indexed childContract,
        uint256 indexed childId,
        address indexed consumer,
        uint256 amount,
        uint256 tokenId
    );

    event FuturesPositionClosed(
        uint256 indexed tokenId,
        address indexed supplier
    );

    event FuturesSellOrderCreated(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 orderId,
        uint256 amount,
        uint256 pricePerUnit
    );

    event FuturesSellOrderFilled(
        uint256 indexed tokenId,
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
        uint256 indexed tokenId,
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

        uint256 tokenId = _calculateTokenId(childId, msg.sender);
        if (_futuresPositions[tokenId].isActive) {
            revert FGOErrors.InvalidStatus();
        }

        _mint(supplier, tokenId, amount, "");

        _futuresPositions[tokenId] = FGOMarketLibrary.FuturesPosition({
            supplier: supplier,
            totalAmount: amount,
            soldAmount: 0,
            pricePerUnit: pricePerUnit,
            childId: childId,
            childContract: msg.sender,
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
            tokenId
        );
    }

    function buyFutures(uint256 tokenId, uint256 amount) external payable {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            tokenId
        ];

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

        FGOAccessControl childAccessControl = IFGOChild(position.childContract)
            .accessControl();
        address paymentToken = childAccessControl.PAYMENT_TOKEN();

        uint256 basePrice = amount * position.pricePerUnit;
        uint256 settlementFee = 0;
        uint256 protocolFee = 0;
        uint256 lpFee = 0;
        uint256 sellerProceeds = 0;

        if (position.deadline > 0) {
            settlementFee =
                (basePrice * position.settlementRewardBPS) /
                BASIS_POINTS;
            protocolFee =
                ((basePrice - settlementFee) * _protocolFeeBPS) /
                BASIS_POINTS;
            lpFee = ((basePrice - settlementFee) * _lpFeeBPS) / BASIS_POINTS;
            sellerProceeds = basePrice - settlementFee - protocolFee - lpFee;
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

        _safeTransferFrom(position.supplier, msg.sender, tokenId, amount, "");

        if (position.deadline > 0) {
            _settlementRewardPool[tokenId] += settlementFee;
        }

        position.soldAmount += amount;

        _pendingPurchases[tokenId][msg.sender] += amount;

        emit FuturesPurchased(tokenId, msg.sender, amount, basePrice);
        emit FeesCollectedFuture(tokenId, settlementFee, protocolFee, lpFee);
    }

    function settleFutures(uint256 tokenId, uint256 amount) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            tokenId
        ];

        if (position.deadline == 0) {
            if (amount == 0) {
                revert FGOErrors.ZeroValue();
            }

            uint256 balance = balanceOf(msg.sender, tokenId);
            uint256 reserved = _reservedTokenAmounts[tokenId][msg.sender];
            uint256 availableToSettle = balance - reserved;

            if (amount > availableToSettle) {
                revert FGOErrors.InsufficientSupply();
            }

            _futuresCredits[tokenId][msg.sender] += amount;
            _pendingPurchases[tokenId][msg.sender] -= amount;
            _burn(msg.sender, tokenId, amount);

            emit FuturesSettled(tokenId, msg.sender, amount);
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

            FGOAccessControl childAccessControl = IFGOChild(position.childContract)
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

            emit SettlementInitiated(tokenId, msg.sender, rewardAmount);
        }
    }

    function claimFuturesCredits(uint256 tokenId) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            tokenId
        ];

        if (!position.isSettled) {
            revert FGOErrors.InvalidStatus();
        }

        uint256 balance = balanceOf(msg.sender, tokenId);
        if (balance == 0) {
            revert FGOErrors.ZeroValue();
        }

        _futuresCredits[tokenId][msg.sender] += balance;
        _burn(msg.sender, tokenId, balance);

        emit FuturesSettled(tokenId, msg.sender, balance);
    }

    function getFuturesCredits(
        address childContract,
        address designer,
        uint256 childId
    ) external view returns (uint256) {
        uint256 tokenId = _calculateTokenId(childId, childContract);
        return _futuresCredits[tokenId][designer];
    }

    function _calculateTokenId(
        uint256 childId,
        address childContract
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(childContract, childId)));
    }

    function calculateTokenId(
        uint256 childId,
        address childContract
    ) external pure returns (uint256) {
        return _calculateTokenId(childId, childContract);
    }

    function consumeFuturesCredits(
        address childContract,
        address consumer,
        uint256 childId,
        uint256 amount
    ) external onlyApprovedContract {
        uint256 tokenId = _calculateTokenId(childId, childContract);
        if (_futuresCredits[tokenId][consumer] < amount) {
            revert FGOErrors.InsufficientSupply();
        }
        _futuresCredits[tokenId][consumer] -= amount;
        emit FuturesCreditsConsumed(
            childContract,
            childId,
            consumer,
            amount,
            tokenId
        );
    }

    function getFuturesPosition(
        uint256 tokenId
    ) external view returns (FGOMarketLibrary.FuturesPosition memory) {
        return _futuresPositions[tokenId];
    }

    function getReservedTokenAmounts(
        uint256 tokenId,
        address holder
    ) external view returns (uint256) {
        return _reservedTokenAmounts[tokenId][holder];
    }

    function closeFuturesPosition(uint256 tokenId) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            tokenId
        ];

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

        uint256 tokenBalance = balanceOf(msg.sender, tokenId);
        if (tokenBalance < 1) revert FGOFuturesErrors.TokensAlreadyTraded();

        _burn(msg.sender, tokenId, tokenBalance);
        position.isClosed = true;
        emit FuturesPositionClosed(tokenId, msg.sender);
    }

    function createSellOrder(
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerUnit
    ) external {
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[
            tokenId
        ];

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

        uint256 reservedAmount = _reservedTokenAmounts[tokenId][msg.sender];
        uint256 ownedBalance = balanceOf(msg.sender, tokenId);

        if (ownedBalance < reservedAmount + amount) {
            revert FGOErrors.InsufficientSupply();
        }

        _orderCount++;
        _sellOrders[_orderCount] = FGOMarketLibrary.FuturesSellOrder({
            seller: msg.sender,
            amount: amount,
            tokenId: tokenId,
            pricePerUnit: pricePerUnit,
            orderId: _orderCount,
            isActive: true
        });

        _reservedTokenAmounts[tokenId][msg.sender] = reservedAmount + amount;

        emit FuturesSellOrderCreated(
            tokenId,
            msg.sender,
            _orderCount,
            amount,
            pricePerUnit
        );
    }

    function buySellOrder(uint256 orderId, uint256 amount) external payable {
                FGOMarketLibrary.FuturesSellOrder storage order = _sellOrders[orderId];
        FGOMarketLibrary.FuturesPosition storage position = _futuresPositions[order.tokenId];

        if (!position.isActive && position.deadline > 0) {
            revert FGOErrors.InvalidStatus();
        }

        if (position.deadline > 0 && block.timestamp >= position.deadline) {
            revert FGOErrors.InvalidStatus();
        }

        if (amount == 0) {
            revert FGOErrors.ZeroValue();
        }

        if (amount > order.amount) {
            revert FGOErrors.InsufficientSupply();
        }

        uint256 totalCost = amount * order.pricePerUnit;

        FGOAccessControl childAccessControl = IFGOChild(position.childContract)
            .accessControl();
        address paymentToken = childAccessControl.PAYMENT_TOKEN();
        uint256 protocolFee = (totalCost * _protocolFeeBPS) / BASIS_POINTS;
        uint256 lpFee = (totalCost * _lpFeeBPS) / BASIS_POINTS;
        uint256 sellerProceeds = totalCost - protocolFee - lpFee;

        if (balanceOf(order.seller, order.tokenId) < amount) {
            revert FGOErrors.InsufficientSupply();
        }

        if (paymentToken == address(0)) {
            if (msg.value != totalCost) {
                revert FGOErrors.InsufficientPayment();
            }

            (bool sellerSuccess, ) = payable(order.seller).call{
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
                order.seller,
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

        uint256 sellerPurchase = _pendingPurchases[order.tokenId][order.seller];
        uint256 buyerPurchase = _pendingPurchases[order.tokenId][msg.sender];

        sellerPurchase -= amount;
        buyerPurchase += amount;
        _pendingPurchases[order.tokenId][order.seller] = sellerPurchase;
        _pendingPurchases[order.tokenId][msg.sender] = buyerPurchase;

        if (amount < order.amount) {
            order.amount -= amount;
        } else {
            order.isActive = false;
        }

        uint256 reserved = _reservedTokenAmounts[order.tokenId][order.seller];
        if (reserved >= amount) {
            _reservedTokenAmounts[order.tokenId][order.seller] = reserved - amount;
        } else {
            _reservedTokenAmounts[order.tokenId][order.seller] = 0;
        }

        _safeTransferFrom(order.seller, msg.sender, order.tokenId, amount, "");

        emit FuturesSellOrderFilled(
            order.tokenId,
            order.seller,
            msg.sender,
            orderId,
            amount,
            totalCost
        );
        emit FeesCollected(orderId, protocolFee, lpFee);
    }

    function cancelSellOrder(uint256 tokenId, uint256 orderId) external {
        FGOMarketLibrary.FuturesSellOrder storage order = _sellOrders[orderId];

        order.isActive = false;

        uint256 reserved = _reservedTokenAmounts[tokenId][msg.sender];
        uint256 release = order.amount;
        if (reserved >= release) {
            _reservedTokenAmounts[tokenId][msg.sender] = reserved - release;
        } else {
            _reservedTokenAmounts[tokenId][msg.sender] = 0;
        }

        emit FuturesSellOrderCancelled(tokenId, msg.sender, orderId);
    }

    function getLpFee() public view returns (uint256) {
        return _lpFeeBPS;
    }

    function getOrderCount() public view returns (uint256) {
        return _orderCount;
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

    function setProtocolFeeBPS(uint256 protocolFeeBPS) external onlyAdmin {
        if (protocolFeeBPS > 1000) revert FGOErrors.InvalidAmount();
        _protocolFeeBPS = protocolFeeBPS;
    }

    function setLPFeeBPS(uint256 lpFeeBPS) external onlyAdmin {
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
        uint256 tokenId,
        uint256 amount
    ) internal {
        if (from == address(0) || to == address(0) || amount == 0) {
            return;
        }

        uint256 reserved = _reservedTokenAmounts[tokenId][from];
        uint256 balance = balanceOf(from, tokenId);
        if (amount > balance - reserved) {
            revert FGOErrors.InsufficientSupply();
        }

        uint256 pendingFrom = _pendingPurchases[tokenId][from];
        if (pendingFrom < amount) {
            revert FGOErrors.InsufficientSupply();
        }
        _pendingPurchases[tokenId][from] = pendingFrom - amount;
        _pendingPurchases[tokenId][to] += amount;
    }
}
