import { BigInt, Bytes, log } from "@graphprotocol/graph-ts";
import {
  Fulfiller,
  Fulfillment,
  FulfillmentOrderStep,
  FulfillmentStep,
  FulfillmentWorkflow,
  Order,
  Parent,
} from "../generated/schema";
import {
  StepCompleted as StepCompletedEvent,
  FulfillmentCompleted as FulfillmentCompletedEvent,
  FulfillmentStarted as FulfillmentStartedEvent,
  FGOFulfillment,
} from "../generated/templates/FGOFulfillment/FGOFulfillment";
import { FGOMarket } from "../generated/templates/FGOMarket/FGOMarket";

export function handleStepCompleted(event: StepCompletedEvent): void {
  let fulfillment = FGOFulfillment.bind(event.address);
  let data = fulfillment.getFulfillmentStatus(event.params.orderId);
  let entity = Fulfillment.load(
    Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.orderId.toString() +
        data.parentContract.toHexString() +
        data.parentId.toHexString()
    )
  );

  let step = data.steps[event.params.stepIndex.toI32()];

  let marketAddress = fulfillment.market();
  let market = FGOMarket.bind(marketAddress);
  let orderData = market.getOrderReceipt(event.params.orderId);

  let isPhysical = orderData.params.isPhysical;

  let stepId =
    data.parentContract.toHexString() +
    "-" +
    data.parentId.toHexString() +
    "-" +
    event.params.stepIndex.toString();

  if (isPhysical) {
    stepId = stepId + "-physical";
  }

  let entitySteps = FulfillmentOrderStep.load(Bytes.fromUTF8(stepId));

  if (!entitySteps) {
    entitySteps = new FulfillmentOrderStep(Bytes.fromUTF8(stepId));
  }
  entitySteps.completedAt = step.completedAt;
  entitySteps.notes = step.notes;
  entitySteps.isCompleted = step.isCompleted;
  entitySteps.stepIndex = data.currentStep;
  entitySteps.save();

  if (entity) {
    entity.currentStep = data.currentStep;
    entity.lastUpdated = data.lastUpdated;

    let steps = entity.fulfillmentOrderSteps;
    if (!steps) {
      steps = [];
    }
    if (steps.indexOf(entitySteps.id) == -1) {
      steps.push(entitySteps.id);
    }
    entity.fulfillmentOrderSteps = steps;
    entity.save();
  }
}

export function handleFulfillmentCompleted(
  event: FulfillmentCompletedEvent
): void {
  let fulfillment = FGOFulfillment.bind(event.address);
  let data = fulfillment.getFulfillmentStatus(event.params.orderId);
  let marketAddress = fulfillment.market();
  let market = FGOMarket.bind(marketAddress);
  let orderData = market.getOrderReceipt(event.params.orderId);

  let isPhysical = orderData.params.isPhysical;

  let stepId =
    data.parentContract.toHexString() +
    "-" +
    data.parentId.toHexString() +
    "-" +
    (data.steps.length - 1).toString();

  if (isPhysical) {
    stepId = stepId + "-physical";
  }

  let entitySteps = FulfillmentOrderStep.load(Bytes.fromUTF8(stepId));
  if (entitySteps) {
    entitySteps.completedAt = data.steps[data.steps.length - 1].completedAt;
    entitySteps.isCompleted = data.steps[data.steps.length - 1].isCompleted;
    entitySteps.save();
  }

  let entityOrder = Order.load(
    Bytes.fromUTF8(
      marketAddress.toHexString() + "-" + event.params.orderId.toString()
    )
  );

  if (entityOrder) {
    let rec = market.getOrderReceipt(event.params.orderId);
    entityOrder.orderStatus = BigInt.fromI32(rec.status);
    entityOrder.save();
  }
}

