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
        address futuresCoordination,
        address factory,
        string memory scm,
        string memory name,
        string memory symbol
    )
        FGOChild(
            childType,
            infraId,
            accessControl,
            supplyCoordination,
            futuresCoordination,
            factory,
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
        FGOLibrary.CreateChildParams memory params,
        FGOLibrary.ChildReference[] memory placements
    ) internal {
        FGOLibrary.ChildMetadata storage child = _children[templateId];

        if (
            params.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            child.digitalPrice = params.digitalPrice;

            bool hasFuturesOrPrepaid = _hasFuturesOrPrepaidChildren(
                placements,
                params.availability
            );

            if (hasFuturesOrPrepaid) {
                if (params.maxDigitalEditions == 0) {
                    revert FGOErrors.DigitalLimitRequired();
                }
                child.maxDigitalEditions = params.maxDigitalEditions;
            } else {
                child.maxDigitalEditions = 0;
            }
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

        _createTemplateChildBaseWithId(_childSupply, params, placements);

        if (
            params.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            _validateUnlimitedPhysicalPropagation(
                params.maxPhysicalEditions,
                placements
            );
        }

        if (
            params.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
            params.availability == FGOLibrary.Availability.BOTH
        ) {
            _validateUnlimitedDigitalPropagation(
                params.maxDigitalEditions,
                placements
            );
        }

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
            allChildrenApproved =
                _validateTemplateReferencesRecursive(
                    placements,
                    _childSupply,
                    true
                ) &&
                _validateChildReferencesRecursive(
                    placements,
                    _childSupply,
                    address(0),
                    true,
                    params.maxPhysicalEditions > 0
                        ? params.maxPhysicalEditions
                        : 1,
                    true
                );
        } else if (
            params.availability == FGOLibrary.Availability.DIGITAL_ONLY
        ) {
            allChildrenApproved =
                _validateTemplateReferencesRecursive(
                    placements,
                    _childSupply,
                    false
                ) &&
                _validateChildReferencesRecursive(
                    placements,
                    _childSupply,
                    address(0),
                    false,
                    1,
                    true
                );
        } else {
            bool physicalTemplateValidation = _validateTemplateReferencesRecursive(
                    placements,
                    _childSupply,
                    true
                );

            bool physicalChildValidation = _validateChildReferencesRecursive(
                placements,
                _childSupply,
                address(0),
                true,
                params.maxPhysicalEditions > 0 ? params.maxPhysicalEditions : 1,
                true
            );

            bool digitalTemplateValidation = _validateTemplateReferencesRecursive(
                    placements,
                    _childSupply,
                    false
                );

            bool digitalChildValidation = _validateChildReferencesRecursive(
                placements,
                _childSupply,
                address(0),
                false,
                1,
                true
            );

            allChildrenApproved =
                physicalTemplateValidation &&
                physicalChildValidation &&
                digitalTemplateValidation &&
                digitalChildValidation;
        }

        _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

        if (allChildrenApproved) {
            _consumeFuturesCreditsForTemplate(
                _childSupply,
                placements,
                params.maxPhysicalEditions,
                params.maxDigitalEditions
            );
            _children[_childSupply].status = FGOLibrary.Status.ACTIVE;
            _incrementUsageForChildren(_childSupply, placements);
            emit ChildCreated(_childSupply, msg.sender);
        } else {
            _requestNestedTemplateApprovals(placements, _childSupply, false);
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
            allApproved =
                _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    true
                ) &&
                _validateChildReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    address(0),
                    true,
                    child.maxPhysicalEditions > 0
                        ? child.maxPhysicalEditions
                        : 1,
                    true
                );
        } else if (child.availability == FGOLibrary.Availability.DIGITAL_ONLY) {
            allApproved =
                _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    false
                ) &&
                _validateChildReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    address(0),
                    false,
                    1,
                    true
                );
        } else {
            allApproved =
                _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    true
                ) &&
                _validateChildReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    address(0),
                    true,
                    child.maxPhysicalEditions > 0
                        ? child.maxPhysicalEditions
                        : 1,
                    true
                ) &&
                _validateTemplateReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    false
                ) &&
                _validateChildReferencesRecursive(
                    templatePlacements,
                    reservedTemplateId,
                    address(0),
                    false,
                    1,
                    true
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

            _createTemplateChildBaseWithId(_childSupply, params, placements);

            if (
                params.availability == FGOLibrary.Availability.PHYSICAL_ONLY ||
                params.availability == FGOLibrary.Availability.BOTH
            ) {
                _validateUnlimitedPhysicalPropagation(
                    params.maxPhysicalEditions,
                    placements
                );
            }

            if (
                params.availability == FGOLibrary.Availability.DIGITAL_ONLY ||
                params.availability == FGOLibrary.Availability.BOTH
            ) {
                _validateUnlimitedDigitalPropagation(
                    params.maxDigitalEditions,
                    placements
                );
            }

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
                allChildrenApproved =
                    _validateTemplateReferencesRecursive(
                        placements,
                        _childSupply,
                        true
                    ) &&
                    _validateChildReferencesRecursive(
                        placements,
                        _childSupply,
                        address(0),
                        true,
                        params.maxPhysicalEditions > 0
                            ? params.maxPhysicalEditions
                            : 1,
                        true
                    );
            } else if (
                params.availability == FGOLibrary.Availability.DIGITAL_ONLY
            ) {
                allChildrenApproved =
                    _validateTemplateReferencesRecursive(
                        placements,
                        _childSupply,
                        false
                    ) &&
                    _validateChildReferencesRecursive(
                        placements,
                        _childSupply,
                        address(0),
                        false,
                        1,
                        true
                    );
            } else {
                allChildrenApproved =
                    _validateTemplateReferencesRecursive(
                        placements,
                        _childSupply,
                        true
                    ) &&
                    _validateChildReferencesRecursive(
                        placements,
                        _childSupply,
                        address(0),
                        true,
                        params.maxPhysicalEditions > 0
                            ? params.maxPhysicalEditions
                            : 1,
                        true
                    ) &&
                    _validateTemplateReferencesRecursive(
                        placements,
                        _childSupply,
                        false
                    ) &&
                    _validateChildReferencesRecursive(
                        placements,
                        _childSupply,
                        address(0),
                        false,
                        1,
                        true
                    );
            }

            _setAuthorizedMarkets(_childSupply, params.authorizedMarkets);

            if (allChildrenApproved) {
                _children[_childSupply].status = FGOLibrary.Status.ACTIVE;
                _incrementUsageForChildren(_childSupply, placements);
                emit ChildCreated(_childSupply, msg.sender);
            } else {
                _requestNestedTemplateApprovals(
                    placements,
                    _childSupply,
                    false
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
                memory templatePlacements = _templatePlacements[
                    reservedTemplateId
                ];

            bool allApproved = false;
            if (child.availability == FGOLibrary.Availability.PHYSICAL_ONLY) {
                allApproved =
                    _validateTemplateReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        true
                    ) &&
                    _validateChildReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        address(0),
                        true,
                        child.maxPhysicalEditions > 0
                            ? child.maxPhysicalEditions
                            : 1,
                        true
                    );
            } else if (
                child.availability == FGOLibrary.Availability.DIGITAL_ONLY
            ) {
                allApproved =
                    _validateTemplateReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        false
                    ) &&
                    _validateChildReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        address(0),
                        false,
                        1,
                        true
                    );
            } else {
                allApproved =
                    _validateTemplateReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        true
                    ) &&
                    _validateChildReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        address(0),
                        true,
                        child.maxPhysicalEditions > 0
                            ? child.maxPhysicalEditions
                            : 1,
                        true
                    ) &&
                    _validateTemplateReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        false
                    ) &&
                    _validateChildReferencesRecursive(
                        templatePlacements,
                        reservedTemplateId,
                        address(0),
                        false,
                        1,
                        true
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
            parentDesignId,
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
        uint256 parentDesignId,
        uint256 parentAmount,
        bool isPhysical,
        FGOLibrary.DemandEntry[] memory demands
    ) internal view returns (FGOLibrary.DemandEntry[] memory) {
        FGOLibrary.ChildMetadata storage template = _children[parentDesignId];
        bool skipAvailabilityMismatches = template.availability ==
            FGOLibrary.Availability.BOTH;

        uint256 referencesLength = childReferences.length;
        for (uint256 i = 0; i < referencesLength; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];
            uint256 totalAmount = childRef.amount * parentAmount;

            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                bool skipChild = false;
                if (skipAvailabilityMismatches) {
                    if (
                        isPhysical &&
                        child.availability ==
                        FGOLibrary.Availability.DIGITAL_ONLY
                    ) {
                        skipChild = true;
                    } else if (
                        !isPhysical &&
                        child.availability ==
                        FGOLibrary.Availability.PHYSICAL_ONLY
                    ) {
                        skipChild = true;
                    }
                }

                if (!skipChild && !child.isTemplate) {
                    demands = _addToDemands(
                        demands,
                        childRef.childContract,
                        childRef.childId,
                        totalAmount
                    );
                }
            } catch {
                demands = _addToDemands(
                    demands,
                    childRef.childContract,
                    childRef.childId,
                    totalAmount
                );
            }

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
        FGOLibrary.ChildMetadata storage template = _children[parentDesignId];
        bool skipAvailabilityMismatches = template.availability ==
            FGOLibrary.Availability.BOTH;

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

            bool hasOpenAccess = false;
            uint256 approvedAmount = 0;
            bool skipChild = false;

            try
                IFGOChild(demand.childContract).getChildMetadata(demand.childId)
            returns (FGOLibrary.ChildMetadata memory childMeta) {
                if (skipAvailabilityMismatches) {
                    if (
                        isPhysical &&
                        childMeta.availability ==
                        FGOLibrary.Availability.DIGITAL_ONLY
                    ) {
                        skipChild = true;
                    } else if (
                        !isPhysical &&
                        childMeta.availability ==
                        FGOLibrary.Availability.PHYSICAL_ONLY
                    ) {
                        skipChild = true;
                    }
                }

                if (!skipChild) {
                    if (isPhysical && childMeta.physicalReferencesOpenToAll) {
                        hasOpenAccess = true;
                    } else if (
                        !isPhysical && childMeta.digitalReferencesOpenToAll
                    ) {
                        hasOpenAccess = true;
                    }
                }
            } catch {
                return false;
            }

            if (skipChild) {
                unchecked {
                    ++i;
                }
                continue;
            }

            if (!hasOpenAccess) {
                try
                    IFGOChild(demand.childContract).getTemplateApprovedAmount(
                        demand.childId,
                        parentDesignId,
                        address(this),
                        isPhysical
                    )
                returns (uint256 approved) {
                    approvedAmount = approved;
                } catch {
                    approvedAmount = 0;
                }

                uint256 futuresCredits = 0;
                if (futuresCoordination != address(0)) {
                    try
                        IFGOFuturesCoordination(futuresCoordination)
                            .getFuturesCredits(
                                demand.childContract,
                                demand.childId,
                                template.supplier
                            )
                    returns (uint256 credits) {
                        futuresCredits = credits;
                    } catch {}
                }

                if (approvedAmount + futuresCredits < demand.cumulativeDemand) {
                    return false;
                }
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
                            child.totalReservedSupply +
                            child.usageCount +
                            demand.cumulativeDemand >
                        child.maxPhysicalEditions + child.totalPrepaidAmount
                    ) {
                        return false;
                    }
                }

                if (!isPhysical) {
                    if (
                        child.futures.isFutures &&
                        child.futures.maxDigitalEditions > 0
                    ) {
                        if (
                            child.currentDigitalEditions +
                                demand.cumulativeDemand >
                            child.futures.maxDigitalEditions +
                                child.totalPrepaidAmount
                        ) {
                            return false;
                        }
                    } else if (child.maxDigitalEditions > 0) {
                        if (
                            child.currentDigitalEditions +
                                demand.cumulativeDemand >
                            child.maxDigitalEditions + child.totalPrepaidAmount
                        ) {
                            return false;
                        }
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
        FGOLibrary.ChildMetadata storage template = _children[templateId];
        bool skipAvailabilityMismatches = template.availability ==
            FGOLibrary.Availability.BOTH;

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

            FGOLibrary.ChildMetadata memory child;
            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory childMeta) {
                child = childMeta;
            } catch {
                return false;
            }

            if (skipAvailabilityMismatches) {
                if (
                    isPhysical &&
                    child.availability == FGOLibrary.Availability.DIGITAL_ONLY
                ) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
                if (
                    !isPhysical &&
                    child.availability == FGOLibrary.Availability.PHYSICAL_ONLY
                ) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
            } else {
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

            if (child.isTemplate) {
                try
                    IFGOTemplate(childRef.childContract).getTemplatePlacements(
                        childRef.childId
                    )
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

            unchecked {
                ++i;
            }
        }

        return true;
    }

    function _requestNestedTemplateApprovals(
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 templateId,
        bool isNested
    ) internal {
        FGOLibrary.ChildMetadata storage templateMetadata = _children[
            templateId
        ];

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildReference memory childRef = childReferences[i];

            FGOLibrary.ChildMetadata memory childMetadata;
            try
                IFGOChild(childRef.childContract).getChildMetadata(
                    childRef.childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            bool needsPhysicalApproval = (templateMetadata.availability ==
                FGOLibrary.Availability.PHYSICAL_ONLY ||
                templateMetadata.availability ==
                FGOLibrary.Availability.BOTH) &&
                (childMetadata.availability ==
                    FGOLibrary.Availability.PHYSICAL_ONLY ||
                    childMetadata.availability == FGOLibrary.Availability.BOTH);

            bool needsDigitalApproval = (templateMetadata.availability ==
                FGOLibrary.Availability.DIGITAL_ONLY ||
                templateMetadata.availability ==
                FGOLibrary.Availability.BOTH) &&
                (childMetadata.availability ==
                    FGOLibrary.Availability.DIGITAL_ONLY ||
                    childMetadata.availability == FGOLibrary.Availability.BOTH);

            if (childMetadata.futures.isFutures) {
                if (isNested) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }

                if (futuresCoordination == address(0)) {
                    revert FGOErrors.Unauthorized();
                }

                if (
                    needsPhysicalApproval &&
                    templateMetadata.maxPhysicalEditions > 0
                ) {
                    uint256 physicalAmount = childRef.amount *
                        templateMetadata.maxPhysicalEditions;

                    uint256 designerCredits = IFGOFuturesCoordination(
                        futuresCoordination
                    ).getFuturesCredits(
                            childRef.childContract,
                            childRef.childId,
                            msg.sender
                        );

                    if (designerCredits < physicalAmount) {
                        revert FGOErrors.Unauthorized();
                    }

                    IFGOFuturesCoordination(futuresCoordination)
                        .consumeFuturesCredits(
                            childRef.childContract,
                            childRef.childId,
                            msg.sender,
                            physicalAmount
                        );
                }

                if (
                    needsDigitalApproval &&
                    templateMetadata.maxDigitalEditions > 0
                ) {
                    uint256 digitalAmount = childRef.amount *
                        templateMetadata.maxDigitalEditions;

                    uint256 designerCredits = IFGOFuturesCoordination(
                        futuresCoordination
                    ).getFuturesCredits(
                            childRef.childContract,
                            childRef.childId,
                            msg.sender
                        );

                    if (designerCredits < digitalAmount) {
                        revert FGOErrors.Unauthorized();
                    }

                    IFGOFuturesCoordination(futuresCoordination)
                        .consumeFuturesCredits(
                            childRef.childContract,
                            childRef.childId,
                            msg.sender,
                            digitalAmount
                        );
                }
            } else {
                if (needsPhysicalApproval) {
                    uint256 totalPhysicalDemand = templateMetadata
                        .maxPhysicalEditions > 0
                        ? childRef.amount * templateMetadata.maxPhysicalEditions
                        : type(uint256).max;

                    uint256 physicalApprovalNeeded = totalPhysicalDemand >
                        childRef.prepaidAmount
                        ? totalPhysicalDemand - childRef.prepaidAmount
                        : 0;

                    if (physicalApprovalNeeded > 0) {
                        try
                            IFGOChild(childRef.childContract)
                                .requestTemplateApproval(
                                    childRef.childId,
                                    templateId,
                                    physicalApprovalNeeded,
                                    true
                                )
                        {} catch {
                            revert FGOErrors.CatchBlock();
                        }
                    }
                }

                if (needsDigitalApproval) {
                    uint256 totalDigitalDemand = templateMetadata
                        .maxDigitalEditions > 0
                        ? childRef.amount * templateMetadata.maxDigitalEditions
                        : type(uint256).max;

                    uint256 digitalApprovalNeeded = totalDigitalDemand >
                        childRef.prepaidAmount
                        ? totalDigitalDemand - childRef.prepaidAmount
                        : 0;

                    if (digitalApprovalNeeded > 0) {
                        try
                            IFGOChild(childRef.childContract)
                                .requestTemplateApproval(
                                    childRef.childId,
                                    templateId,
                                    digitalApprovalNeeded,
                                    false
                                )
                        {} catch {
                            revert FGOErrors.CatchBlock();
                        }
                    }
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
                            templateId,
                            true
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
        FGOLibrary.ChildMetadata memory templateMetadata = _children[
            templateId
        ];

        if (
            templateMetadata.maxPhysicalEditions == 0 &&
            templateMetadata.maxDigitalEditions == 0
        ) {
            return;
        }

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            try
                IFGOChild(childReferences[i].childContract).incrementChildUsage(
                    childReferences[i].childId,
                    templateId,
                    childReferences[i].amount,
                    templateMetadata.maxPhysicalEditions,
                    templateMetadata.maxDigitalEditions,
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

    function _validateUnlimitedPhysicalPropagation(
        uint256 maxPhysicalEditions,
        FGOLibrary.ChildReference[] memory childReferences
    ) internal view {
        if (maxPhysicalEditions != 0) {
            return;
        }

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildMetadata memory childMetadata;

            try
                IFGOChild(childReferences[i].childContract).getChildMetadata(
                    childReferences[i].childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            if (
                childMetadata.availability ==
                FGOLibrary.Availability.PHYSICAL_ONLY ||
                childMetadata.availability == FGOLibrary.Availability.BOTH
            ) {
                if (childMetadata.maxPhysicalEditions != 0) {
                    revert FGOErrors.Unauthorized();
                }

                if (childMetadata.isTemplate) {
                    try
                        IFGOTemplate(childReferences[i].childContract)
                            .getTemplatePlacements(childReferences[i].childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        _validateUnlimitedPhysicalPropagation(
                            0,
                            templatePlacements
                        );
                    } catch {
                        revert FGOErrors.CatchBlock();
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _validateUnlimitedDigitalPropagation(
        uint256 maxDigitalEditions,
        FGOLibrary.ChildReference[] memory childReferences
    ) internal view {
        if (maxDigitalEditions != 0) {
            return;
        }

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildMetadata memory childMetadata;

            try
                IFGOChild(childReferences[i].childContract).getChildMetadata(
                    childReferences[i].childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            if (
                childMetadata.availability ==
                FGOLibrary.Availability.DIGITAL_ONLY ||
                childMetadata.availability == FGOLibrary.Availability.BOTH
            ) {
                bool hasDigitalLimit = false;

                if (
                    childMetadata.futures.isFutures &&
                    childMetadata.futures.maxDigitalEditions > 0
                ) {
                    hasDigitalLimit = true;
                }

                if (childReferences[i].prepaidAmount > 0) {
                    hasDigitalLimit = true;
                }

                if (hasDigitalLimit) {
                    revert FGOErrors.Unauthorized();
                }

                if (childMetadata.isTemplate) {
                    try
                        IFGOTemplate(childReferences[i].childContract)
                            .getTemplatePlacements(childReferences[i].childId)
                    returns (
                        FGOLibrary.ChildReference[] memory templatePlacements
                    ) {
                        _validateUnlimitedDigitalPropagation(
                            0,
                            templatePlacements
                        );
                    } catch {
                        revert FGOErrors.CatchBlock();
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _hasFuturesOrPrepaidChildren(
        FGOLibrary.ChildReference[] memory childReferences,
        FGOLibrary.Availability templateAvailability
    ) internal view returns (bool) {
        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildMetadata memory childMetadata;

            try
                IFGOChild(childReferences[i].childContract).getChildMetadata(
                    childReferences[i].childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                revert FGOErrors.ChildNotAuthorized();
            }

            if (
                templateAvailability == FGOLibrary.Availability.DIGITAL_ONLY ||
                templateAvailability == FGOLibrary.Availability.BOTH
            ) {
                if (
                    childMetadata.availability ==
                    FGOLibrary.Availability.DIGITAL_ONLY ||
                    childMetadata.availability == FGOLibrary.Availability.BOTH
                ) {
                    if (
                        childMetadata.futures.isFutures &&
                        childMetadata.futures.maxDigitalEditions > 0
                    ) {
                        return true;
                    }

                    if (childReferences[i].prepaidAmount > 0) {
                        return true;
                    }
                }
            }

            if (childMetadata.isTemplate) {
                try
                    IFGOTemplate(childReferences[i].childContract)
                        .getTemplatePlacements(childReferences[i].childId)
                returns (
                    FGOLibrary.ChildReference[] memory templatePlacements
                ) {
                    if (
                        _hasFuturesOrPrepaidChildren(
                            templatePlacements,
                            templateAvailability
                        )
                    ) {
                        return true;
                    }
                } catch {
                    revert FGOErrors.CatchBlock();
                }
            }

            unchecked {
                ++i;
            }
        }

        return false;
    }

    function _consumeFuturesCreditsForTemplate(
        uint256 templateId,
        FGOLibrary.ChildReference[] memory childReferences,
        uint256 maxPhysicalEditions,
        uint256 maxDigitalEditions
    ) internal {
        if (futuresCoordination == address(0)) {
            return;
        }

        uint256 length = childReferences.length;
        for (uint256 i = 0; i < length; ) {
            FGOLibrary.ChildMetadata memory childMetadata;
            try
                IFGOChild(childReferences[i].childContract).getChildMetadata(
                    childReferences[i].childId
                )
            returns (FGOLibrary.ChildMetadata memory child) {
                childMetadata = child;
            } catch {
                unchecked {
                    ++i;
                }
                continue;
            }

            if (!childMetadata.futures.isFutures) {
                unchecked {
                    ++i;
                }
                continue;
            }

            FGOLibrary.ChildMetadata storage template = _children[templateId];

            bool needsPhysicalApproval = (template.availability ==
                FGOLibrary.Availability.PHYSICAL_ONLY ||
                template.availability == FGOLibrary.Availability.BOTH) &&
                (childMetadata.availability ==
                    FGOLibrary.Availability.PHYSICAL_ONLY ||
                    childMetadata.availability == FGOLibrary.Availability.BOTH);

            bool needsDigitalApproval = (template.availability ==
                FGOLibrary.Availability.DIGITAL_ONLY ||
                template.availability == FGOLibrary.Availability.BOTH) &&
                (childMetadata.availability ==
                    FGOLibrary.Availability.DIGITAL_ONLY ||
                    childMetadata.availability == FGOLibrary.Availability.BOTH);

            if (needsPhysicalApproval && maxPhysicalEditions > 0) {
                uint256 physicalAmount = childReferences[i].amount *
                    maxPhysicalEditions;
                IFGOFuturesCoordination(futuresCoordination)
                    .consumeFuturesCredits(
                        childReferences[i].childContract,
                        childReferences[i].childId,
                        msg.sender,
                        physicalAmount
                    );
            }

            if (needsDigitalApproval && maxDigitalEditions > 0) {
                uint256 digitalAmount = childReferences[i].amount *
                    maxDigitalEditions;
                IFGOFuturesCoordination(futuresCoordination)
                    .consumeFuturesCredits(
                        childReferences[i].childContract,
                        childReferences[i].childId,
                        msg.sender,
                        digitalAmount
                    );
            }

            unchecked {
                ++i;
            }
        }
    }
}
