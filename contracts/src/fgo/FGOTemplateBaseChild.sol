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
        address supplyCoordination,
        string memory scm,
        string memory name,
        string memory symbol
    )
        FGOChild(
            childType,
            infraId,
            accessControl,
            supplyCoordination,
            scm,
            name,
            symbol
        )
    {}

    function createChild(
        FGOLibrary.CreateChildParams memory
    ) external pure override returns (uint256) {
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

    function _createTemplateChildBaseWithId(
        uint256 templateId,
        FGOLibrary.CreateChildParams memory params
    ) internal {
        FGOLibrary.ChildMetadata storage child = _children[templateId];

        if (
            params.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            child.digitalPrice = params.digitalPrice;
        }

        if (
            params.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            child.maxPhysicalEditions = params.maxPhysicalEditions;
            child.physicalPrice = params.physicalPrice;
        }

        child.digitalMarketsOpenToAll = params.digitalMarketsOpenToAll;
        child.physicalMarketsOpenToAll = params.physicalMarketsOpenToAll;

        child.digitalReferencesOpenToAll = params.digitalReferencesOpenToAll;
        child.physicalReferencesOpenToAll = params.physicalReferencesOpenToAll;

        child.version = params.version;
        child.uriVersion = 1;
        child.isTemplate = true;
        child.standaloneAllowed = params.standaloneAllowed;
        child.supplier = msg.sender;
        child.status = FGOLibrary.Status.RESERVED;
        child.availability = params.availability;
        child.isImmutable = params.isImmutable;
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
            _checkChildActive(placements[i], false);
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
            _incrementUsageForChildren(_childSupply, placements);
            emit ChildCreated(_childSupply, msg.sender);
        } else {
            _requestNestedTemplateApprovals(placements, _childSupply);
        }
        emit TemplateReserved(_childSupply, msg.sender);
        emit URI(params.childUri, _childSupply);

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
        _incrementUsageForChildren(reservedTemplateId, templatePlacements);

        emit ChildCreated(reservedTemplateId, msg.sender);
    }

    function getTemplatePlacements(
        uint256 childId
    ) external view returns (FGOLibrary.ChildReference[] memory) {
        return _templatePlacements[childId];
    }

    function _checkChildActive(
        FGOLibrary.ChildReference memory placement,
        bool requireActive
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

        if (requireActive) {
            try
                FGOChild(placement.childContract).isChildActive(
                    placement.childId
                )
            returns (bool childActive) {
                if (!childActive) {
                    revert FGOErrors.ChildNotAuthorized();
                }
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }
        }
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
                _checkChildActive(placements[i], false);
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
                _incrementUsageForChildren(_childSupply, placements);
                emit ChildCreated(_childSupply, msg.sender);
            } else {
                _requestNestedTemplateApprovals(placements, _childSupply);
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
                memory templatePlacements = _templatePlacements[
                    reservedTemplateId
                ];

            bool allApproved = false;
            if (child.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                allApproved = _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    true
                );
            } else if (
                child.availability == FGOLibrary.Availability.DIGITAL_ONLY
            ) {
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
            _incrementUsageForChildren(reservedTemplateId, templatePlacements);

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

        if (child.status == FGOLibrary.Status.ACTIVE) {
            _decrementUsageForChildren(childId, _templatePlacements[childId]);
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

        bool templateApproves = _authorizedMarkets[templateId][market] > 0;

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
        FGOLibrary.DemandEntry[] memory demands = new FGOLibrary.DemandEntry[](
            0
        );
        demands = _calculateCumulativeDemand(
            childReferences,
            parentAmount,
            isPhysical,
            demands
        );

        return
            _validateCumulativeDemandAndApprovals(
                demands,
                parentDesignId,
                market,
                isPhysical,
                skipMarketChecks
            );
    }

    function _calculateCumulativeDemand(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 parentAmount,
        bool isPhysical,
        FGOLibrary.DemandEntry[] memory demands
    ) internal view returns (FGOLibrary.DemandEntry[] memory) {
        uint256 referencesLength = childReferences.length;
        for (uint256 i = 0; i < referencesLength; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];
            uint256 totalAmount = childRef.amount * parentAmount;

            demands = _addToDemands(
                demands,
                childRef.childContract,
                childRef.childId,
                totalAmount
            );

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
                        demands = _calculateCumulativeDemand(
                            templatePlacements,
                            totalAmount,
                            isPhysical,
                            demands
                        );
                    } catch {}
                }
            } catch {}

            unchecked {
                ++i;
            }
        }
        return demands;
    }

    function _addToDemands(
        FGOLibrary.DemandEntry[] memory demands,
        address contractAddr,
        uint256 childId,
        uint256 amount
    ) internal pure returns (FGOLibrary.DemandEntry[] memory) {
        for (uint256 i = 0; i < demands.length; ) {
            if (
                demands[i].childContract == contractAddr &&
                demands[i].childId == childId
            ) {
                demands[i].cumulativeDemand += amount;
                return demands;
            }
            unchecked {
                ++i;
            }
        }

        FGOLibrary.DemandEntry[]
            memory newDemands = new FGOLibrary.DemandEntry[](
                demands.length + 1
            );
        for (uint256 i = 0; i < demands.length; ) {
            newDemands[i] = demands[i];
            unchecked {
                ++i;
            }
        }
        newDemands[demands.length] = FGOLibrary.DemandEntry({
            childContract: contractAddr,
            childId: childId,
            cumulativeDemand: amount
        });

        return newDemands;
    }

    function _validateCumulativeDemandAndApprovals(
        FGOLibrary.DemandEntry[] memory demands,
        uint256 parentDesignId,
        address market,
        bool isPhysical,
        bool skipMarketChecks
    ) internal view returns (bool) {
        for (uint256 i = 0; i < demands.length; ) {
            FGOLibrary.DemandEntry memory demand = demands[i];

            try
                IFGOChild(demand.childContract).isChildActive(demand.childId)
            returns (bool childActive) {
                if (!childActive) {
                    return false;
                }
            } catch {
                return false;
            }

            try
                IFGOChild(demand.childContract).approvesParent(
                    demand.childId,
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
                    IFGOChild(demand.childContract).approvesMarket(
                        demand.childId,
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

            try
                IFGOChild(demand.childContract).getChildMetadata(demand.childId)
            returns (FGOLibrary.ChildMetadata memory child) {
                FGOLibrary.ChildMetadata storage template = _children[
                    parentDesignId
                ];

                if (template.availability != FGOLibrary.Availability.BOTH) {
                    if (
                        isPhysical &&
                        child.availability ==
                        FGOLibrary.Availability.DIGITAL_ONLY
                    ) {
                        return false;
                    }
                    if (
                        !isPhysical &&
                        child.availability ==
                        FGOLibrary.Availability.PHYSICAL_ONLY
                    ) {
                        return false;
                    }
                }

                if (isPhysical && child.maxPhysicalEditions > 0) {
                    if (
                        child.currentPhysicalEditions +
                            demand.cumulativeDemand >
                        child.maxPhysicalEditions
                    ) {
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
                FGOLibrary.ChildMetadata storage template = _children[
                    templateId
                ];

                if (template.availability != FGOLibrary.Availability.BOTH) {
                    if (
                        isPhysical &&
                        child.availability ==
                        FGOLibrary.Availability.DIGITAL_ONLY
                    ) {
                        return false;
                    }
                    if (
                        !isPhysical &&
                        child.availability ==
                        FGOLibrary.Availability.PHYSICAL_ONLY
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

    function _requestNestedTemplateApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 templateId
    ) internal {
        FGOLibrary.ChildMetadata storage templateMetadata = _children[templateId];

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            if (templateMetadata.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                templateMetadata.availability == FGOLibrary.Availability.BOTH) {
                uint256 physicalAmount = templateMetadata.maxPhysicalEditions > 0 ?
                    childRef.amount * templateMetadata.maxPhysicalEditions :
                    type(uint256).max;
                try
                    IFGOChild(childRef.childContract).requestTemplateApproval(
                        childRef.childId,
                        templateId,
                        physicalAmount,
                        true
                    )
                {} catch {
                    revert FGOErrors.CatchBlock();
                }
            }

            if (templateMetadata.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
                templateMetadata.availability == FGOLibrary.Availability.BOTH) {
                try
                    IFGOChild(childRef.childContract).requestTemplateApproval(
                        childRef.childId,
                        templateId,
                        type(uint256).max,
                        false
                    )
                {} catch {
                    revert FGOErrors.CatchBlock();
                }
            }

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
                            templateId
                        );
                    } catch {
                        revert FGOErrors.CatchBlock();
                    }
                }
            } catch {
                revert FGOErrors.CatchBlock();
            }

            unchecked {
                ++i;
            }
        }
    }

    function _incrementUsageForChildren(
        uint256 templateId,
        FGOLibrary.ChildReference[] memory childReferences
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            try
                IFGOChild(childReferences[i].childContract).incrementChildUsage(
                    childReferences[i].childId,
                    templateId,
                    childReferences[i].amount,
                    true
                )
            {} catch {
                revert FGOErrors.CatchBlock();
            }
            unchecked {
                ++i;
            }
        }
    }

    function _decrementUsageForChildren(
        uint256 templateId,
        FGOLibrary.ChildReference[] memory childReferences
    ) internal {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            try
                IFGOChild(childReferences[i].childContract).decrementChildUsage(
                    childReferences[i].childId,
                    templateId
                )
            {} catch {
                revert FGOErrors.CatchBlock();
            }
            unchecked {
                ++i;
            }
        }
    }
}
