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
        child.maxPhysicalEditions = params.maxPhysicalEditions;
        child.uriVersion = 1;
        child.isTemplate = true;
        child.standaloneAllowed = params.standaloneAllowed;
        child.supplier = msg.sender;
        child.status = FGOLibrary.Status.RESERVED;
        child.availability = params.availability;
        child.isImmutable = params.isImmutable;
        child.digitalMarketsOpenToAll = params.digitalMarketsOpenToAll;
        child.physicalMarketsOpenToAll = params.physicalMarketsOpenToAll;
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

        uint256 placementsLength = placements.length;
        for (uint256 i = 0; i < placementsLength; ) {
            _checkChildActive(placements[i]);
            _templatePlacements[_childSupply].push(placements[i]);
            unchecked {
                ++i;
            }
        }


        bool allChildrenApproved = false;
        if (params.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
            allChildrenApproved = _validateTemplateReferencesRecursive(
                placements,
                _childSupply,
                true
            );
        } else if (
            params.availability == FGOLibrary.Availability.DIGITAL_ONLY
        ) {
            allChildrenApproved = _validateTemplateReferencesRecursive(
                placements,
                _childSupply,
                false
            );
        } else {
            allChildrenApproved =
                _validateTemplateReferencesRecursive(
                    placements,
                    _childSupply,
                    true
                ) &&
                _validateTemplateReferencesRecursive(
                    placements,
                    _childSupply,
                    false
                );
        }

        _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

        if (allChildrenApproved) {
            _children[_childSupply].status = FGOLibrary.Status.ACTIVE;
            emit ChildCreated(_childSupply, msg.sender);
        } else {
            _requestNestedTemplateApprovals(
                placements,
                _childSupply,
                address(this)
            );
        }
        emit TemplateReserved(_childSupply, msg.sender);

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

        FGOLibrary.ChildReference[]
            memory templatePlacements = _templatePlacements[reservedTemplateId];

        bool allApproved = false;
        if (child.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
            allApproved = _validateTemplateReferencesRecursive(
                templatePlacements,
                reservedTemplateId,
                true
            );
        } else if (child.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
            allApproved = _validateTemplateReferencesRecursive(
                templatePlacements,
                reservedTemplateId,
                false
            );
        } else {
            allApproved =
                _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    true
                ) &&
                _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    false
                );
        }

        if (!allApproved) {
            revert FGOErrors.ChildNotAuthorized();
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

            uint256 placementsLength = placements.length;
            for (uint256 i = 0; i < placementsLength; ) {
                _checkChildActive(placements[i]);
                _templatePlacements[_childSupply].push(placements[i]);
                unchecked {
                    ++i;
                }
            }

            bool allChildrenApproved = false;
            if (params.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                allChildrenApproved = _validateTemplateReferencesRecursive(
                    placements,
                    _childSupply,
                    true
                );
            } else if (
                params.availability == FGOLibrary.Availability.DIGITAL_ONLY
            ) {
                allChildrenApproved = _validateTemplateReferencesRecursive(
                    placements,
                    _childSupply,
                    false
                );
            } else {
                allChildrenApproved =
                    _validateTemplateReferencesRecursive(
                        placements,
                        _childSupply,
                        true
                    ) &&
                    _validateTemplateReferencesRecursive(
                        placements,
                        _childSupply,
                        false
                    );
            }

            _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

            if (allChildrenApproved) {
                _children[_childSupply].status = FGOLibrary.Status.ACTIVE;
                emit ChildCreated(_childSupply, msg.sender);
            } else {
                _requestNestedTemplateApprovals(
                    placements,
                    _childSupply,
                    address(this)
                );
            }
            emit TemplateReserved(_childSupply, msg.sender);

            reservedIds[j] = _childSupply;
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

            FGOLibrary.ChildReference[]
                memory templatePlacements = _templatePlacements[reservedTemplateId];

            bool allApproved = false;
            if (child.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                allApproved = _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    true
                );
            } else if (child.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
                allApproved = _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    false
                );
            } else {
                allApproved =
                    _validateTemplateReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        true
                    ) &&
                    _validateTemplateReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        false
                    );
            }

            if (!allApproved) {
                revert FGOErrors.ChildNotAuthorized();
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

    function canPurchase(
        uint256 templateId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view override returns (bool) {
        FGOLibrary.ChildMetadata storage template = _children[templateId];

        if (template.status != FGOLibrary.Status.ACTIVE) {
            return false;
        }

        if (!template.standaloneAllowed) {
            return false;
        }

        bool templateApproves = _authorizedMarkets[templateId][market];

        if (!templateApproves) {
            if (isPhysical && template.physicalMarketsOpenToAll) {
                templateApproves = true;
            } else if (!isPhysical && template.digitalMarketsOpenToAll) {
                templateApproves = true;
            }
        }

        if (!templateApproves) {
            return false;
        }

        if (
            isPhysical &&
            template.availability == FGOLibrary.Availability.DIGITAL_ONLY
        ) {
            return false;
        }
        if (
            !isPhysical &&
            template.availability == FGOLibrary.Availability.PHYSICAL_ONLY
        ) {
            return false;
        }

        if (isPhysical) {
            if (
                template.maxPhysicalEditions > 0 &&
                template.currentPhysicalEditions + amount >
                template.maxPhysicalEditions
            ) {
                return false;
            }
        }

        FGOLibrary.ChildReference[]
            storage templateReferences = _templatePlacements[templateId];

        return
            _validateChildReferencesRecursive(
                templateReferences,
                templateId,
                market,
                isPhysical,
                amount,
                false
            );
    }

    function _validateChildReferencesRecursive(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentDesignId,
        address market,
        bool isPhysical,
        uint256 parentAmount,
        bool skipMarketChecks
    ) internal view returns (bool) {
        uint256 referencesLength = childReferences.length;
        for (uint256 i = 0; i < referencesLength; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            try
                IFGOChild(childRef.childContract).isChildActive(
                    childRef.childId
                )
            returns (bool childActive) {
                if (!childActive) {
                    return false;
                }
            } catch {
                return false;
            }

            try
                IFGOChild(childRef.childContract).approvesParent(
                    childRef.childId,
                    parentDesignId,
                    address(this),
                    isPhysical
                )
            returns (bool childApprovesParent) {
                if (!childApprovesParent) {
                    return false;
                }
            } catch {
                return false;
            }

            if (!skipMarketChecks && market != address(0)) {
                try
                    IFGOChild(childRef.childContract).approvesMarket(
                        childRef.childId,
                        market,
                        isPhysical
                    )
                returns (bool childApprovesMarket) {
                    if (!childApprovesMarket) {
                        return false;
                    }
                } catch {
                    return false;
                }
            }

            uint256 totalAmount = childRef.amount * parentAmount;
            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                FGOLibrary.ChildMetadata storage template = _children[parentDesignId];
                
                if (template.availability != FGOLibrary.Availability.BOTH) {
                    if (
                        isPhysical &&
                        child.availability == FGOLibrary.Availability.DIGITAL_ONLY
                    ) {
                        return false;
                    }
                    if (
                        !isPhysical &&
                        child.availability == FGOLibrary.Availability.PHYSICAL_ONLY
                    ) {
                        return false;
                    }
                }

                if (isPhysical && child.maxPhysicalEditions > 0) {
                    if (
                        child.currentPhysicalEditions + totalAmount >
                        child.maxPhysicalEditions
                    ) {
                        return false;
                    }
                }

                if (child.isTemplate) {
                    try
                        IFGOChild(childRef.childContract).approvesParent(
                            childRef.childId,
                            parentDesignId,
                            address(this),
                            isPhysical
                        )
                    returns (bool templateApprovesParent) {
                        if (!templateApprovesParent) {
                            return false;
                        }
                    } catch {
                        return false;
                    }

                    if (isPhysical && child.maxPhysicalEditions > 0) {
                        if (
                            child.currentPhysicalEditions + totalAmount >
                            child.maxPhysicalEditions
                        ) {
                            return false;
                        }
                    }

                    try
                        IFGOTemplate(childRef.childContract)
                            .getTemplatePlacements(childRef.childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        if (
                            !_validateChildReferencesRecursive(
                                templatePlacements,
                                parentDesignId,
                                market,
                                isPhysical,
                                totalAmount,
                                skipMarketChecks
                            )
                        ) {
                            return false;
                        }
                    } catch {
                        return false;
                    }
                }
            } catch {
                return false;
            }

            unchecked {
                ++i;
            }
        }

        return true;
    }

    function _validateTemplateReferencesRecursive(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 templateId,
        bool isPhysical
    ) internal view returns (bool) {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            try
                IFGOChild(childRef.childContract).isChildActive(
                    childRef.childId
                )
            returns (bool childActive) {
                if (!childActive) {
                    return false;
                }
            } catch {
                return false;
            }

            try
                IFGOChild(childRef.childContract).approvesTemplate(
                    childRef.childId,
                    templateId,
                    address(this),
                    isPhysical
                )
            returns (bool childApprovesTemplate) {
                if (!childApprovesTemplate) {
                    return false;
                }
            } catch {
                return false;
            }

            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                FGOLibrary.ChildMetadata storage template = _children[templateId];
                
                if (template.availability != FGOLibrary.Availability.BOTH) {
                    if (
                        isPhysical &&
                        child.availability == FGOLibrary.Availability.DIGITAL_ONLY
                    ) {
                        return false;
                    }
                    if (
                        !isPhysical &&
                        child.availability == FGOLibrary.Availability.PHYSICAL_ONLY
                    ) {
                        return false;
                    }
                }

                if (child.isTemplate) {
                    try
                        IFGOTemplate(childRef.childContract)
                            .getTemplatePlacements(childRef.childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        if (
                            !_validateTemplateReferencesRecursive(
                                templatePlacements,
                                templateId,
                                isPhysical
                            )
                        ) {
                            return false;
                        }
                    } catch {
                        return false;
                    }
                }
            } catch {
                return false;
            }

            unchecked {
                ++i;
            }
        }

        return true;
    }

    function requestParentApproval(
        uint256 childId,
        uint256 parentId,
        uint256 requestedAmount
    ) external override {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.ParentApprovalRequest storage request = _parentRequests[
            childId
        ][msg.sender][parentId];
        request.parentContract = msg.sender;
        request.childId = childId;
        request.parentId = parentId;
        request.requestedAmount = requestedAmount;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit ParentApprovalRequested(
            childId,
            parentId,
            requestedAmount,
            msg.sender
        );

        FGOLibrary.ChildReference[]
            storage templatePlacements = _templatePlacements[childId];
        _requestNestedParentApprovals(templatePlacements, parentId, msg.sender);
    }

    function _requestNestedParentApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentId,
        address parentContract
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            try
                IFGOChild(childRef.childContract).requestParentApproval(
                    childRef.childId,
                    parentId,
                    childRef.amount
                )
            {} catch {}

            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                if (child.isTemplate) {
                    try
                        IFGOTemplate(childRef.childContract)
                            .getTemplatePlacements(childRef.childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        _requestNestedParentApprovals(
                            templatePlacements,
                            parentId,
                            parentContract
                        );
                    } catch {}
                }
            } catch {}

            unchecked {
                ++i;
            }
        }
    }

    function requestTemplateApproval(
        uint256 childId,
        uint256 templateId,
        uint256 requestedAmount
    ) external override {
        if (!childExists(childId)) {
            revert FGOErrors.ChildDoesNotExist();
        }

        FGOLibrary.TemplateApprovalRequest storage request = _templateRequests[
            childId
        ][msg.sender][templateId];
        request.templateContract = msg.sender;
        request.childId = childId;
        request.templateId = templateId;
        request.requestedAmount = requestedAmount;
        request.timestamp = block.timestamp;
        request.isPending = true;

        emit TemplateApprovalRequested(
            childId,
            templateId,
            requestedAmount,
            msg.sender
        );

        try IFGOChild(msg.sender).getChildMetadata(templateId) returns (
            FGOLibrary.ChildMetadata memory child
        ) {
            if (child.isTemplate) {
                try
                    IFGOTemplate(msg.sender).getTemplatePlacements(templateId)
                returns (
                    FGOLibrary.ChildReference[] memory templatePlacements
                ) {
                    _requestNestedTemplateApprovals(
                        templatePlacements,
                        templateId,
                        msg.sender
                    );
                } catch {}
            }
        } catch {}
    }

    function _requestNestedTemplateApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 templateId,
        address templateContract
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            try
                IFGOChild(childRef.childContract).requestTemplateApproval(
                    childRef.childId,
                    templateId,
                    childRef.amount
                )
            {} catch {}

            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                if (child.isTemplate) {
                    try
                        IFGOTemplate(childRef.childContract)
                            .getTemplatePlacements(childRef.childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        _requestNestedTemplateApprovals(
                            templatePlacements,
                            templateId,
                            templateContract
                        );
                    } catch {}
                }
            } catch {}

            unchecked {
                ++i;
            }
        }
    }
}
