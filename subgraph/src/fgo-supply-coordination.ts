import {
  Address,
  BigInt,
  Bytes,
  crypto,
  ethereum,
  store,
} from "@graphprotocol/graph-ts";
import {
  ExpiredSupplyReleased as ExpiredSupplyReleasedEvent,
  FGOSupplyCoordination,
  ParentSupplyReleased as ParentSupplyReleasedEvent,
  ProposalCancelled as ProposalCancelledEvent,
  SupplyProposalSubmitted as SupplyProposalSubmittedEvent,
  SupplyRequestPaid as SupplyRequestPaidEvent,
  SupplyRequestRegistered as SupplyRequestRegisteredEvent,
} from "../generated/FGOSupplyCoordination/FGOSupplyCoordination";
import {
  SupplierProposal,
  ChildSupplyRequest,
  Parent,
  ChildReference,
} from "../generated/schema";
import { FGOParent } from "../generated/templates/FGOParent/FGOParent";
import { FGOTemplateChild } from "../generated/templates/FGOTemplateChild/FGOTemplateChild";

export function handleExpiredSupplyReleased(
  event: ExpiredSupplyReleasedEvent
): void {
  let supplyRequest = ChildSupplyRequest.load(event.params.positionId);

  if (supplyRequest) {
    if (!supplyRequest.expired) {
      supplyRequest.expired = true;
    }

    let coordination = FGOSupplyCoordination.bind(event.address);
    let proposalData = coordination.getSupplierProposal(
      event.params.positionId,
      event.params.supplier
    );

    let proposalId = Bytes.fromUTF8(
      event.params.positionId.toHexString() +
        "-" +
        event.params.supplier.toHexString() +
        "-" +
        proposalData.childId.toString() +
        "-" +
        proposalData.childContract.toHexString()
    );

    store.remove("SupplierProposal", proposalId.toHexString());

    let proposals = supplyRequest.proposals;
    if (proposals) {
      let newProposals: Bytes[] = [];
      for (let i = 0; i < proposals.length; i++) {
        if (proposals[i] !== proposalId) {
          newProposals.push(proposals[i]);
        }
      }
      supplyRequest.proposals = newProposals;
    }

    supplyRequest.save();
  }
}

export function handleParentSupplyReleased(
  event: ParentSupplyReleasedEvent
): void {
  let parentEntity = Parent.load(
    Bytes.fromUTF8(
      event.params.parentContract.toHexString() +
        "-" +
        event.params.parentId.toString()
    )
  );

  if (parentEntity && parentEntity.supplyRequests) {
    let supplyRequests = parentEntity.supplyRequests;

    for (let i = 0; i < (supplyRequests as Bytes[]).length; i++) {
      let request = ChildSupplyRequest.load((supplyRequests as Bytes[])[i]);

      if (request && !request.paid) {
        if (request.proposals) {
          let proposals = request.proposals;

          for (let j = 0; j < (proposals as Bytes[]).length; j++) {
            let proposal = SupplierProposal.load((proposals as Bytes[])[j]);

            if (proposal) {
              store.remove(
                "SupplierProposal",
                ((proposals as Bytes[])[j] as Bytes).toHexString()
              );
            }
          }

          request.proposals = [];
        }

        request.save();
      }
    }
  }
}

export function handleProposalCancelled(event: ProposalCancelledEvent): void {
  let coordination = FGOSupplyCoordination.bind(event.address);
  let data = coordination.getSupplierProposal(
    event.params.positionId,
    event.params.supplier
  );
  let proposalId = Bytes.fromUTF8(
    event.params.positionId.toHexString() +
      "-" +
      data.supplier.toHexString() +
      "-" +
      data.childId.toString() +
      "-" +
      data.childContract.toHexString()
  );
  store.remove("SupplierProposal", proposalId.toHexString());

  let entityRequest = ChildSupplyRequest.load(event.params.positionId);

  if (entityRequest) {
    let proposals = entityRequest.proposals;

    if (proposals) {
      let newProposals: Bytes[] = [];
      for (let i = 0; i < proposals.length; i++) {
        if (proposals[i] !== proposalId) {
          newProposals.push(proposals[i]);
        }
      }
      entityRequest.proposals = newProposals;
      entityRequest.save();
    }
  }
}

