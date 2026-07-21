import { DataResult } from '../message/DataResult';

export interface ActionOffer {
  offerId: string;
  actionId: string;
  label: string;
  variant: string;
  args: Object;
}

export interface ActionOfferContext {
  conversationId: string;
  turnId: string;
  dataTaskId: string;
}

export type ActionOfferResolver = (
  data: DataResult,
  context: ActionOfferContext
) => Promise<ActionOffer[]>;

export interface ActionOffersReadyPayload {
  dataTaskId: string;
  sourceToolId: string;
  offers: ActionOffer[];
}