export function handleFulfillmentStarted(event: FulfillmentStartedEvent): void {
  log.debug("=== handleFulfillmentStarted called ===", []);
  let fulfillment = FGOFulfillment.bind(event.address);
  let data = fulfillment.getFulfillmentStatus(event.params.orderId);
  log.debug("Parent: {}, ParentId: {}", [
    data.parentContract.toHexString(),
    data.parentId.toString(),
  ]);

  let entity = new Fulfillment(
    Bytes.fromUTF8(
      event.address.toHexString() +
        "-" +
        event.params.orderId.toString() +
        data.parentContract.toHexString() +
        event.params.parentId.toHexString()
    )
  );

  entity.orderId = event.params.orderId;
  entity.contract = event.address;
  entity.parent = Bytes.fromUTF8(
    data.parentContract.toHexString() + "-" + event.params.parentId.toString()
  );
  let marketAddress = fulfillment.market();

  let market = FGOMarket.bind(marketAddress);

  let parentEntity = Parent.load(entity.parent);
  log.debug("Parent loaded: {}", [parentEntity ? "YES" : "NO"]);

  if (parentEntity) {
    log.debug("Parent.workflow: {}", [parentEntity.workflow ? "YES" : "NO"]);
    if (parentEntity.workflow) {
      let workflowEntity = FulfillmentWorkflow.load(
        parentEntity.workflow as Bytes
      );
      log.debug("Workflow loaded: {}", [workflowEntity ? "YES" : "NO"]);
      if (workflowEntity) {
        entity.estimatedDeliveryDuration =
          workflowEntity.estimatedDeliveryDuration;
        entity.digitalSteps = workflowEntity.digitalSteps;
        entity.physicalSteps = workflowEntity.physicalSteps;
        if (workflowEntity.digitalSteps) {
          for (
            let i = 0;
            i < (workflowEntity.digitalSteps as Bytes[]).length;
            i++
          ) {
            let step = FulfillmentStep.load(
              (workflowEntity.digitalSteps as Bytes[])[i]
            );

            if (step && step.fulfiller) {
              log.debug("Found digitalStep with fulfiller: {}", [
                (step.fulfiller as Bytes).toHexString(),
              ]);
              let fulfiller = Fulfiller.load(step.fulfiller as Bytes);

              if (fulfiller) {
                log.debug("Loaded fulfiller: {}", [
                  (fulfiller.fulfiller as Bytes).toHexString(),
                ]);
                let fulls = fulfiller.fulfillments;
                if (!fulls) {
                  fulls = [];
                }
                log.debug("Before push - fulfillments length: {}", [
                  fulls.length.toString(),
                ]);
                if (fulls.indexOf(entity.id) == -1) {
                  fulls.push(entity.id);
                }
                log.debug("After push - fulfillments length: {}", [
                  fulls.length.toString(),
                ]);

                fulfiller.fulfillments = fulls;
                fulfiller.save();
                log.debug("Fulfiller saved with {} fulfillments", [
                  fulls.length.toString(),
                ]);
              } else {
                log.debug("Fulfiller not found: {}", [
                  (step.fulfiller as Bytes).toHexString(),
                ]);
              }
            }
          }
        }
        if (workflowEntity.physicalSteps) {
          for (
            let i = 0;
            i < (workflowEntity.physicalSteps as Bytes[]).length;
            i++
          ) {
            let step = FulfillmentStep.load(
              (workflowEntity.physicalSteps as Bytes[])[i]
            );

            if (step && step.fulfiller) {
              log.debug("Found physicalStep with fulfiller: {}", [
                (step.fulfiller as Bytes).toHexString(),
              ]);
              let fulfiller = Fulfiller.load(step.fulfiller as Bytes);

              if (fulfiller) {
                log.debug("Loaded fulfiller from physicalStep", []);
                let fulls = fulfiller.fulfillments;
                if (!fulls) {
                  fulls = [];
                }
                log.debug("Before push - fulfillments length: {}", [
                  fulls.length.toString(),
                ]);
                if (fulls.indexOf(entity.id) == -1) {
                  fulls.push(entity.id);
                }
                log.debug("After push - fulfillments length: {}", [
                  fulls.length.toString(),
                ]);

                fulfiller.fulfillments = fulls;
                fulfiller.save();
                log.debug("Fulfiller saved with {} fulfillments", [
                  fulls.length.toString(),
                ]);
              } else {
                log.debug("Fulfiller not found: {}", [
                  (step.fulfiller as Bytes).toHexString(),
                ]);
              }
            }
          }
        }
      }
    }
  }

  let orderData = market.getOrderReceipt(event.params.orderId);
  entity.isPhysical = orderData.params.isPhysical;
  entity.currentStep = data.currentStep;
  entity.createdAt = event.block.timestamp;
  entity.lastUpdated = event.block.timestamp;
  entity.order = Bytes.fromUTF8(
    fulfillment.market().toHexString() + "-" + entity.orderId.toString()
  );

  entity.save();
}
