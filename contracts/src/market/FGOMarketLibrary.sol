// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "../fgo/FGOLibrary.sol";

contract FGOMarketLibrary {
    enum PaymentType {
        CHILD_PAYMENT,
        PARENT_PAYMENT,
        TEMPLATE_PAYMENT,
        FULFILLER_PAYMENT
    }

    enum OrderStatus {
        PAID,
        CANCELLED,
        REFUNDED,
        DISPUTED
    }

    struct FuturesPosition {
        address supplier;
        address childContract;
        uint256 totalAmount;
        uint256 soldAmount;
        uint256 pricePerUnit;
        uint256 deadline;
        uint256 childId;
        uint256 settlementRewardBPS;
        bool isSettled;
        bool isActive;
        bool isClosed;
    }

    struct FuturesSellOrder {
        address seller;
        uint256 amount;
        uint256 tokenId;
        uint256 pricePerUnit;
        uint256 orderId;
        bool isActive;
    }

    struct PurchaseParams {
        uint256 parentId;
        uint256 parentAmount;
        uint256 childId;
        uint256 childAmount;
        uint256 templateId;
        uint256 templateAmount;
        address parentContract;
        address childContract;
        address templateContract;
        bool isPhysical;
        string fulfillmentData;
    }

    struct PaymentItem {
        uint256 amount;
        address recipient;
        PaymentType paymentType;
    }

    struct PaymentBreakdown {
        uint256 totalPayments;
        PaymentItem[] payments;
    }

    struct OrderReceipt {
        uint256 timestamp;
        uint256 orderId;
        PurchaseParams params;
        PaymentBreakdown breakdown;
        address buyer;
        OrderStatus status;
    }

    struct FulfillmentStatus {
        uint256 orderId;
        uint256 parentId;
        uint256 currentStep;
        uint256 createdAt;
        uint256 lastUpdated;
        address parentContract;
        StepCompletion[] steps;
    }

    struct StepCompletion {
        uint256 completedAt;
        uint256 fulfillerId;
        bool isCompleted;
        string notes;
    }

    struct SupplyRequestPosition {
        uint256 parentId;
        uint256 matchedChildId;
        uint256 designerId;
        FGOLibrary.ChildSupplyRequest request;
        address parentContract;
        address matchedSupplier;
        address matchedChildContract;
        bool paid;
    }

    struct SupplierProposal {
        uint256 childId;
        uint256 timestamp;
        address childContract;
        address supplier;
    }
}
