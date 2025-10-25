// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../fgo/FGOAccessControl.sol";
import "../fgo/FGOLibrary.sol";
import "./FGOMarketLibrary.sol";
import "../interfaces/IFGOContracts.sol";
import "./FGOMarketErrors.sol";

contract FGOSupplyCoordination is ReentrancyGuard {
    string public symbol;
    string public name;
    address public factory;

    mapping(bytes32 => FGOMarketLibrary.SupplyRequestPosition)
        private _supplyPositions;
    mapping(bytes32 => mapping(address => FGOMarketLibrary.SupplierProposal))
        private _supplyProposals;
    mapping(bytes32 => address[]) private _proposalSuppliers;
    mapping(address => bytes32[]) private _designerPositions;
    mapping(uint256 => mapping(address => bytes32[])) private _parentPositions;

    event SupplyRequestRegistered(
        bytes32 indexed positionId,
        uint256 indexed parentId,
        address indexed designer,
        address parentContract
    );

    event SupplyProposalSubmitted(
        bytes32 indexed positionId,
        address indexed supplier,
        uint256 childId,
        address childContract
    );

    event SupplyRequestPaid(
        bytes32 indexed positionId,
        address indexed designer,
        address indexed supplier,
        uint256 amount
    );

    event ProposalAccepted(
        bytes32 indexed positionId,
        address indexed supplier
    );

    event SupplyRequestFulfilled(
        bytes32 indexed positionId,
        address indexed supplier,
        uint256 childId,
        address childContract
    );

    event ProposalCancelled(
        bytes32 indexed positionId,
        address indexed supplier
    );

    event ExpiredSupplyReleased(
        bytes32 indexed positionId,
        address indexed supplier
    );

    event ParentSupplyReleased(
        uint256 indexed parentId,
        address indexed parentContract
    );

    modifier onlyParentContract(uint256 parentId, address designer) {
        if (
            factory == address(0) ||
            !IFGOFactory(factory).isValidParent(msg.sender)
        ) {
            revert FGOErrors.Unauthorized();
        }
        FGOLibrary.ParentMetadata memory parent = IFGOParent(msg.sender)
            .getDesignTemplate(parentId);
        if (parent.designer != designer) {
            revert FGOMarketErrors.InvalidParent();
        }
        _;
    }

    constructor(address _factory) {
        symbol = "FGOSC";
        name = "FGOSupplyCoordination";
        factory = _factory;
    }

    function registerSupplyRequest(
        uint256 parentId,
        address designer,
        uint256 requestIndex,
        FGOLibrary.ChildSupplyRequest memory request
    ) external onlyParentContract(parentId, designer) {
        if (request.deadline == 0) {
            revert FGOMarketErrors.InvalidDeadline();
        }
        if (bytes(request.placementURI).length == 0) {
            revert FGOErrors.EmptyPlacementURI();
        }

        bytes32 positionId = keccak256(
            abi.encodePacked(msg.sender, parentId, requestIndex)
        );

        _supplyPositions[positionId] = FGOMarketLibrary.SupplyRequestPosition({
            parentId: parentId,
            matchedChildId: 0,
            parentContract: msg.sender,
            designer: designer,
            matchedSupplier: address(0),
            matchedChildContract: address(0),
            request: request,
            matched: false,
            paid: false,
            fulfilled: false
        });

        _designerPositions[designer].push(positionId);
        _parentPositions[parentId][msg.sender].push(positionId);

        emit SupplyRequestRegistered(
            positionId,
            parentId,
            designer,
            msg.sender
        );
    }

    function proposeSupplyMatch(
        bytes32 positionId,
        uint256 childId,
        address childContract
    ) external nonReentrant {
        FGOMarketLibrary.SupplyRequestPosition
            storage position = _supplyPositions[positionId];

        if (position.parentContract == address(0)) {
            revert FGOMarketErrors.InvalidPosition();
        }
        if (position.paid) {
            revert FGOMarketErrors.AlreadyMatched();
        }
        if (
            position.request.deadline > 0 &&
            block.timestamp > position.request.deadline
        ) {
            revert FGOMarketErrors.DeadlinePassed();
        }

        IFGOChild childContractInterface = IFGOChild(childContract);
        FGOLibrary.ChildMetadata memory childMetadata = childContractInterface
            .getChildMetadata(childId);

        if (childMetadata.supplier != msg.sender) {
            revert FGOMarketErrors.Unauthorized();
        }

        if (childMetadata.isTemplate) {
            revert FGOMarketErrors.CannotUseTemplate();
        }

        if (childMetadata.futures.isFutures) {
            revert FGOMarketErrors.CannotUseForSupplyRequests();
        }

        if (position.request.existingChildId != 0) {
            if (
                childId != position.request.existingChildId ||
                childContract != position.request.childContract
            ) {
                revert FGOMarketErrors.ChildMismatch();
            }
        }

        if (position.request.isPhysical) {
            if (
                childMetadata.availability ==
                FGOLibrary.Availability.DIGITAL_ONLY
            ) {
                revert FGOMarketErrors.AvailabilityMismatch();
            }
        } else {
            if (
                childMetadata.availability ==
                FGOLibrary.Availability.PHYSICAL_ONLY
            ) {
                revert FGOMarketErrors.AvailabilityMismatch();
            }
        }

        if (_supplyProposals[positionId][msg.sender].supplier != address(0)) {
            revert FGOMarketErrors.AlreadyProposed();
        }

        IFGOParent parentInterface = IFGOParent(position.parentContract);
        FGOAccessControl accessControl = parentInterface.accessControl();
        address childPaymentToken = childContractInterface
            .accessControl()
            .PAYMENT_TOKEN();
        address parentPaymentToken = accessControl.PAYMENT_TOKEN();

        if (childPaymentToken != parentPaymentToken) {
            revert FGOMarketErrors.InvalidPurchaseParams();
        }

        _supplyProposals[positionId][msg.sender] = FGOMarketLibrary
            .SupplierProposal({
                childId: childId,
                childContract: childContract,
                supplier: msg.sender,
                timestamp: block.timestamp
            });

        _proposalSuppliers[positionId].push(msg.sender);

        emit SupplyProposalSubmitted(
            positionId,
            msg.sender,
            childId,
            childContract
        );
    }

    function payForSupplyRequest(
        bytes32 positionId,
        address supplier
    ) external payable nonReentrant {
        FGOMarketLibrary.SupplyRequestPosition
            storage position = _supplyPositions[positionId];
        FGOMarketLibrary.SupplierProposal storage proposal = _supplyProposals[
            positionId
        ][supplier];

        if (position.parentContract == address(0)) {
            revert FGOMarketErrors.InvalidPosition();
        }
        if (position.matched) {
            revert FGOMarketErrors.AlreadyMatched();
        }
        if (position.paid) {
            revert FGOMarketErrors.AlreadyPaid();
        }
        if (msg.sender != position.designer) {
            revert FGOMarketErrors.Unauthorized();
        }
        if (proposal.supplier == address(0)) {
            revert FGOMarketErrors.NoProposal();
        }

        IFGOChild childContractInterface = IFGOChild(proposal.childContract);
        IFGOParent parentInterface = IFGOParent(position.parentContract);

        FGOLibrary.ParentMetadata memory parentMetadata = parentInterface
            .getDesignTemplate(position.parentId);
        uint256 parentEditions = position.request.isPhysical
            ? parentMetadata.maxPhysicalEditions
            : parentMetadata.maxDigitalEditions;

        uint256 totalQuantity = position.request.quantity * parentEditions;

        childContractInterface.reserveSupplyForRequest(
            proposal.childId,
            positionId,
            totalQuantity,
            position.request.isPhysical
        );

        position.matched = true;
        position.matchedSupplier = supplier;
        position.matchedChildId = proposal.childId;
        position.matchedChildContract = proposal.childContract;

        FGOLibrary.ChildMetadata memory childMetadata = childContractInterface
            .getChildMetadata(proposal.childId);

        uint256 pricePerUnit = position.request.isPhysical
            ? childMetadata.physicalPrice
            : childMetadata.digitalPrice;
        uint256 totalPayment = pricePerUnit * totalQuantity;

        FGOAccessControl accessControl = parentInterface.accessControl();
        address paymentToken = accessControl.PAYMENT_TOKEN();

        if (paymentToken == address(0)) {
            if (msg.value != totalPayment) {
                revert FGOMarketErrors.IncorrectPayment();
            }
            (bool success, ) = supplier.call{value: totalPayment}("");
            if (!success) {
                revert FGOMarketErrors.PaymentFailed();
            }
        } else {
            IERC20(paymentToken).transferFrom(
                msg.sender,
                supplier,
                totalPayment
            );
        }

        childContractInterface.consumeReservedSupply(
            position.matchedChildId,
            positionId,
            position.request.isPhysical
        );

        parentInterface.updatePrepaidSupply(
            position.parentId,
            position.matchedChildContract,
            position.matchedChildId,
            position.request.quantity,
            totalQuantity,
            position.request.placementURI
        );

        bool needsPhysicalApproval = (parentMetadata.availability ==
            FGOLibrary.Availability.PHYSICAL_ONLY ||
            parentMetadata.availability == FGOLibrary.Availability.BOTH) &&
            (childMetadata.availability ==
                FGOLibrary.Availability.PHYSICAL_ONLY ||
                childMetadata.availability == FGOLibrary.Availability.BOTH);

        bool needsDigitalApproval = (parentMetadata.availability ==
            FGOLibrary.Availability.DIGITAL_ONLY ||
            parentMetadata.availability == FGOLibrary.Availability.BOTH) &&
            (childMetadata.availability ==
                FGOLibrary.Availability.DIGITAL_ONLY ||
                childMetadata.availability == FGOLibrary.Availability.BOTH);

        if (needsPhysicalApproval) {
            uint256 physicalQuantity = position.request.quantity * parentMetadata.maxPhysicalEditions;
            childContractInterface.approveParent(
                position.matchedChildId,
                position.parentId,
                physicalQuantity,
                position.parentContract,
                true
            );
        }

        if (needsDigitalApproval) {
            uint256 digitalQuantity = position.request.quantity * parentMetadata.maxDigitalEditions;
            childContractInterface.approveParent(
                position.matchedChildId,
                position.parentId,
                digitalQuantity,
                position.parentContract,
                false
            );
        }

        position.paid = true;
        position.fulfilled = true;

        emit SupplyRequestPaid(positionId, msg.sender, supplier, totalPayment);

        _checkAllRequestsFulfilled(position.parentId, position.parentContract);
    }

    function _checkAllRequestsFulfilled(
        uint256 parentId,
        address parentContract
    ) internal {
        bytes32[] memory positions = _parentPositions[parentId][parentContract];
        bool allFulfilled = true;

        for (uint256 i = 0; i < positions.length; ) {
            if (!_supplyPositions[positions[i]].fulfilled) {
                allFulfilled = false;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (allFulfilled) {
            IFGOParent(parentContract).updateStatusFromSupply(parentId);
        }
    }

    function getSupplyPosition(
        bytes32 positionId
    ) external view returns (FGOMarketLibrary.SupplyRequestPosition memory) {
        return _supplyPositions[positionId];
    }

    function getSupplierProposal(
        bytes32 positionId,
        address supplier
    ) external view returns (FGOMarketLibrary.SupplierProposal memory) {
        return _supplyProposals[positionId][supplier];
    }

    function getDesignerPositions(
        address designer
    ) external view returns (bytes32[] memory) {
        return _designerPositions[designer];
    }

    function getParentPositions(
        uint256 parentId,
        address parentContract
    ) external view returns (bytes32[] memory) {
        return _parentPositions[parentId][parentContract];
    }

    function getProposalSuppliers(
        bytes32 positionId
    ) external view returns (address[] memory) {
        return _proposalSuppliers[positionId];
    }

    function cancelProposal(bytes32 positionId) external nonReentrant {
        FGOMarketLibrary.SupplyRequestPosition
            storage position = _supplyPositions[positionId];
        FGOMarketLibrary.SupplierProposal storage proposal = _supplyProposals[
            positionId
        ][msg.sender];

        if (position.parentContract == address(0)) {
            revert FGOMarketErrors.InvalidPosition();
        }
        if (position.matched || position.paid) {
            revert FGOMarketErrors.AlreadyMatched();
        }
        if (proposal.supplier != msg.sender) {
            revert FGOMarketErrors.Unauthorized();
        }

        delete _supplyProposals[positionId][msg.sender];

        emit ProposalCancelled(positionId, msg.sender);
    }

    function releaseExpiredSupply(
        bytes32 positionId,
        address supplier
    ) external nonReentrant {
        FGOMarketLibrary.SupplyRequestPosition
            storage position = _supplyPositions[positionId];
        FGOMarketLibrary.SupplierProposal memory proposal = _supplyProposals[
            positionId
        ][supplier];

        if (position.parentContract == address(0)) {
            revert FGOMarketErrors.InvalidPosition();
        }
        if (position.matched || position.paid) {
            revert FGOMarketErrors.AlreadyMatched();
        }
        if (proposal.supplier == address(0)) {
            revert FGOMarketErrors.NoProposal();
        }

        if (block.timestamp <= position.request.deadline) {
            revert FGOMarketErrors.DeadlineNotPassed();
        }

        delete _supplyProposals[positionId][supplier];

        IFGOChild childContractInterface = IFGOChild(proposal.childContract);
        childContractInterface.releaseReservedSupply(
            proposal.childId,
            positionId
        );

        emit ExpiredSupplyReleased(positionId, supplier);
    }

    function releaseAllSupplyForParent(
        uint256 parentId,
        address parentContract
    ) external {
        if (msg.sender != parentContract) {
            revert FGOMarketErrors.Unauthorized();
        }

        bytes32[] memory positions = _parentPositions[parentId][parentContract];

        for (uint256 i = 0; i < positions.length; ) {
            FGOMarketLibrary.SupplyRequestPosition
                storage position = _supplyPositions[positions[i]];

            if (!position.paid) {
                address[] memory suppliers = _proposalSuppliers[positions[i]];
                for (uint256 j = 0; j < suppliers.length; ) {
                    FGOMarketLibrary.SupplierProposal
                        memory proposal = _supplyProposals[positions[i]][
                            suppliers[j]
                        ];
                    if (proposal.supplier != address(0)) {
                        try
                            IFGOChild(proposal.childContract)
                                .releaseReservedSupply(
                                    proposal.childId,
                                    positions[i]
                                )
                        {} catch {}
                        delete _supplyProposals[positions[i]][suppliers[j]];
                    }
                    unchecked {
                        ++j;
                    }
                }
                delete _proposalSuppliers[positions[i]];
                position.matched = true;
            }
            unchecked {
                ++i;
            }
        }

        emit ParentSupplyReleased(parentId, parentContract);
    }
}
