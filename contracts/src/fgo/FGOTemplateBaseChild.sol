// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOChild.sol";

abstract contract FGOTemplateBaseChild is FGOChild {
    mapping(uint256 => FGOLibrary.ChildReference[]) private _templatePlacements;

    event TemplateReserved(
        uint256 indexed templateId,
        address indexed supplier
    );

    constructor(
        uint256 childType,
        bytes32 infraId,
        address accessControl,
        string memory scm,
        string memory name,
        string memory symbol
    ) FGOChild(childType, infraId, accessControl, scm, name, symbol) {}

    function createChild(
        FGOLibrary.CreateChildParams memory
    ) external pure override returns (uint256) {
        revert FGOErrors.TemplateNotReserved();
    }

    function updateChild(
        FGOLibrary.UpdateChildParams memory
    ) external pure override {
        revert FGOErrors.TemplateNotReserved();
    }

    function deleteChild(uint256) external pure override {
        revert FGOErrors.TemplateNotReserved();
    }

    function createChildrenBatch(
        FGOLibrary.CreateChildParams[] memory
    ) external pure override returns (uint256[] memory) {
        revert FGOErrors.TemplateNotReserved();
    }

    function updateChildrenBatch(
        FGOLibrary.UpdateChildParams[] memory
    ) external pure override {
        revert FGOErrors.TemplateNotReserved();
    }

    function _createTemplateChildBaseWithId(
        uint256 templateId,
        FGOLibrary.CreateChildParams memory params
    ) internal {
        FGOLibrary.ChildMetadata storage child = _children[templateId];

        child.digitalPrice = params.digitalPrice;
        child.physicalPrice = params.physicalPrice;
        child.version = params.version;
        child.maxPhysicalFulfillments = params.maxPhysicalFulfillments;
        child.uriVersion = 1;
        child.isTemplate = true;
        child.standaloneAllowed = params.standaloneAllowed;
        child.supplier = msg.sender;
        child.status = FGOLibrary.Status.RESERVED;
        child.availability = params.availability;
        child.isImmutable = params.isImmutable;
        child.digitalOpenToAll = params.digitalOpenToAll;
        child.physicalOpenToAll = params.physicalOpenToAll;
        child.digitalReferencesOpenToAll = true;
        child.physicalReferencesOpenToAll = true;
        child.uri = params.childUri;
    }

    function reserveTemplate(
        FGOLibrary.CreateChildParams memory params,
        FGOLibrary.ChildReference[] memory placements
    ) external onlySupplier returns (uint256) {
        if (placements.length == 0) {
            revert FGOErrors.EmptyArray();
        }
        if (placements.length > 50) {
            revert FGOErrors.BatchTooLarge();
        }
        if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
            revert FGOErrors.BatchTooLarge();
        }

        _childSupply++;

        _createTemplateChildBaseWithId(_childSupply, params);

        bool allChildrenApproved = true;

        uint256 placementsLength = placements.length;
        for (uint256 i = 0; i < placementsLength; ) {
            FGOLibrary.ChildReference memory placement = placements[i];

            _checkChildActive(placement);

            if (
                !_checkTemplateApproval(
                    placement.childId,
                    _childSupply,
                    placement.childContract,
                    params.availability
                )
            ) {
                _requestTemplateApproval(
                    placement.childId,
                    _childSupply,
                    placement.amount,
                    placement.childContract
                );
                allChildrenApproved = false;
            }

            _templatePlacements[_childSupply].push(placement);

            unchecked {
                ++i;
            }
        }

        _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

        emit TemplateReserved(_childSupply, msg.sender);

        if (allChildrenApproved) {
            _children[_childSupply].status = FGOLibrary.Status.ACTIVE;
            emit ChildCreated(_childSupply, msg.sender);
        }

        return _childSupply;
    }

    function createTemplate(
        uint256 reservedTemplateId
    ) external onlySupplier nonReentrant {
        FGOLibrary.ChildMetadata storage child = _children[reservedTemplateId];

        if (child.supplier != msg.sender) {
            revert FGOErrors.Unauthorized();
        }
        if (child.status != FGOLibrary.Status.RESERVED) {
            revert FGOErrors.TemplateNotReserved();
        }

        for (
            uint256 i = 0;
            i < _templatePlacements[reservedTemplateId].length;

        ) {
            FGOLibrary.ChildReference memory placement = _templatePlacements[
                reservedTemplateId
            ][i];

            _checkChildActive(placement);
            if (
                !_checkTemplateApproval(
                    placement.childId,
                    reservedTemplateId,
                    placement.childContract,
                    child.availability
                )
            ) {
                revert FGOErrors.ChildNotAuthorized();
            }

            unchecked {
                ++i;
            }
        }

        _children[reservedTemplateId].status = FGOLibrary.Status.ACTIVE;

        emit ChildCreated(reservedTemplateId, msg.sender);
    }

    function updateTemplate(
        FGOLibrary.UpdateChildParams memory params,
        FGOLibrary.ChildReference[] memory placements
    ) external onlyChildOwner(params.childId) nonReentrant {
        _updateChild(params);

        if (!_children[params.childId].isImmutable) {
            delete _templatePlacements[params.childId];

            uint256 placementsLength = placements.length;
            for (uint256 i = 0; i < placementsLength; ) {
                _checkChildActive(placements[i]);
                _templatePlacements[params.childId].push(placements[i]);
                unchecked {
                    ++i;
                }
            }
        }
    }

    function updateTemplateBatch(
        FGOLibrary.UpdateChildParams[] memory paramsArray,
        FGOLibrary.ChildReference[][] memory placementsArray
    ) external nonReentrant {
        uint256 len = paramsArray.length;
        if (len == 0 || len != placementsArray.length) {
            revert FGOErrors.ArrayLengthMismatch();
        }
        if (len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        for (uint256 j = 0; j < len; ) {
            FGOLibrary.UpdateChildParams memory params = paramsArray[j];
            FGOLibrary.ChildReference[] memory placements = placementsArray[j];

            if (_children[params.childId].supplier != msg.sender) {
                revert FGOErrors.Unauthorized();
            }

            _updateChild(params);

            if (!_children[params.childId].isImmutable) {
                delete _templatePlacements[params.childId];

                uint256 placementsLength = placements.length;
                for (uint256 i = 0; i < placementsLength; ) {
                    _checkChildActive(placements[i]);
                    _templatePlacements[params.childId].push(placements[i]);
                    unchecked {
                        ++i;
                    }
                }
            }
            unchecked {
                ++j;
            }
        }
    }

    function getTemplatePlacements(
        uint256 childId
    ) external view returns (FGOLibrary.ChildReference[] memory) {
        return _templatePlacements[childId];
    }

    function _checkChildActive(
        FGOLibrary.ChildReference memory placement
    ) internal view {
        if (placement.childContract == address(0)) {
            revert FGOErrors.Unauthorized();
        }
        if (placement.amount == 0) {
            revert FGOErrors.ZeroValue();
        }
        if (bytes(placement.placementURI).length == 0) {
            revert FGOErrors.EmptyPlacementURI();
        }

        try
            FGOChild(placement.childContract).childExists(placement.childId)
        returns (bool exists) {
            if (!exists) {
                revert FGOErrors.ChildDoesNotExist();
            }
        } catch {
            revert FGOErrors.Unauthorized();
        }

        try
            FGOChild(placement.childContract).isChildActive(placement.childId)
        returns (bool childActive) {
            if (!childActive) {
                revert FGOErrors.ChildNotAuthorized();
            }
        } catch {
            revert FGOErrors.ChildNotAuthorized();
        }
    }

    function _requestTemplateApproval(
        uint256 childId,
        uint256 templateId,
        uint256 requestedAmount,
        address childContract
    ) internal {
        try
            FGOChild(childContract).requestTemplateApproval(
                childId,
                templateId,
                requestedAmount
            )
        {} catch {
            revert FGOErrors.ChildNotAuthorized();
        }
    }

    function _checkTemplateApproval(
        uint256 childId,
        uint256 templateId,
        address childContract,
        FGOLibrary.Availability availability
    ) internal view returns (bool) {
        if (availability == FGOLibrary.Availability.DIGITAL_ONLY) {
            try
                FGOChild(childContract).approvesTemplate(
                    childId,
                    templateId,
                    address(this),
                    false
                )
            returns (bool childApproves) {
                return childApproves;
            } catch {
                return false;
            }
        } else if (availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
            try
                FGOChild(childContract).approvesTemplate(
                    childId,
                    templateId,
                    address(this),
                    true
                )
            returns (bool childApproves) {
                return childApproves;
            } catch {
                return false;
            }
        } else if (availability == FGOLibrary.Availability.BOTH) {
            bool digitalApproves = false;
            bool physicalApproves = false;

            try
                FGOChild(childContract).approvesTemplate(
                    childId,
                    templateId,
                    address(this),
                    false
                )
            returns (bool childApproves) {
                digitalApproves = childApproves;
            } catch {
                digitalApproves = false;
            }

            try
                FGOChild(childContract).approvesTemplate(
                    childId,
                    templateId,
                    address(this),
                    true
                )
            returns (bool childApproves) {
                physicalApproves = childApproves;
            } catch {
                physicalApproves = false;
            }

            return digitalApproves && physicalApproves;
        }

        return false;
    }

    function reserveTemplateBatch(
        FGOLibrary.CreateChildParams[] memory paramsArray,
        FGOLibrary.ChildReference[][] memory placementsArray
    ) external onlySupplier returns (uint256[] memory) {
        uint256 len = paramsArray.length;
        if (len == 0 || len > 20) {
            revert FGOErrors.BatchTooLarge();
        }
        if (len != placementsArray.length) {
            revert FGOErrors.ArrayLengthMismatch();
        }

        uint256[] memory reservedIds = new uint256[](len);

        for (uint256 j = 0; j < len; ) {
            FGOLibrary.CreateChildParams memory params = paramsArray[j];
            FGOLibrary.ChildReference[] memory placements = placementsArray[j];

            if (placements.length == 0 || placements.length > 50) {
                revert FGOErrors.BatchTooLarge();
            }
            if (params.authorizedMarkets.length >= MAX_AUTHORIZED_ADDRESSES) {
                revert FGOErrors.BatchTooLarge();
            }

            _childSupply++;
            uint256 templateId = _childSupply;

            _createTemplateChildBaseWithId(templateId, params);

            bool allChildrenApproved = true;
            uint256 placementsLength = placements.length;
            for (uint256 i = 0; i < placementsLength; ) {
                FGOLibrary.ChildReference memory placement = placements[i];

                _checkChildActive(placement);

                if (
                    !_checkTemplateApproval(
                        placement.childId,
                        templateId,
                        placement.childContract,
                        params.availability
                    )
                ) {
                    _requestTemplateApproval(
                        placement.childId,
                        templateId,
                        placement.amount,
                        placement.childContract
                    );
                    allChildrenApproved = false;
                }

                _templatePlacements[templateId].push(placement);

                unchecked {
                    ++i;
                }
            }

            _setAuthorizedMarkets(templateId, params.authorizedMarkets);

            reservedIds[j] = templateId;

            if (allChildrenApproved) {
                _children[templateId].status = FGOLibrary.Status.ACTIVE;
                emit ChildCreated(templateId, msg.sender);
            } else {
                emit TemplateReserved(templateId, msg.sender);
            }
            unchecked {
                ++j;
            }
        }

        return reservedIds;
    }

    function createTemplateBatch(
        uint256[] memory reservedTemplateIds
    ) external onlySupplier nonReentrant returns (uint256[] memory) {
        uint256 len = reservedTemplateIds.length;
        if (len == 0 || len > 20) {
            revert FGOErrors.BatchTooLarge();
        }

        uint256[] memory createdIds = new uint256[](len);

        for (uint256 j = 0; j < len; ) {
            uint256 reservedTemplateId = reservedTemplateIds[j];
            FGOLibrary.ChildMetadata storage child = _children[
                reservedTemplateId
            ];

            if (child.supplier != msg.sender) {
                revert FGOErrors.Unauthorized();
            }
            if (child.status != FGOLibrary.Status.RESERVED) {
                revert FGOErrors.TemplateNotReserved();
            }

            for (
                uint256 i = 0;
                i < _templatePlacements[reservedTemplateId].length;

            ) {
                FGOLibrary.ChildReference
                    memory placement = _templatePlacements[reservedTemplateId][
                        i
                    ];

                _checkChildActive(placement);
                if (
                    !_checkTemplateApproval(
                        placement.childId,
                        reservedTemplateId,
                        placement.childContract,
                        _children[reservedTemplateId].availability
                    )
                ) {
                    revert FGOErrors.ChildNotAuthorized();
                }

                unchecked {
                    ++i;
                }
            }

            _children[reservedTemplateId].status = FGOLibrary.Status.ACTIVE;

            createdIds[j] = reservedTemplateId;
            emit ChildCreated(reservedTemplateId, msg.sender);
            unchecked {
                ++j;
            }
        }

        return createdIds;
    }

    function deleteTemplate(uint256 childId) external onlyChildOwner(childId) {
        FGOLibrary.ChildMetadata storage child = _children[childId];

        if (child.supplyCount > 0) {
            revert FGOErrors.HasSupply();
        }
        if (child.usageCount > 0) {
            revert FGOErrors.HasUsage();
        }

        address[] memory authorizedMarkets = child.authorizedMarkets;
        uint256 marketsLength = authorizedMarkets.length;
        for (uint256 i = 0; i < marketsLength; ) {
            delete _authorizedMarkets[childId][authorizedMarkets[i]];
            delete _marketRequests[childId][authorizedMarkets[i]];
            unchecked {
                ++i;
            }
        }

        delete _templatePlacements[childId];
        delete _children[childId];

        emit ChildDeleted(childId);
    }
}