export function handleSupplyProposalSubmitted(
  event: SupplyProposalSubmittedEvent
): void {
  let entity = new SupplierProposal(
    Bytes.fromUTF8(
      event.params.positionId.toHexString() +
        "-" +
        event.params.supplier.toHexString() +
        "-" +
        event.params.childId.toString() +
        "-" +
        event.params.childContract.toHexString()
    )
  );

  let coordination = FGOSupplyCoordination.bind(event.address);

  let data = coordination.getSupplierProposal(
    event.params.positionId,
    event.params.supplier
  );

  entity.positionId = event.params.positionId;
  entity.supplier = event.params.supplier;
  entity.childId = event.params.childId;
  entity.childContract = event.params.childContract;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;
  entity.timestamp = data.timestamp;
  entity.child = Bytes.fromUTF8(
    event.params.childContract.toHexString() +
      "-" +
      event.params.childId.toString()
  );

  entity.save();

  let entityRequest = ChildSupplyRequest.load(event.params.positionId);

  if (entityRequest) {
    let proposals = entityRequest.proposals;

    if (!proposals) {
      proposals = [];
    }
    proposals.push(entity.id);
    entityRequest.proposals = proposals;
    entityRequest.save();
  }
}

export function handleSupplyRequestPaid(event: SupplyRequestPaidEvent): void {
  let entity = ChildSupplyRequest.load(event.params.positionId);

  if (entity) {
    let coordination = FGOSupplyCoordination.bind(event.address);

    let data = coordination.getSupplyPosition(event.params.positionId);

    entity.paid = true;
    entity.paidBlockNumber = event.block.number;
    entity.paidBlockTimestamp = event.block.timestamp;
    entity.paidTransactionHash = event.transaction.hash;
    entity.matchedChildContract = data.matchedChildContract;
    entity.matchedChildId = data.matchedChildId;
    entity.matchedChild = Bytes.fromUTF8(
      data.matchedChildContract.toHexString() +
        "-" +
        data.matchedChildId.toString()
    );
    entity.matchedSupplier = data.matchedSupplier;

    entity.save();

    if (entity.parent) {
      let parentEntity = Parent.load(entity.parent as Bytes);
      if (parentEntity) {
        let childRefs: Bytes[] = [];
        let parent = FGOParent.bind(parentEntity.parentContract as Address);
        let parentData = parent.getDesignTemplate(
          parentEntity.designId as BigInt
        );

        if (parentData.childReferences) {
          for (let i = 0; i < parentData.childReferences.length; i++) {
            let placement = parentData.childReferences[i];
            let placementId = Bytes.fromUTF8(
              placement.childId.toHexString() +
                "-placement-" +
                placement.childContract.toHexString() +
                "-" +
                i.toString() +
                "-" +
                placement.placementURI.toString()
            );

            let childRefEntity = new ChildReference(placementId);
            let placementChild = FGOTemplateChild.bind(placement.childContract);
            let placementData = placementChild.getChildMetadata(
              placement.childId
            );

            childRefEntity.parent = entity.id;
            childRefEntity.childContract = placement.childContract;
            childRefEntity.childId = placement.childId;
            childRefEntity.amount = placement.amount;
            childRefEntity.placementURI = placement.placementURI;
            childRefEntity.isTemplate = placementData.isTemplate;
            childRefEntity.prepaidAmount = placement.prepaidAmount;
            childRefEntity.prepaidUsed = placement.prepaidUsed;

            if (placementData.isTemplate) {
              childRefEntity.childTemplate = Bytes.fromUTF8(
                placement.childContract.toHexString() +
                  "-" +
                  placement.childId.toString()
              );
            } else {
              childRefEntity.child = Bytes.fromUTF8(
                placement.childContract.toHexString() +
                  "-" +
                  placement.childId.toString()
              );
            }

            childRefEntity.save();
            childRefs.push(placementId);
          }
        }

        parentEntity.childReferences = childRefs;
        parentEntity.save();
      }
    }
  }
}

export function handleSupplyRequestRegistered(
  event: SupplyRequestRegisteredEvent
): void {
  let entity = new ChildSupplyRequest(event.params.positionId);
  let parentId = Bytes.fromUTF8(
    event.params.parentContract.toHexString() +
      "-" +
      event.params.parentId.toString()
  );
  let contract = FGOSupplyCoordination.bind(event.address);
  let supply = contract.getSupplyPosition(event.params.positionId);
  entity.parent = parentId;
  entity.paid = false;
  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.existingChildId = supply.request.existingChildId;
  entity.existingChild = Bytes.fromUTF8(
    supply.request.existingChildContract.toHexString() +
      "-" +
      supply.request.existingChildId.toString()
  );
  entity.quantity = supply.request.quantity;
  entity.preferredMaxPrice = supply.request.preferredMaxPrice;
  entity.deadline = supply.request.deadline;
  entity.existingChildContract = supply.request.existingChildContract;
  entity.isPhysical = supply.request.isPhysical;
  entity.customSpec = supply.request.customSpec;
  entity.placementURI = supply.request.placementURI;

  entity.save();

  let parentEntity = Parent.load(parentId);

  if (!parentEntity) {
    parentEntity = new Parent(parentId);
  }
  let supplyRequests = parentEntity.supplyRequests;

  if (!supplyRequests) {
    supplyRequests = [];
  }
  supplyRequests.push(entity.id);
  parentEntity.supplyRequests = supplyRequests;

  parentEntity.save();
}
