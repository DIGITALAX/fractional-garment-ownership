// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

contract FGOMarketErrors {
    error MintFailed();
    error Unauthorized();
    error InvalidPurchaseParams();
    error MaxSupplyReached();
    error ChildNotAuthorized();
    error ChildInactive();
    error OrderNotFound();
    error OrderNotFulfillable();
    error StepNotFound();
    error StepAlreadyCompleted();
    error WrongFulfiller();
    error InvalidStepTransition();
    error WorkflowCompleted();
    error NoPhysicalFulfillment();
    error InvalidParent();
    error InvalidPosition();
    error AlreadyMatched();
    error NotMatched();
    error AlreadyPaid();
    error DeadlinePassed();
    error ChildMismatch();
    error AvailabilityMismatch();
    error PriceTooHigh();
    error IncorrectPayment();
    error PaymentFailed();
    error CannotUseTemplate();
    error CannotUseForSupplyRequests();
    error AlreadyProposed();
    error NoProposal();
    error ProposalRejected();
    error DeadlineNotPassed();
    error InvalidDeadline();
}
