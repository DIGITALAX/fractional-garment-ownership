// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../fgo/FGOAccessControl.sol";
import "../fgo/FGOLibrary.sol";
import "../interfaces/IFGOContracts.sol";
import "./FGOMarketLibrary.sol";
import "./FGOMarketErrors.sol";

contract FGOFulfillment is ReentrancyGuard {
    bytes32 public infraId;
    FGOAccessControl public accessControl;
    address public market;

    mapping(uint256 => FGOMarketLibrary.FulfillmentStatus)
        private _fulfillmentStatuses;
    mapping(address => uint256[]) private _fulfillerOrders;

    event FulfillmentStarted(uint256 indexed orderId, uint256 indexed parentId);
    event StepCompleted(
        uint256 indexed orderId,
        uint256 indexed stepIndex,
        address indexed fulfiller,
        string notes
    );
    event FulfillmentCompleted(uint256 indexed orderId);
    event OrderStatusUpdated(
        uint256 indexed orderId,
        FGOMarketLibrary.OrderStatus status
    );

    modifier onlyMarket() {
        if (msg.sender != market) {
            revert FGOMarketErrors.Unauthorized();
        }
        _;
    }

    modifier onlyFulfiller() {
        if (!accessControl.isFulfiller(msg.sender)) {
            revert FGOMarketErrors.Unauthorized();
        }
        _;
    }

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOMarketErrors.Unauthorized();
        }
        _;
    }

    constructor(bytes32 _infraId, address _accessControl, address _market) {
        infraId = _infraId;
        accessControl = FGOAccessControl(_accessControl);
        market = _market;
    }

    function startFulfillment(
        uint256 orderId,
        uint256 parentId,
        address parentContract,
        bool isPhysical
    ) external onlyMarket nonReentrant {
        if (_fulfillmentStatuses[orderId].orderId != 0) {
            revert FGOMarketErrors.OrderNotFulfillable();
        }

        FGOLibrary.ParentMetadata memory parent = IFGOParent(parentContract)
            .getDesignTemplate(parentId);

        FGOLibrary.FulfillmentStep[] memory steps = isPhysical
            ? parent.workflow.physicalSteps
            : parent.workflow.digitalSteps;

        uint256 stepCount = steps.length;

        _fulfillmentStatuses[orderId] = FGOMarketLibrary.FulfillmentStatus({
            orderId: orderId,
            parentId: parentId,
            parentContract: parentContract,
            currentStep: 0,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp,
            steps: new FGOMarketLibrary.StepCompletion[](stepCount)
        });

        for (uint256 i = 0; i < stepCount; ) {
            address performer = steps[i].primaryPerformer;
            if (performer != address(0)) {
                _fulfillerOrders[performer].push(orderId);
            }
            unchecked {
                ++i;
            }
        }

        emit FulfillmentStarted(orderId, parentId);
    }

    function completeStep(
        uint256 orderId,
        uint256 stepIndex,
        string memory notes
    ) external nonReentrant {
        if (!accessControl.isFulfiller(msg.sender) && !accessControl.canCreateParents(msg.sender)) {
            revert FGOMarketErrors.Unauthorized();
        }
        FGOMarketLibrary.FulfillmentStatus
            storage fulfillment = _fulfillmentStatuses[orderId];

        if (fulfillment.orderId == 0) {
            revert FGOMarketErrors.OrderNotFound();
        }

        if (stepIndex >= fulfillment.steps.length) {
            revert FGOMarketErrors.InvalidStepTransition();
        }

        if (fulfillment.steps[stepIndex].isCompleted) {
            revert FGOMarketErrors.StepAlreadyCompleted();
        }

        if (stepIndex != fulfillment.currentStep) {
            revert FGOMarketErrors.InvalidStepTransition();
        }

        FGOLibrary.ParentMetadata memory parent = IFGOParent(
            fulfillment.parentContract
        ).getDesignTemplate(fulfillment.parentId);

        FGOMarketLibrary.OrderReceipt memory orderReceipt = IFGOMarket(market)
            .getOrderReceipt(orderId);
        bool isPhysical = orderReceipt.params.isPhysical;

        FGOLibrary.FulfillmentStep[] memory steps = isPhysical
            ? parent.workflow.physicalSteps
            : parent.workflow.digitalSteps;

        FGOLibrary.FulfillmentStep memory step = steps[stepIndex];

        if (step.primaryPerformer == address(0)) {
            if (parent.designer != msg.sender) {
                revert FGOMarketErrors.WrongFulfiller();
            }
        } else {
            if (step.primaryPerformer != msg.sender) {
                revert FGOMarketErrors.WrongFulfiller();
            }
        }

        fulfillment.steps[stepIndex] = FGOMarketLibrary.StepCompletion({
            fulfiller: msg.sender,
            completedAt: block.timestamp,
            notes: notes,
            isCompleted: true
        });

        fulfillment.currentStep = stepIndex + 1;
        fulfillment.lastUpdated = block.timestamp;

        emit StepCompleted(orderId, stepIndex, msg.sender, notes);

        if ((fulfillment.currentStep == steps.length)) {
            if (isPhysical) {
                _fulfillChildren(fulfillment, orderReceipt);
            }
            emit FulfillmentCompleted(orderId);
        }
    }

    function updateOrderStatus(
        uint256 orderId,
        FGOMarketLibrary.OrderStatus status
    ) external onlyAdmin nonReentrant {
        FGOMarketLibrary.FulfillmentStatus
            storage fulfillment = _fulfillmentStatuses[orderId];

        if (fulfillment.orderId == 0) {
            revert FGOMarketErrors.OrderNotFound();
        }

        fulfillment.lastUpdated = block.timestamp;

        try
            IFGOMarket(market).updateMarketOrderStatus(orderId, status)
        {} catch {}

        emit OrderStatusUpdated(orderId, status);
    }

    function getFulfillmentStatus(
        uint256 orderId
    ) external view returns (FGOMarketLibrary.FulfillmentStatus memory) {
        if (_fulfillmentStatuses[orderId].orderId == 0) {
            revert FGOMarketErrors.OrderNotFound();
        }
        return _fulfillmentStatuses[orderId];
    }

    function getFulfillerOrders(
        address fulfiller
    ) external view returns (uint256[] memory) {
        return _fulfillerOrders[fulfiller];
    }

    function getOrderCurrentStep(
        uint256 orderId
    ) external view returns (uint256, FGOLibrary.FulfillmentStep memory) {
        FGOMarketLibrary.FulfillmentStatus
            memory fulfillment = _fulfillmentStatuses[orderId];

        if (fulfillment.orderId == 0) {
            revert FGOMarketErrors.OrderNotFound();
        }

        FGOLibrary.ParentMetadata memory parent = IFGOParent(
            fulfillment.parentContract
        ).getDesignTemplate(fulfillment.parentId);

        FGOMarketLibrary.OrderReceipt memory orderReceipt = IFGOMarket(market)
            .getOrderReceipt(orderId);
        bool isPhysical = orderReceipt.params.isPhysical;

        FGOLibrary.FulfillmentStep[] memory steps = isPhysical
            ? parent.workflow.physicalSteps
            : parent.workflow.digitalSteps;

        if (fulfillment.currentStep >= steps.length) {
            revert FGOMarketErrors.WorkflowCompleted();
        }

        return (fulfillment.currentStep, steps[fulfillment.currentStep]);
    }

    function setMarket(address _market) external onlyAdmin {
        market = _market;
    }

    function _fulfillChildren(
        FGOMarketLibrary.FulfillmentStatus memory fulfillment,
        FGOMarketLibrary.OrderReceipt memory orderReceipt
    ) internal {
        FGOLibrary.ParentMetadata memory parent = IFGOParent(
            fulfillment.parentContract
        ).getDesignTemplate(fulfillment.parentId);

        uint256 amount = orderReceipt.params.parentAmount;
        address buyer = orderReceipt.buyer;

        _fulfillNestedChildren(parent.childReferences, amount, buyer);
    }

    function _fulfillNestedChildren(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 amount,
        address buyer
    ) internal {
        for (uint256 i = 0; i < childReferences.length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];
            FGOLibrary.ChildMetadata memory child = IFGOChild(
                childRef.childContract
            ).getChildMetadata(childRef.childId);

            if (child.isTemplate) {
                try
                    IFGOChild(childRef.childContract).fulfillPhysicalTokens(
                        childRef.childId,
                        childRef.amount * amount,
                        buyer
                    )
                {} catch {}

                FGOLibrary.ChildReference[]
                    memory templateReferences = IFGOTemplate(
                        childRef.childContract
                    ).getTemplatePlacements(childRef.childId);

                _fulfillNestedChildren(
                    templateReferences,
                    childRef.amount * amount,
                    buyer
                );
            } else {
                try
                    IFGOChild(childRef.childContract).fulfillPhysicalTokens(
                        childRef.childId,
                        childRef.amount * amount,
                        buyer
                    )
                {} catch {}
            }

            unchecked {
                ++i;
            }
        }
    }
}
