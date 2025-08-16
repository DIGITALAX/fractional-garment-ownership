// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOAccessControl.sol";
import "./FGOLibrary.sol";
import "./FGOErrors.sol";
import "./FGOParent.sol";
import "./FGOFulfillers.sol";
import "./IFGOMarket.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FGOWorkflowExecutor is ReentrancyGuard {
    FGOAccessControl public accessControl;
    FGOParent public parentFGO;
    FGOFulfillers public fulfillers;
    
    constructor(address _accessControl, address _parentFGO, address _fulfillers) {
        accessControl = FGOAccessControl(_accessControl);
        parentFGO = FGOParent(_parentFGO);
        fulfillers = FGOFulfillers(_fulfillers);
    }
    
    mapping(uint256 => WorkflowExecution) private _executions;
    mapping(uint256 => bool) private _executionExists;
    mapping(uint256 => RefundRequest) private _refundRequests;
    uint256 private _executionSupply;
    uint256 private _refundRequestSupply;
    
    struct WorkflowExecution {
        uint256 executionId;
        uint256 orderId;
        uint256 parentTokenId;
        uint256 currentStepIndex;
        FGOLibrary.StepStatus[] stepStatuses;
        mapping(uint256 => uint256) stepPayments;
        mapping(uint256 => bool) stepPaymentReleased;
        mapping(uint256 => bool) upfrontPaymentReleased;
        mapping(uint256 => bool) finalPaymentReleased;
        uint256 totalPayment;
        uint256 reservedForFinalPayments;
        address paymentCurrency;
        bool isCompleted;
        bool isRejected;
        address buyer;
        address marketContract;
    }
    
    struct RefundRequest {
        uint256 executionId;
        address buyer;
        string reason;
        address[] fulfillers;
        mapping(address => bool) fulfillerApprovals;
        uint256 approvalsReceived;
        bool executed;
        uint256 createdAt;
    }
    
    event WorkflowInitiated(uint256 indexed executionId, uint256 indexed orderId, uint256 indexed parentTokenId);
    event StepStarted(uint256 indexed executionId, uint256 stepIndex, address performer);
    event StepCompleted(uint256 indexed executionId, uint256 stepIndex, address performer);
    event StepRejected(uint256 indexed executionId, uint256 stepIndex, address performer, string reason);
    event StepFailed(uint256 indexed executionId, uint256 stepIndex, address performer, string reason);
    event PaymentReleased(uint256 indexed executionId, uint256 stepIndex, address recipient, uint256 amount);
    event WorkflowCompleted(uint256 indexed executionId);
    event WorkflowFailed(uint256 indexed executionId);
    event RefundIssued(uint256 indexed executionId, address recipient, uint256 amount);
    event RefundRequested(uint256 indexed requestId, uint256 indexed executionId, address buyer, string reason);
    event RefundApproved(uint256 indexed requestId, address fulfiller);
    event RefundExecuted(uint256 indexed requestId, uint256 refundAmount);
    
    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }
    
    modifier onlyStepPerformer(uint256 executionId) {
        WorkflowExecution storage execution = _executions[executionId];
        FGOLibrary.FulfillmentWorkflow memory workflow = parentFGO.getParentWorkflow(execution.parentTokenId);
        
        if (execution.currentStepIndex >= workflow.steps.length) {
            revert FGOErrors.InvalidAmount();
        }
        
        if (workflow.steps[execution.currentStepIndex].primaryPerformer != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }
    
    modifier onlyBuyer(uint256 executionId) {
        if (_executions[executionId].buyer != msg.sender) {
            revert FGOErrors.AddressInvalid();
        }
        _;
    }
    
    function initiateWorkflow(
        uint256 orderId,
        uint256 parentTokenId,
        uint256 totalPayment,
        address paymentCurrency,
        address buyer
    ) external returns (uint256) {
        if (!accessControl.isAuthorizedMarket(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        FGOLibrary.FulfillmentWorkflow memory workflow = parentFGO.getParentWorkflow(parentTokenId);
        
        if (workflow.steps.length == 0) {
            revert FGOErrors.InvalidAmount();
        }
        
        uint256 totalBasisPoints = 0;
        for (uint256 i = 0; i < workflow.steps.length; i++) {
            totalBasisPoints += workflow.steps[i].paymentBasisPoints;
            
            if (!fulfillers.fulfillerExists(fulfillers.getFulfillerIdByAddress(workflow.steps[i].primaryPerformer))) {
                revert FGOErrors.AddressInvalid();
            }
        }
        
        if (totalBasisPoints != 10000) {
            revert FGOErrors.InvalidAmount();
        }
        
        _executionSupply++;
        
        WorkflowExecution storage execution = _executions[_executionSupply];
        execution.executionId = _executionSupply;
        execution.orderId = orderId;
        execution.parentTokenId = parentTokenId;
        execution.currentStepIndex = 0;
        execution.totalPayment = totalPayment;
        execution.paymentCurrency = paymentCurrency;
        execution.buyer = buyer;
        execution.marketContract = msg.sender;
        
        uint256 totalFinalPaymentReserved = 0;
        
        for (uint256 i = 0; i < workflow.steps.length; i++) {
            execution.stepStatuses.push(FGOLibrary.StepStatus.PENDING);
            uint256 stepPayment = (totalPayment * workflow.steps[i].paymentBasisPoints) / 10000;
            execution.stepPayments[i] = stepPayment;
            execution.stepPaymentReleased[i] = false;
            execution.upfrontPaymentReleased[i] = false;
            execution.finalPaymentReleased[i] = false;
            
            uint256 upfrontAmount = (stepPayment * 50) / 100;
            uint256 finalReserve = (stepPayment * 25) / 100;
            totalFinalPaymentReserved += finalReserve;
            
            IERC20(paymentCurrency).transfer(workflow.steps[i].primaryPerformer, upfrontAmount);
            execution.upfrontPaymentReleased[i] = true;
        }
        
        execution.reservedForFinalPayments = totalFinalPaymentReserved;
        
        execution.stepStatuses[0] = FGOLibrary.StepStatus.IN_PROGRESS;
        _executionExists[_executionSupply] = true;
        
        emit WorkflowInitiated(_executionSupply, orderId, parentTokenId);
        emit StepStarted(_executionSupply, 0, workflow.steps[0].primaryPerformer);
        
        return _executionSupply;
    }
    
    function completeStep(uint256 executionId) external nonReentrant onlyStepPerformer(executionId) {
        WorkflowExecution storage execution = _executions[executionId];
        
        if (execution.isCompleted || execution.isRejected) {
            revert FGOErrors.InvalidAmount();
        }
        
        uint256 currentStep = execution.currentStepIndex;
        execution.stepStatuses[currentStep] = FGOLibrary.StepStatus.COMPLETED;
        
        _releaseStepPayment(executionId, currentStep);
        
        emit StepCompleted(executionId, currentStep, msg.sender);
        
        FGOLibrary.FulfillmentWorkflow memory workflow = parentFGO.getParentWorkflow(execution.parentTokenId);
        
        if (currentStep + 1 >= workflow.steps.length) {
            execution.isCompleted = true;
            _releaseFinalPayments(executionId);
            _completePhysicalFulfillment(executionId);
            emit WorkflowCompleted(executionId);
        } else {
            execution.currentStepIndex++;
            execution.stepStatuses[execution.currentStepIndex] = FGOLibrary.StepStatus.IN_PROGRESS;
            emit StepStarted(executionId, execution.currentStepIndex, workflow.steps[execution.currentStepIndex].primaryPerformer);
        }
    }
    
    function rejectStep(uint256 executionId, string memory reason) external nonReentrant onlyStepPerformer(executionId) {
        WorkflowExecution storage execution = _executions[executionId];
        
        if (execution.isCompleted || execution.isRejected) {
            revert FGOErrors.InvalidAmount();
        }
        
        uint256 currentStep = execution.currentStepIndex;
        execution.stepStatuses[currentStep] = FGOLibrary.StepStatus.REJECTED;
        execution.isRejected = true;
        
        emit StepRejected(executionId, currentStep, msg.sender, reason);
        emit WorkflowFailed(executionId);
    }
    
    function failStep(uint256 executionId, string memory reason) external nonReentrant onlyStepPerformer(executionId) {
        WorkflowExecution storage execution = _executions[executionId];
        
        if (execution.isCompleted || execution.isRejected) {
            revert FGOErrors.InvalidAmount();
        }
        
        uint256 currentStep = execution.currentStepIndex;
        execution.stepStatuses[currentStep] = FGOLibrary.StepStatus.FAILED;
        execution.isRejected = true;
        
        emit StepFailed(executionId, currentStep, msg.sender, reason);
        emit WorkflowFailed(executionId);
        
        _issueRefund(executionId);
    }
    
    function _releaseStepPayment(uint256 executionId, uint256 stepIndex) internal {
        WorkflowExecution storage execution = _executions[executionId];
        
        if (execution.stepPaymentReleased[stepIndex]) {
            return;
        }
        
        uint256 totalStepPayment = execution.stepPayments[stepIndex];
        uint256 completionPayment = (totalStepPayment * 25) / 100;
        
        FGOLibrary.FulfillmentWorkflow memory workflow = parentFGO.getParentWorkflow(execution.parentTokenId);
        FGOLibrary.FulfillmentStep memory step = workflow.steps[stepIndex];
        
        execution.stepPaymentReleased[stepIndex] = true;
        
        if (step.subPerformers.length == 0) {
            IERC20(execution.paymentCurrency).transfer(step.primaryPerformer, completionPayment);
            emit PaymentReleased(executionId, stepIndex, step.primaryPerformer, completionPayment);
        } else {
            for (uint256 i = 0; i < step.subPerformers.length; i++) {
                uint256 subPayment = (completionPayment * step.subPerformers[i].splitBasisPoints) / 10000;
                IERC20(execution.paymentCurrency).transfer(step.subPerformers[i].performer, subPayment);
                emit PaymentReleased(executionId, stepIndex, step.subPerformers[i].performer, subPayment);
            }
        }
    }
    
    function _releaseFinalPayments(uint256 executionId) internal {
        WorkflowExecution storage execution = _executions[executionId];
        FGOLibrary.FulfillmentWorkflow memory workflow = parentFGO.getParentWorkflow(execution.parentTokenId);
        
        for (uint256 i = 0; i < workflow.steps.length; i++) {
            if (execution.stepStatuses[i] == FGOLibrary.StepStatus.COMPLETED && !execution.finalPaymentReleased[i]) {
                uint256 totalStepPayment = execution.stepPayments[i];
                uint256 finalPayment = (totalStepPayment * 25) / 100;
                
                FGOLibrary.FulfillmentStep memory step = workflow.steps[i];
                execution.finalPaymentReleased[i] = true;
                
                if (step.subPerformers.length == 0) {
                    IERC20(execution.paymentCurrency).transfer(step.primaryPerformer, finalPayment);
                    emit PaymentReleased(executionId, i, step.primaryPerformer, finalPayment);
                } else {
                    for (uint256 j = 0; j < step.subPerformers.length; j++) {
                        uint256 subPayment = (finalPayment * step.subPerformers[j].splitBasisPoints) / 10000;
                        IERC20(execution.paymentCurrency).transfer(step.subPerformers[j].performer, subPayment);
                        emit PaymentReleased(executionId, i, step.subPerformers[j].performer, subPayment);
                    }
                }
            }
        }
    }
    
    function fundWorkflow(uint256 executionId, uint256 amount) external nonReentrant {
        if (!accessControl.isAuthorizedMarket(msg.sender)) {
            revert FGOErrors.AddressInvalid();
        }
        WorkflowExecution storage execution = _executions[executionId];
        
        IERC20(execution.paymentCurrency).transferFrom(msg.sender, address(this), amount);
    }
    
    function getWorkflowExecution(uint256 executionId) external view returns (
        uint256 orderId,
        uint256 parentTokenId,
        uint256 currentStepIndex,
        uint256 totalPayment,
        address paymentCurrency,
        bool isCompleted,
        bool isRejected,
        address buyer
    ) {
        WorkflowExecution storage execution = _executions[executionId];
        return (
            execution.orderId,
            execution.parentTokenId,
            execution.currentStepIndex,
            execution.totalPayment,
            execution.paymentCurrency,
            execution.isCompleted,
            execution.isRejected,
            execution.buyer
        );
    }
    
    function getStepStatus(uint256 executionId, uint256 stepIndex) external view returns (FGOLibrary.StepStatus) {
        return _executions[executionId].stepStatuses[stepIndex];
    }
    
    function getStepPayment(uint256 executionId, uint256 stepIndex) external view returns (uint256) {
        return _executions[executionId].stepPayments[stepIndex];
    }
    
    function isStepPaymentReleased(uint256 executionId, uint256 stepIndex) external view returns (bool) {
        return _executions[executionId].stepPaymentReleased[stepIndex];
    }
    
    function setAccessControl(address _accessControl) external onlyAdmin {
        accessControl = FGOAccessControl(_accessControl);
    }
    
    function setParentFGO(address _parentFGO) external onlyAdmin {
        parentFGO = FGOParent(_parentFGO);
    }
    
    function setFulfillers(address _fulfillers) external onlyAdmin {
        fulfillers = FGOFulfillers(_fulfillers);
    }
    
    function _issueRefund(uint256 executionId) internal {
        WorkflowExecution storage execution = _executions[executionId];
        
        uint256 refundAmount = execution.totalPayment;
        
        if (refundAmount > 0) {
            IERC20(execution.paymentCurrency).transfer(execution.buyer, refundAmount);
            emit RefundIssued(executionId, execution.buyer, refundAmount);
        }
    }
    
    function adminRefund(uint256 executionId) external onlyAdmin {
        WorkflowExecution storage execution = _executions[executionId];
        
        if (!execution.isRejected && !execution.isCompleted) {
            execution.isRejected = true;
        }
        
        _issueRefund(executionId);
    }
    
    function requestRefund(uint256 executionId, string memory reason) external {
        WorkflowExecution storage execution = _executions[executionId];
         FGOLibrary.FulfillmentWorkflow memory workflow = parentFGO.getParentWorkflow(execution.parentTokenId);
            
        bool canRequest = false;
        
        if (execution.buyer == msg.sender) {
            canRequest = true;  
        } else {
           
            for (uint256 i = 0; i < workflow.steps.length; i++) {
                if (workflow.steps[i].primaryPerformer == msg.sender) {
                    canRequest = true;
                    break;
                }
                for (uint256 j = 0; j < workflow.steps[i].subPerformers.length; j++) {
                    if (workflow.steps[i].subPerformers[j].performer == msg.sender) {
                        canRequest = true;
                        break;
                    }
                }
                if (canRequest) break;
            }
            
            if (!canRequest) {
                address designer = parentFGO.ownerOf(execution.parentTokenId);
                if (designer == msg.sender) {
                    canRequest = true;
                }
            }
        }
        
        if (!canRequest) {
            revert FGOErrors.AddressInvalid();
        }
        
        if (execution.isCompleted || execution.isRejected) {
            revert FGOErrors.InvalidAmount();
        }
        
        _refundRequestSupply++;
        
        
        RefundRequest storage request = _refundRequests[_refundRequestSupply];
        request.executionId = executionId;
        request.buyer = msg.sender;
        request.reason = reason;
        request.executed = false;
        request.createdAt = block.timestamp;
        
        for (uint256 i = 0; i < workflow.steps.length; i++) {
            request.fulfillers.push(workflow.steps[i].primaryPerformer);
        }
        
        emit RefundRequested(_refundRequestSupply, executionId, msg.sender, reason);
    }
    
    function approveFulfillerRefund(uint256 requestId) external {
        RefundRequest storage request = _refundRequests[requestId];
        
        if (request.executed) {
            revert FGOErrors.InvalidAmount();
        }
        
        bool isFulfillerInWorkflow = false;
        for (uint256 i = 0; i < request.fulfillers.length; i++) {
            if (request.fulfillers[i] == msg.sender) {
                isFulfillerInWorkflow = true;
                break;
            }
        }
        
        if (!isFulfillerInWorkflow) {
            revert FGOErrors.AddressInvalid();
        }
        
        if (request.fulfillerApprovals[msg.sender]) {
            revert FGOErrors.Existing();
        }
        
        request.fulfillerApprovals[msg.sender] = true;
        request.approvalsReceived++;
        
        emit RefundApproved(requestId, msg.sender);
        
        uint256 requiredApprovals = (request.fulfillers.length * 60 + 99) / 100;
        if (requiredApprovals == 0 && request.fulfillers.length > 0) {
            requiredApprovals = 1;
        }
        
        if (request.approvalsReceived >= requiredApprovals) {
            _executeRefund(requestId);
        }
    }
    
    function _executeRefund(uint256 requestId) internal {
        RefundRequest storage request = _refundRequests[requestId];
        WorkflowExecution storage execution = _executions[request.executionId];
        
        request.executed = true;
        execution.isRejected = true;
        
        uint256 totalRefundAmount = execution.totalPayment;
        
        IERC20(execution.paymentCurrency).transfer(request.buyer, totalRefundAmount);
        
        FGOLibrary.FulfillmentWorkflow memory workflow = parentFGO.getParentWorkflow(execution.parentTokenId);
        
        for (uint256 i = 0; i < workflow.steps.length; i++) {
            if (execution.stepStatuses[i] == FGOLibrary.StepStatus.COMPLETED) {
                uint256 totalStepPayment = execution.stepPayments[i];
                uint256 upfrontAmount = (totalStepPayment * 50) / 100;
                uint256 completionAmount = (totalStepPayment * 25) / 100;
                uint256 debtAmount = upfrontAmount + completionAmount;
                
                fulfillers.addDebt(workflow.steps[i].primaryPerformer, debtAmount, 7);
            }
        }
        
        emit RefundExecuted(requestId, totalRefundAmount);
        emit RefundIssued(request.executionId, request.buyer, totalRefundAmount);
    }
    
    function _completePhysicalFulfillment(uint256 executionId) internal {
        WorkflowExecution storage execution = _executions[executionId];
        
        if (execution.marketContract.code.length > 0) {
            IFGOMarket(execution.marketContract).completePhysicalOrder(
                execution.orderId,
                execution.buyer,
                execution.parentTokenId
            );
        }
        
        emit PhysicalFulfillmentCompleted(executionId);
    }
    
    event PhysicalFulfillmentCompleted(uint256 indexed executionId);
    
    function getRefundRequest(uint256 requestId) external view returns (
        uint256 executionId,
        address buyer,
        string memory reason,
        uint256 approvalsReceived,
        uint256 totalFulfillers,
        bool executed
    ) {
        RefundRequest storage request = _refundRequests[requestId];
        return (
            request.executionId,
            request.buyer,
            request.reason,
            request.approvalsReceived,
            request.fulfillers.length,
            request.executed
        );
    }
}