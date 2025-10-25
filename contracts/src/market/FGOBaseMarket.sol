// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../fgo/FGOAccessControl.sol";
import "./FGOMarketLibrary.sol";
import "../interfaces/IFGOContracts.sol";
import "./FGOMarketErrors.sol";
import "./FGOFulfillment.sol";
import "../fgo/FGOFulfillers.sol";

abstract contract FGOBaseMarket is ReentrancyGuard {
    bytes32 public infraId;
    uint256 private _orderCounter;
    address public factory;
    FGOAccessControl public accessControl;
    FGOFulfillment public fulfillment;
    FGOFulfillers public fulfillers;
    address public futuresCoordination;
    bool public isPaused;
    string public symbol;
    string public name;
    string public marketURI;

    mapping(uint256 => FGOMarketLibrary.OrderReceipt) private _orders;
    mapping(address => uint256[]) private _buyerOrders;

    event OrderExecuted(
        uint256 indexed totalPayments,
        address indexed buyer,
        uint256[] orderIds
    );

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOMarketErrors.Unauthorized();
        }
        _;
    }

    modifier whenNotPaused() {
        if (isPaused) {
            revert FGOMarketErrors.Unauthorized();
        }
        _;
    }

    constructor(
        bytes32 _infraId,
        address _accessControl,
        address _fulfillers,
        string memory _symbol,
        string memory _name,
        string memory _marketURI
    ) {
        infraId = _infraId;
        symbol = _symbol;
        name = _name;
        marketURI = _marketURI;
        accessControl = FGOAccessControl(_accessControl);
        fulfillers = FGOFulfillers(_fulfillers);
        factory = msg.sender;
        isPaused = false;
    }

    function pauseMarket() external onlyAdmin {
        isPaused = true;
    }

    function unpauseMarket() external onlyAdmin {
        isPaused = false;
    }

    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }

    function setFuturesCoordination(address _futuresCoordination) external onlyAdmin {
        futuresCoordination = _futuresCoordination;
    }

    function buy(
        FGOMarketLibrary.PurchaseParams[] memory params
    ) external nonReentrant whenNotPaused {
        _validatePurchase(params);

        FGOMarketLibrary.PaymentBreakdown memory breakdown = _calculatePayments(
            params
        );

        _executePayments(breakdown);

        uint256[] memory orderIds = new uint256[](params.length);
        for (uint256 i = 0; i < params.length; ) {
            orderIds[i] = _orderCounter + 1 + i;
            unchecked {
                ++i;
            }
        }

        _mintTokens(params, orderIds);

        for (uint256 i = 0; i < params.length; ) {
            _orderCounter++;

            _orders[_orderCounter] = FGOMarketLibrary.OrderReceipt({
                orderId: _orderCounter,
                buyer: msg.sender,
                params: params[i],
                breakdown: breakdown,
                timestamp: block.timestamp,
                status: FGOMarketLibrary.OrderStatus.PAID
            });

            _buyerOrders[msg.sender].push(_orderCounter);

            if (address(fulfillment) != address(0) && params[i].parentId != 0) {
                FGOLibrary.ParentMetadata memory parent = IFGOParent(
                    params[i].parentContract
                ).getDesignTemplate(params[i].parentId);

                FGOLibrary.FulfillmentStep[] memory steps = params[i].isPhysical
                    ? parent.workflow.physicalSteps
                    : parent.workflow.digitalSteps;

                if (steps.length > 0) {
                    fulfillment.startFulfillment(
                        _orderCounter,
                        params[i].parentId,
                        params[i].parentContract,
                        params[i].isPhysical
                    );
                }
            }

            unchecked {
                ++i;
            }
        }

        emit OrderExecuted(breakdown.totalPayments, msg.sender, orderIds);
    }

    function _validatePurchase(
        FGOMarketLibrary.PurchaseParams[] memory params
    ) internal view {
        for (uint256 j = 0; j < params.length; ) {
            FGOMarketLibrary.PurchaseParams memory param = params[j];

            uint256 typeCount = 0;
            if (param.childId != 0) typeCount++;
            if (param.parentId != 0) typeCount++;
            if (param.templateId != 0) typeCount++;

            if (typeCount != 1) {
                revert FGOMarketErrors.InvalidPurchaseParams();
            }

            if (param.parentId != 0) {
                if (param.parentAmount == 0) {
                    revert FGOMarketErrors.InvalidPurchaseParams();
                }
                if (
                    !IFGOParent(param.parentContract).canPurchase(
                        param.parentId,
                        param.parentAmount,
                        param.isPhysical,
                        address(this)
                    )
                ) {
                    revert FGOMarketErrors.Unauthorized();
                }
            } else if (param.templateId != 0) {
                if (param.templateAmount == 0) {
                    revert FGOMarketErrors.InvalidPurchaseParams();
                }
                if (
                    !IFGOTemplate(param.templateContract).canPurchase(
                        param.templateId,
                        param.templateAmount,
                        param.isPhysical,
                        address(this)
                    )
                ) {
                    revert FGOMarketErrors.Unauthorized();
                }
            } else if (param.childId != 0) {
                if (param.childAmount == 0) {
                    revert FGOMarketErrors.InvalidPurchaseParams();
                }

                bool skipValidation = false;
                bool isStandalone = IFGOChild(param.childContract).getStandaloneAllowed(param.childId);

                if (isStandalone && futuresCoordination != address(0)) {
                    FGOLibrary.ChildMetadata memory child = IFGOChild(param.childContract).getChildMetadata(param.childId);

                    if (child.futures.isFutures) {
                        uint256 buyerCredits = IFGOFuturesCoordination(futuresCoordination).getFuturesCredits(
                            param.childContract,
                            param.childId,
                            msg.sender,
                            param.isPhysical
                        );

                        if (buyerCredits >= param.childAmount) {
                            skipValidation = true;
                        }
                    }
                }

                if (!skipValidation) {
                    if (
                        !IFGOChild(param.childContract).canPurchase(
                            param.childId,
                            param.childAmount,
                            param.isPhysical,
                            address(this)
                        )
                    ) {
                        revert FGOMarketErrors.Unauthorized();
                    }
                }
            }
            unchecked {
                ++j;
            }
        }
    }

    function _addToPayments(
        FGOMarketLibrary.PaymentItem[] memory payments,
        uint256 index,
        uint256 amount,
        address recipient,
        FGOMarketLibrary.PaymentType paymentType
    ) internal pure returns (uint256) {
        payments[index] = FGOMarketLibrary.PaymentItem({
            amount: amount,
            recipient: recipient,
            paymentType: paymentType
        });
        return index + 1;
    }

    function _calculatePayments(
        FGOMarketLibrary.PurchaseParams[] memory params
    ) internal view returns (FGOMarketLibrary.PaymentBreakdown memory) {
        FGOMarketLibrary.PaymentItem[]
            memory tempPayments = new FGOMarketLibrary.PaymentItem[](500);
        uint256 paymentCount = 0;
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < params.length; ) {
            if (params[i].parentId != 0) {
                FGOLibrary.ParentMetadata memory parent = IFGOParent(
                    params[i].parentContract
                ).getDesignTemplate(params[i].parentId);

                uint256 price = params[i].isPhysical
                    ? parent.physicalPrice
                    : parent.digitalPrice;
                uint256 totalParentPrice = price * params[i].parentAmount;
                totalAmount += totalParentPrice;

                paymentCount = _addParentPaymentsToBuffer(
                    parent,
                    totalParentPrice,
                    params[i].isPhysical,
                    tempPayments,
                    paymentCount
                );

                (paymentCount, totalAmount) = _addNestedPaymentsToBuffer(
                    parent.childReferences,
                    tempPayments,
                    params[i].parentAmount,
                    paymentCount,
                    totalAmount,
                    params[i].parentId,
                    params[i].parentContract,
                    parent.designer,
                    params[i].isPhysical
                );
            } else if (params[i].templateId != 0) {
                FGOLibrary.ChildMetadata memory template = IFGOChild(
                    params[i].templateContract
                ).getChildMetadata(params[i].templateId);
                FGOLibrary.ChildReference[]
                    memory templateReferences = IFGOTemplate(
                        params[i].templateContract
                    ).getTemplatePlacements(params[i].templateId);

                uint256 price = params[i].isPhysical
                    ? template.physicalPrice
                    : template.digitalPrice;
                uint256 templateAmount = price * params[i].templateAmount;
                totalAmount += templateAmount;

                paymentCount = _addToPayments(
                    tempPayments,
                    paymentCount,
                    templateAmount,
                    template.supplier,
                    FGOMarketLibrary.PaymentType.TEMPLATE_PAYMENT
                );

                (paymentCount, totalAmount) = _addNestedPaymentsToBuffer(
                    templateReferences,
                    tempPayments,
                    params[i].templateAmount,
                    paymentCount,
                    totalAmount,
                    0,
                    address(0),
                    address(0),
                    params[i].isPhysical
                );
            } else if (params[i].childId != 0) {
                FGOLibrary.ChildMetadata memory child = IFGOChild(
                    params[i].childContract
                ).getChildMetadata(params[i].childId);

                bool skipPayment = false;
                bool isStandalone = IFGOChild(params[i].childContract).getStandaloneAllowed(params[i].childId);

                if (isStandalone && child.futures.isFutures) {
                    if (futuresCoordination == address(0)) {
                        revert FGOMarketErrors.Unauthorized();
                    }

                    uint256 buyerCredits = IFGOFuturesCoordination(futuresCoordination).getFuturesCredits(
                        params[i].childContract,
                        params[i].childId,
                        msg.sender,
                        params[i].isPhysical
                    );

                    if (buyerCredits >= params[i].childAmount) {
                        skipPayment = true;
                    } else {
                        revert FGOMarketErrors.Unauthorized();
                    }
                }

                if (!skipPayment) {
                    uint256 price = params[i].isPhysical
                        ? child.physicalPrice
                        : child.digitalPrice;
                    uint256 childAmount = price * params[i].childAmount;
                    totalAmount += childAmount;

                    paymentCount = _addToPayments(
                        tempPayments,
                        paymentCount,
                        childAmount,
                        child.supplier,
                        FGOMarketLibrary.PaymentType.CHILD_PAYMENT
                    );
                }
            }
            unchecked {
                ++i;
            }
        }

        FGOMarketLibrary.PaymentItem[]
            memory finalPayments = new FGOMarketLibrary.PaymentItem[](
                paymentCount
            );
        for (uint256 i = 0; i < paymentCount; ) {
            finalPayments[i] = tempPayments[i];
            unchecked {
                ++i;
            }
        }

        return
            FGOMarketLibrary.PaymentBreakdown({
                totalPayments: totalAmount,
                payments: finalPayments
            });
    }

    function _addParentPaymentsToBuffer(
        FGOLibrary.ParentMetadata memory parent,
        uint256 totalParentPrice,
        bool isPhysical,
        FGOMarketLibrary.PaymentItem[] memory tempPayments,
        uint256 paymentCount
    ) internal view returns (uint256) {
        FGOMarketLibrary.PaymentItem[]
            memory parentPayments = _calculateParentPayments(
                parent,
                totalParentPrice,
                isPhysical
            );

        for (uint256 i = 0; i < parentPayments.length; ) {
            tempPayments[paymentCount] = parentPayments[i];
            paymentCount++;
            unchecked {
                ++i;
            }
        }

        return paymentCount;
    }

    function _addNestedPaymentsToBuffer(
        FGOLibrary.ChildReference[] memory childReferences,
        FGOMarketLibrary.PaymentItem[] memory tempPayments,
        uint256 amount,
        uint256 paymentCount,
        uint256 totalAmount,
        uint256 parentId,
        address parentContract,
        address designer,
        bool isPhysical
    ) internal view returns (uint256, uint256) {
        FGOMarketLibrary.PaymentItem[]
            memory nestedPayments = _calculateNestedPayments(
                childReferences,
                amount,
                parentId,
                parentContract,
                designer,
                isPhysical
            );

        for (uint256 i = 0; i < nestedPayments.length; ) {
            tempPayments[paymentCount] = nestedPayments[i];
            totalAmount += nestedPayments[i].amount;
            paymentCount++;
            unchecked {
                ++i;
            }
        }

        return (paymentCount, totalAmount);
    }

    function _executePayments(
        FGOMarketLibrary.PaymentBreakdown memory breakdown
    ) internal {
        for (uint256 i = 0; i < breakdown.payments.length; ) {
            FGOMarketLibrary.PaymentItem memory payment = breakdown.payments[i];

            if (payment.amount > 0) {
                if (payment.recipient == address(0)) {
                    revert FGOMarketErrors.InvalidPurchaseParams();
                }

                address paymentToken = accessControl.PAYMENT_TOKEN();
                IERC20(paymentToken).transferFrom(
                    msg.sender,
                    payment.recipient,
                    payment.amount
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    function _mintTokens(
        FGOMarketLibrary.PurchaseParams[] memory params,
        uint256[] memory orderIds
    ) internal {
        for (uint256 i = 0; i < params.length; ) {
            FGOMarketLibrary.PurchaseParams memory param = params[i];

            if (param.parentId != 0) {
                IFGOParent(param.parentContract).mint(
                    param.parentId,
                    param.parentAmount,
                    msg.sender,
                    param.isPhysical
                );

                FGOLibrary.ParentMetadata memory parent = IFGOParent(
                    param.parentContract
                ).getDesignTemplate(param.parentId);

                bool reserveRights = param.isPhysical &&
                    parent.workflow.physicalSteps.length > 0;

                _mintNestedChildren(
                    parent.childReferences,
                    param.parentAmount,
                    orderIds[i],
                    parent.workflow.estimatedDeliveryDuration,
                    param.isPhysical,
                    msg.sender,
                    reserveRights,
                    param.parentId,
                    param.parentContract
                );
            } else if (param.templateId != 0) {
                try
                    IFGOChild(param.templateContract).mint(
                        param.templateId,
                        param.templateAmount,
                        orderIds[i],
                        0,
                        msg.sender,
                        param.isPhysical,
                        true,
                        false,
                        0
                    )
                {} catch {
                    revert FGOMarketErrors.MintFailed();
                }

                FGOLibrary.ChildReference[]
                    memory templateReferences = IFGOTemplate(
                        param.templateContract
                    ).getTemplatePlacements(param.templateId);

                _mintNestedChildren(
                    templateReferences,
                    param.templateAmount,
                    orderIds[i],
                    0,
                    param.isPhysical,
                    msg.sender,
                    false,
                    0,
                    address(0)
                );
            } else if (param.childId != 0) {
                FGOLibrary.ChildMetadata memory child = IFGOChild(param.childContract).getChildMetadata(param.childId);
                bool isStandalone = IFGOChild(param.childContract).getStandaloneAllowed(param.childId);

                if (isStandalone && child.futures.isFutures && futuresCoordination != address(0)) {
                    IFGOFuturesCoordination(futuresCoordination).consumeFuturesCredits(
                        param.childContract,
                        param.childId,
                        msg.sender,
                        param.childAmount,
                        param.isPhysical
                    );
                }

                try
                    IFGOChild(param.childContract).mint(
                        param.childId,
                        param.childAmount,
                        orderIds[i],
                        0,
                        msg.sender,
                        param.isPhysical,
                        true,
                        false,
                        0
                    )
                {} catch {
                    revert FGOMarketErrors.MintFailed();
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function getOrderReceipt(
        uint256 orderId
    ) external view returns (FGOMarketLibrary.OrderReceipt memory) {
        return _orders[orderId];
    }

    function getBuyerOrders(
        address buyer
    ) external view returns (uint256[] memory) {
        return _buyerOrders[buyer];
    }

    function getOrderCounter() external view returns (uint256) {
        return _orderCounter;
    }

    function getFulfillmentContract() external view returns (address) {
        return address(fulfillment);
    }

    function setFulfillment(address _fulfillment) external {
        if (msg.sender != factory) {
            revert FGOMarketErrors.Unauthorized();
        }

        fulfillment = FGOFulfillment(_fulfillment);
    }

    function updateMarketOrderStatus(
        uint256 orderId,
        FGOMarketLibrary.OrderStatus status
    ) external {
        if (msg.sender != address(fulfillment)) {
            revert FGOMarketErrors.Unauthorized();
        }

        if (_orders[orderId].orderId == 0) {
            revert FGOMarketErrors.OrderNotFound();
        }

        _orders[orderId].status = status;
    }

    function _calculateParentPayments(
        FGOLibrary.ParentMetadata memory parent,
        uint256 totalParentPrice,
        bool isPhysical
    ) internal view returns (FGOMarketLibrary.PaymentItem[] memory) {
        FGOLibrary.FulfillmentStep[] memory steps = isPhysical
            ? parent.workflow.physicalSteps
            : parent.workflow.digitalSteps;

        if (steps.length == 0) {
            FGOMarketLibrary.PaymentItem[]
                memory designerPayment = new FGOMarketLibrary.PaymentItem[](1);
            designerPayment[0] = FGOMarketLibrary.PaymentItem({
                amount: totalParentPrice,
                recipient: parent.designer,
                paymentType: FGOMarketLibrary.PaymentType.PARENT_PAYMENT
            });
            return designerPayment;
        }

        uint256 totalItems = 1;
        for (uint256 i = 0; i < steps.length; ) {
            totalItems += steps[i].subPerformers.length + 1;
            unchecked {
                ++i;
            }
        }

        FGOMarketLibrary.PaymentItem[]
            memory payments = new FGOMarketLibrary.PaymentItem[](totalItems);
        uint256 paymentIndex = 0;
        uint256 totalFulfillerCost = 0;

        for (uint256 i = 0; i < steps.length; ) {
            FGOLibrary.FulfillerProfile memory primaryProfile = FGOFulfillers(
                fulfillers
            ).getFulfillerProfile(
                    FGOFulfillers(fulfillers).getFulfillerIdByAddress(
                        steps[i].primaryPerformer
                    )
                );

            uint256 primaryAmount = primaryProfile.basePrice +
                ((totalParentPrice * primaryProfile.vigBasisPoints) / 10000);
            uint256 remainder = primaryAmount;

            for (uint256 j = 0; j < steps[i].subPerformers.length; ) {
                uint256 subAmount = (primaryAmount *
                    steps[i].subPerformers[j].splitBasisPoints) / 10000;

                payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                    amount: subAmount,
                    recipient: steps[i].subPerformers[j].performer,
                    paymentType: FGOMarketLibrary.PaymentType.FULFILLER_PAYMENT
                });

                remainder -= subAmount;
                paymentIndex++;
                unchecked {
                    ++j;
                }
            }

            payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                amount: remainder,
                recipient: steps[i].primaryPerformer,
                paymentType: FGOMarketLibrary.PaymentType.FULFILLER_PAYMENT
            });

            totalFulfillerCost += primaryAmount;
            paymentIndex++;
            unchecked {
                ++i;
            }
        }

        uint256 designerAmount = totalParentPrice - totalFulfillerCost;
        payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
            amount: designerAmount,
            recipient: parent.designer,
            paymentType: FGOMarketLibrary.PaymentType.PARENT_PAYMENT
        });

        return payments;
    }

    function _calculateChildPrice(
        uint256 childId,
        address childContract,
        uint256 amount,
        bool isPhysical
    ) internal view returns (uint256) {
        try IFGOChild(childContract).getChildMetadata(childId) returns (
            FGOLibrary.ChildMetadata memory child
        ) {
            if (
                isPhysical &&
                child.availability == FGOLibrary.Availability.DIGITAL_ONLY
            ) {
                return 0;
            }
            if (
                !isPhysical &&
                child.availability == FGOLibrary.Availability.PHYSICAL_ONLY
            ) {
                return 0;
            }

            uint256 price = isPhysical
                ? child.physicalPrice
                : child.digitalPrice;
            return price * amount;
        } catch {
            return 0;
        }
    }

    function _calculateTemplatePrice(
        uint256 templateId,
        address templateContract,
        uint256 amount,
        bool isPhysical
    ) internal view returns (uint256) {
        try IFGOChild(templateContract).getChildMetadata(templateId) returns (
            FGOLibrary.ChildMetadata memory template
        ) {
            if (
                isPhysical &&
                template.availability == FGOLibrary.Availability.DIGITAL_ONLY
            ) {
                return 0;
            }
            if (
                !isPhysical &&
                template.availability == FGOLibrary.Availability.PHYSICAL_ONLY
            ) {
                return 0;
            }

            uint256 templatePrice = isPhysical
                ? template.physicalPrice
                : template.digitalPrice;
            uint256 total = templatePrice * amount;

            try
                IFGOTemplate(templateContract).getTemplatePlacements(templateId)
            returns (FGOLibrary.ChildReference[] memory placements) {
                for (uint256 i = 0; i < placements.length; ) {
                    FGOLibrary.ChildReference memory placement = placements[i];

                    uint256 childPrice = _calculateTemplatePrice(
                        placement.childId,
                        placement.childContract,
                        placement.amount * amount,
                        isPhysical
                    );

                    if (childPrice == 0) {
                        childPrice = _calculateChildPrice(
                            placement.childId,
                            placement.childContract,
                            placement.amount * amount,
                            isPhysical
                        );
                    }

                    total += childPrice;
                    unchecked {
                        ++i;
                    }
                }
            } catch {
                revert FGOErrors.CatchBlock();
            }

            return total;
        } catch {
            return 0;
        }
    }

    function _calculateNestedPayments(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 amount,
        uint256 parentId,
        address parentContract,
        address designer,
        bool isPhysical
    ) internal view returns (FGOMarketLibrary.PaymentItem[] memory) {
        uint256 totalItems = _countNestedPaymentItems(childReferences);

        FGOMarketLibrary.PaymentItem[]
            memory payments = new FGOMarketLibrary.PaymentItem[](totalItems * 2);
        uint256 paymentIndex = 0;

        paymentIndex = _processNestedReferences(
            childReferences,
            payments,
            amount,
            paymentIndex,
            parentId,
            parentContract,
            designer,
            isPhysical
        );

        FGOMarketLibrary.PaymentItem[]
            memory finalPayments = new FGOMarketLibrary.PaymentItem[](paymentIndex);
        for (uint256 i = 0; i < paymentIndex; ) {
            finalPayments[i] = payments[i];
            unchecked {
                ++i;
            }
        }

        return finalPayments;
    }

    function _countNestedPaymentItems(
        FGOLibrary.ChildReference[] memory childReferences
    ) internal view returns (uint256) {
        uint256 totalItems = 0;

        for (uint256 i = 0; i < childReferences.length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];
            FGOLibrary.ChildMetadata memory child = IFGOChild(
                childRef.childContract
            ).getChildMetadata(childRef.childId);

            if (child.isTemplate) {
                totalItems += 1;

                FGOLibrary.ChildReference[]
                    memory templateReferences = IFGOTemplate(
                        childRef.childContract
                    ).getTemplatePlacements(childRef.childId);

                totalItems += _countNestedPaymentItems(templateReferences);
            } else {
                totalItems += 1;
            }

            unchecked {
                ++i;
            }
        }

        return totalItems;
    }

    function _processNestedReferences(
        FGOLibrary.ChildReference[] memory childReferences,
        FGOMarketLibrary.PaymentItem[] memory payments,
        uint256 amount,
        uint256 paymentIndex,
        uint256 parentId,
        address parentContract,
        address designer,
        bool isPhysical
    ) internal view returns (uint256) {
        for (uint256 i = 0; i < childReferences.length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];
            FGOLibrary.ChildMetadata memory child = IFGOChild(
                childRef.childContract
            ).getChildMetadata(childRef.childId);

            uint256 amountNeeded = childRef.amount * amount;
            uint256 prepaidAvailable = 0;

            if (parentContract != address(0) && parentId != 0) {
                prepaidAvailable = IFGOParent(parentContract).getPrepaidAvailable(
                    parentId,
                    childRef.childContract,
                    childRef.childId
                );
            }

            if (child.isTemplate) {
                if (!child.futures.isFutures) {
                    uint256 price = isPhysical
                        ? child.physicalPrice
                        : child.digitalPrice;

                    if (prepaidAvailable > 0) {
                        uint256 prepaidUsed = prepaidAvailable > amountNeeded ? amountNeeded : prepaidAvailable;
                        uint256 unpaidAmount = amountNeeded - prepaidUsed;

                        if (prepaidUsed > 0) {
                            payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                                amount: price * prepaidUsed,
                                recipient: designer,
                                paymentType: FGOMarketLibrary.PaymentType.TEMPLATE_PAYMENT
                            });
                            paymentIndex++;
                        }

                        if (unpaidAmount > 0) {
                            payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                                amount: price * unpaidAmount,
                                recipient: child.supplier,
                                paymentType: FGOMarketLibrary.PaymentType.TEMPLATE_PAYMENT
                            });
                            paymentIndex++;
                        }
                    } else {
                        payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                            amount: price * amountNeeded,
                            recipient: child.supplier,
                            paymentType: FGOMarketLibrary.PaymentType.TEMPLATE_PAYMENT
                        });
                        paymentIndex++;
                    }
                }

                FGOLibrary.ChildReference[]
                    memory templateReferences = IFGOTemplate(
                        childRef.childContract
                    ).getTemplatePlacements(childRef.childId);

                paymentIndex = _processNestedReferences(
                    templateReferences,
                    payments,
                    amountNeeded,
                    paymentIndex,
                    0,
                    address(0),
                    address(0),
                    isPhysical
                );
            } else {
                if (!child.futures.isFutures) {
                    uint256 price = isPhysical
                        ? child.physicalPrice
                        : child.digitalPrice;

                    if (prepaidAvailable > 0) {
                        uint256 prepaidUsed = prepaidAvailable > amountNeeded ? amountNeeded : prepaidAvailable;
                        uint256 unpaidAmount = amountNeeded - prepaidUsed;

                        if (prepaidUsed > 0) {
                            payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                                amount: price * prepaidUsed,
                                recipient: designer,
                                paymentType: FGOMarketLibrary.PaymentType.CHILD_PAYMENT
                            });
                            paymentIndex++;
                        }

                        if (unpaidAmount > 0) {
                            payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                                amount: price * unpaidAmount,
                                recipient: child.supplier,
                                paymentType: FGOMarketLibrary.PaymentType.CHILD_PAYMENT
                            });
                            paymentIndex++;
                        }
                    } else {
                        payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                            amount: price * amountNeeded,
                            recipient: child.supplier,
                            paymentType: FGOMarketLibrary.PaymentType.CHILD_PAYMENT
                        });
                        paymentIndex++;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }

        return paymentIndex;
    }

    function _mintNestedChildren(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 amount,
        uint256 orderId,
        uint256 estimatedDeliveryDuration,
        bool isPhysical,
        address to,
        bool reserveRights,
        uint256 parentId,
        address parentContract
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];
            FGOLibrary.ChildMetadata memory child = IFGOChild(
                childRef.childContract
            ).getChildMetadata(childRef.childId);

            uint256 mintAmount = childRef.amount * amount;
            uint256 prepaidAvailable = 0;

            if (parentContract != address(0) && parentId != 0) {
                prepaidAvailable = IFGOParent(parentContract).getPrepaidAvailable(
                    parentId,
                    childRef.childContract,
                    childRef.childId
                );
            }

            if (child.isTemplate) {
                try
                    IFGOChild(childRef.childContract).mint(
                        childRef.childId,
                        mintAmount,
                        orderId,
                        estimatedDeliveryDuration,
                        to,
                        isPhysical,
                        false,
                        reserveRights,
                        prepaidAvailable
                    )
                {} catch {
                    revert FGOErrors.CatchBlock();
                }

                if (parentContract != address(0) && parentId != 0 && prepaidAvailable > 0) {
                    uint256 prepaidUsed = prepaidAvailable > mintAmount ? mintAmount : prepaidAvailable;
                    IFGOParent(parentContract).updatePrepaidUsed(
                        parentId,
                        childRef.childContract,
                        childRef.childId,
                        prepaidUsed
                    );
                    IFGOChild(childRef.childContract).incrementTotalPrepaidUsed(
                        childRef.childId,
                        prepaidUsed
                    );
                }

                FGOLibrary.ChildReference[]
                    memory templateReferences = IFGOTemplate(
                        childRef.childContract
                    ).getTemplatePlacements(childRef.childId);

                _mintNestedChildren(
                    templateReferences,
                    mintAmount,
                    orderId,
                    estimatedDeliveryDuration,
                    isPhysical,
                    to,
                    reserveRights,
                    0,
                    address(0)
                );
            } else {
                try
                    IFGOChild(childRef.childContract).mint(
                        childRef.childId,
                        mintAmount,
                        orderId,
                        estimatedDeliveryDuration,
                        to,
                        isPhysical,
                        false,
                        reserveRights,
                        prepaidAvailable
                    )
                {} catch {
                    revert FGOErrors.CatchBlock();
                }

                if (parentContract != address(0) && parentId != 0 && prepaidAvailable > 0) {
                    uint256 prepaidUsed = prepaidAvailable > mintAmount ? mintAmount : prepaidAvailable;
                    IFGOParent(parentContract).updatePrepaidUsed(
                        parentId,
                        childRef.childContract,
                        childRef.childId,
                        prepaidUsed
                    );
                    IFGOChild(childRef.childContract).incrementTotalPrepaidUsed(
                        childRef.childId,
                        prepaidUsed
                    );
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}
