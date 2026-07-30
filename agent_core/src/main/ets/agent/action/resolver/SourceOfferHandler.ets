import { DataResult } from '../../message/DataResult';
import { ActionCandidate } from './ActionCandidateTypes';

export interface SourceOfferContract {
  toolId: string;
  outputSchema: string;
}

export interface SourceOfferHandler {
  contract(): SourceOfferContract;

  project(
    data: DataResult,
    allowedActionIds: string[]
  ): ActionCandidate[];
}
