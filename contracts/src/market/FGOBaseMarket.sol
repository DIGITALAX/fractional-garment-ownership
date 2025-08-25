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
    bool public isPaused;
    string public symbol;
    string public name;
    string public marketURI;

    mapping(uint256 => FGOMarketLibrary.OrderReceipt) private _orders;
    mapping(address => uint256[]) private _buyerOrders;

    event OrderExecuted(
        address indexed buyer,
        uint256 totalPayments,
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

    function buy(
        FGOMarketLibrary.PurchaseParams[] memory params
    ) external nonReentrant whenNotPaused {
        _validatePurchase(params);

        FGOMarketLibrary.PaymentBreakdown memory breakdown = _calculatePayments(
            params
        );

        _executePayments(breakdown);
        _mintTokens(params);

        uint256[] memory orderIds = new uint256[](params.length);

        for (uint256 i = 0; i < params.length; ) {
            _orderCounter++;
            orderIds[i] = _orderCounter;

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

        emit OrderExecuted(msg.sender, breakdown.totalPayments, orderIds);
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

            if (param.childId != 0) {
                if (param.childAmount == 0) {
                    revert FGOMarketErrors.InvalidPurchaseParams();
                }
                if (
                    !IFGOChild(param.childContract).getStandaloneAllowed(
                        param.childId
                    )
                ) {
                    revert FGOMarketErrors.Unauthorized();
                }
                if (
                    !IFGOChild(param.childContract).approvesMarket(
                        param.childId,
                        address(this)
                    )
                ) {
                    revert FGOMarketErrors.Unauthorized();
                }
                if (
                    !IFGOChild(param.childContract).isChildActive(param.childId)
                ) {
                    revert FGOMarketErrors.ChildInactive();
                }

                FGOLibrary.ChildMetadata memory child = IFGOChild(
                    param.childContract
                ).getChildMetadata(param.childId);
                if (
                    param.isPhysical &&
                    child.physicalFulfillments + param.childAmount >
                    child.maxPhysicalFulfillments &&
                    child.maxPhysicalFulfillments > 0
                ) {
                    revert FGOMarketErrors.MaxSupplyReached();
                }
            }

            if (param.parentId != 0) {
                if (param.parentAmount == 0) {
                    revert FGOMarketErrors.InvalidPurchaseParams();
                }
                if (
                    !IFGOParent(param.parentContract).approvesMarket(
                        param.parentId,
                        address(this)
                    )
                ) {
                    revert FGOMarketErrors.Unauthorized();
                }
                if (
                    !IFGOParent(param.parentContract).isParentActive(
                        param.parentId
                    )
                ) {
                    revert FGOMarketErrors.ChildInactive();
                }

                FGOLibrary.ParentMetadata memory parent = IFGOParent(
                    param.parentContract
                ).getDesignTemplate(param.parentId);
                if (
                    param.isPhysical &&
                    parent.currentPhysicalEditions + param.parentAmount >
                    parent.maxPhysicalEditions &&
                    parent.maxPhysicalEditions > 0
                ) {
                    revert FGOMarketErrors.MaxSupplyReached();
                }
                if (
                    !param.isPhysical &&
                    parent.currentDigitalEditions + param.parentAmount >
                    parent.maxDigitalEditions &&
                    parent.maxDigitalEditions > 0
                ) {
                    revert FGOMarketErrors.MaxSupplyReached();
                }

                for (uint256 k = 0; k < parent.childReferences.length; ) {
                    FGOLibrary.ChildReference memory childRef = parent
                        .childReferences[k];
                    if (
                        !IFGOChild(childRef.childContract).approvesParent(
                            childRef.childId,
                            param.parentId,
                            param.parentContract
                        )
                    ) {
                        revert FGOMarketErrors.ChildNotAuthorized();
                    }
                    unchecked {
                        ++k;
                    }
                }
            }

            if (param.templateId != 0) {
                if (param.templateAmount == 0) {
                    revert FGOMarketErrors.InvalidPurchaseParams();
                }
                if (
                    !IFGOChild(param.templateContract).getStandaloneAllowed(
                        param.templateId
                    )
                ) {
                    revert FGOMarketErrors.Unauthorized();
                }
                if (
                    !IFGOChild(param.templateContract).approvesMarket(
                        param.templateId,
                        address(this)
                    )
                ) {
                    revert FGOMarketErrors.Unauthorized();
                }
                if (
                    !IFGOChild(param.templateContract).isChildActive(
                        param.templateId
                    )
                ) {
                    revert FGOMarketErrors.ChildInactive();
                }

                FGOLibrary.ChildMetadata memory template = IFGOChild(
                    param.templateContract
                ).getChildMetadata(param.templateId);
                if (
                    param.isPhysical &&
                    template.physicalFulfillments + param.templateAmount >
                    template.maxPhysicalFulfillments &&
                    template.maxPhysicalFulfillments > 0
                ) {
                    revert FGOMarketErrors.MaxSupplyReached();
                }
            }
            unchecked {
                ++j;
            }
        }
    }

    function _calculatePayments(
        FGOMarketLibrary.PurchaseParams[] memory params
    ) internal view returns (FGOMarketLibrary.PaymentBreakdown memory) {
        uint256 paymentCount = 0;
        uint256 totalFulfillers = 0;

        for (uint256 i = 0; i < params.length; ) {
            if (
                params[i].childId != 0 ||
                params[i].parentId != 0 ||
                params[i].templateId != 0
            ) {
                paymentCount++;

                if (params[i].parentId != 0) {
                    FGOLibrary.ParentMetadata memory parent = IFGOParent(
                        params[i].parentContract
                    ).getDesignTemplate(params[i].parentId);

                    FGOLibrary.FulfillmentStep[] memory steps = params[i]
                        .isPhysical
                        ? parent.workflow.physicalSteps
                        : parent.workflow.digitalSteps;

                    for (uint256 j = 0; j < steps.length; ) {
                        totalFulfillers++;
                        totalFulfillers += steps[j].subPerformers.length;
                        unchecked {
                            ++j;
                        }
                    }
                }
            }
            unchecked {
                ++i;
            }
        }

        paymentCount += totalFulfillers;

        FGOMarketLibrary.PaymentItem[]
            memory payments = new FGOMarketLibrary.PaymentItem[](paymentCount);
        uint256 totalPayments = 0;
        uint256 paymentIndex = 0;

        for (uint256 i = 0; i < params.length; ) {
            FGOMarketLibrary.PurchaseParams memory param = params[i];

            if (param.childId != 0) {
                FGOLibrary.ChildMetadata memory child = IFGOChild(
                    param.childContract
                ).getChildMetadata(param.childId);
                uint256 price = param.isPhysical
                    ? child.physicalPrice
                    : child.digitalPrice;
                uint256 total = price * param.childAmount;

                payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                    fulfillerId: param.childId,
                    amount: total,
                    paymentType: FGOMarketLibrary.PaymentType.CHILD_PAYMENT,
                    recipient: child.supplier
                });
                totalPayments += total;
                paymentIndex++;
            } else if (param.parentId != 0) {
                FGOLibrary.ParentMetadata memory parent = IFGOParent(
                    param.parentContract
                ).getDesignTemplate(param.parentId);
                uint256 price = param.isPhysical
                    ? parent.physicalPrice
                    : parent.digitalPrice;
                uint256 parentTotal = price * param.parentAmount;
                uint256 fulfillerTotal = 0;

                FGOLibrary.FulfillmentStep[] memory steps = param.isPhysical
                    ? parent.workflow.physicalSteps
                    : parent.workflow.digitalSteps;

                if (steps.length > 0) {
                    for (uint256 k = 0; k < steps.length; ) {
                        address primaryPerformer = steps[k].primaryPerformer;

                        if (primaryPerformer != address(0)) {
                            uint256 fulfillerId = fulfillers
                                .getFulfillerIdByAddress(primaryPerformer);

                            if (fulfillerId != 0) {
                                FGOLibrary.FulfillerProfile
                                    memory fulfillerProfile = fulfillers
                                        .getFulfillerProfile(fulfillerId);

                                uint256 fulfillerPayment = fulfillerProfile
                                    .basePrice +
                                    ((parentTotal *
                                        fulfillerProfile.vigBasisPoints) /
                                        10000);

                                uint256 totalSubPerformerPayments = 0;

                                for (
                                    uint256 m = 0;
                                    m < steps[k].subPerformers.length;

                                ) {
                                    FGOLibrary.SubPerformer
                                        memory subPerformer = steps[k]
                                            .subPerformers[m];
                                    uint256 subPayment = (fulfillerPayment *
                                        subPerformer.splitBasisPoints) / 10000;

                                    payments[paymentIndex] = FGOMarketLibrary
                                        .PaymentItem({
                                            fulfillerId: fulfillerId,
                                            amount: subPayment,
                                            paymentType: FGOMarketLibrary
                                                .PaymentType
                                                .FULFILLER_PAYMENT,
                                            recipient: subPerformer.performer
                                        });

                                    totalSubPerformerPayments += subPayment;
                                    paymentIndex++;

                                    unchecked {
                                        ++m;
                                    }
                                }

                                uint256 primaryFulfillerActualPayment = fulfillerPayment -
                                        totalSubPerformerPayments;

                                payments[paymentIndex] = FGOMarketLibrary
                                    .PaymentItem({
                                        fulfillerId: fulfillerId,
                                        amount: primaryFulfillerActualPayment,
                                        paymentType: FGOMarketLibrary
                                            .PaymentType
                                            .FULFILLER_PAYMENT,
                                        recipient: primaryPerformer
                                    });

                                fulfillerTotal += fulfillerPayment;
                                totalPayments += fulfillerPayment;
                                paymentIndex++;
                            }
                        }

                        unchecked {
                            ++k;
                        }
                    }
                }

                uint256 designerAmount = parentTotal - fulfillerTotal;
                payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                    fulfillerId: param.parentId,
                    amount: designerAmount,
                    paymentType: FGOMarketLibrary.PaymentType.PARENT_PAYMENT,
                    recipient: parent.designer
                });
                totalPayments += designerAmount;
                paymentIndex++;
            } else if (param.templateId != 0) {
                FGOLibrary.ChildMetadata memory template = IFGOChild(
                    param.templateContract
                ).getChildMetadata(param.templateId);
                uint256 price = param.isPhysical
                    ? template.physicalPrice
                    : template.digitalPrice;
                uint256 total = price * param.templateAmount;

                payments[paymentIndex] = FGOMarketLibrary.PaymentItem({
                    fulfillerId: param.templateId,
                    amount: total,
                    paymentType: FGOMarketLibrary.PaymentType.TEMPLATE_PAYMENT,
                    recipient: template.supplier
                });
                totalPayments += total;
                paymentIndex++;
            }
            unchecked {
                ++i;
            }
        }

        return
            FGOMarketLibrary.PaymentBreakdown({
                totalPayments: totalPayments,
                payments: payments
            });
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
        FGOMarketLibrary.PurchaseParams[] memory params
    ) internal {
        for (uint256 i = 0; i < params.length; ) {
            FGOMarketLibrary.PurchaseParams memory param = params[i];

            if (param.childId != 0) {
                try
                    IFGOChild(param.childContract).mint(
                        param.childId,
                        param.childAmount,
                        param.isPhysical,
                        msg.sender,
                        address(this)
                    )
                {} catch {
                    revert FGOMarketErrors.MintFailed();
                }
            }

            if (param.parentId != 0) {
                IFGOParent(param.parentContract).mint(
                    param.parentId,
                    param.parentAmount,
                    param.isPhysical,
                    msg.sender,
                    address(this)
                );
            }

            if (param.templateId != 0) {
                IFGOChild(param.templateContract).mint(
                    param.templateId,
                    param.templateAmount,
                    param.isPhysical,
                    msg.sender,
                    address(this)
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    function getOrderReceipt(
        uint256 orderId
    ) public view returns (FGOMarketLibrary.OrderReceipt memory) {
        return _orders[orderId];
    }

    function getBuyerOrders(
        address buyer
    ) public view returns (uint256[] memory) {
        return _buyerOrders[buyer];
    }

    function getOrderCounter() public view returns (uint256) {
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
}
