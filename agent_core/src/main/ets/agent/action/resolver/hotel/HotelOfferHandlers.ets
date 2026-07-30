import { DataResult } from '../../../message/DataResult';
import {
  ActionCandidate,
  ActionCandidateProjector
} from '../ActionCandidateTypes';
import {
  SourceOfferContract,
  SourceOfferHandler
} from '../SourceOfferHandler';
import {
  HotelBookingOpenProjector,
  HotelDetailProjector,
  HotelNavigateProjector
} from './HotelActionProjectors';
import {
  HotelDetailProjection,
  HotelSearchProjection,
  parseHotelDetailProjection,
  parseHotelSearchProjection
} from './HotelDataResultParsers';

function appendProjectorCandidates<T>(
  target: ActionCandidate[],
  projector: ActionCandidateProjector<T>,
  source: T
): void {
  try {
    const candidates = projector.project(source);
    for (let index = 0; index < candidates.length; index++) {
      if (candidates[index].actionId === projector.actionId()) {
        target.push(candidates[index]);
      }
    }
  } catch (_error) {
  }
}

export class HotelSearchOfferHandler implements SourceOfferHandler {
  private readonly projectors:
    Map<string, ActionCandidateProjector<HotelSearchProjection>> =
    new Map<string, ActionCandidateProjector<HotelSearchProjection>>();

  constructor() {
    const detail = new HotelDetailProjector();
    const navigate = new HotelNavigateProjector();
    this.projectors.set(detail.actionId(), detail);
    this.projectors.set(navigate.actionId(), navigate);
  }

  contract(): SourceOfferContract {
    return {
      toolId: 'hotel.search',
      outputSchema: 'hotelSearchResults'
    };
  }

  project(
    data: DataResult,
    allowedActionIds: string[]
  ): ActionCandidate[] {
    const source = parseHotelSearchProjection(data);
    if (source === null) {
      return [];
    }
    const candidates: ActionCandidate[] = [];
    for (let index = 0; index < allowedActionIds.length; index++) {
      const projector = this.projectors.get(allowedActionIds[index]);
      if (projector !== undefined) {
        appendProjectorCandidates(candidates, projector, source);
      }
    }
    return candidates;
  }
}

export class HotelDetailOfferHandler implements SourceOfferHandler {
  private readonly projectors:
    Map<string, ActionCandidateProjector<HotelDetailProjection>> =
    new Map<string, ActionCandidateProjector<HotelDetailProjection>>();

  constructor() {
    const booking = new HotelBookingOpenProjector();
    this.projectors.set(booking.actionId(), booking);
  }

  contract(): SourceOfferContract {
    return {
      toolId: 'hotel.detail',
      outputSchema: 'hotelRatePlans'
    };
  }

  project(
    data: DataResult,
    allowedActionIds: string[]
  ): ActionCandidate[] {
    const source = parseHotelDetailProjection(data);
    if (source === null) {
      return [];
    }
    const candidates: ActionCandidate[] = [];
    for (let index = 0; index < allowedActionIds.length; index++) {
      const projector = this.projectors.get(allowedActionIds[index]);
      if (projector !== undefined) {
        appendProjectorCandidates(candidates, projector, source);
      }
    }
    return candidates;
  }
}
