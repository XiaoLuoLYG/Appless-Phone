import {
  hotelBookingOpenAction,
  hotelDetailAction,
  hotelNavigateAction
} from '../../../../aiphone/runtime/HotelActions';
import { A2uiAction } from '../../../../aiphone/runtime/A2uiTypes';
import {
  ActionCandidate,
  ActionCandidateProjector
} from '../ActionCandidateTypes';
import {
  HotelDetailProjection,
  HotelSearchProjection,
  hotelSearchItem
} from './HotelDataResultParsers';

function candidateFromAction(
  action: A2uiAction,
  identity: string
): ActionCandidate | null {
  if (action.args === undefined) {
    return null;
  }
  return {
    identity,
    actionId: action.id,
    label: action.label,
    variant: action.variant,
    args: action.args
  };
}

export class HotelDetailProjector
  implements ActionCandidateProjector<HotelSearchProjection> {
  actionId(): string {
    return 'hotel.detail';
  }

  project(source: HotelSearchProjection): ActionCandidate[] {
    const candidates: ActionCandidate[] = [];
    const hotels = source.result.hotels;
    for (let index = 0; index < hotels.length; index++) {
      const hotel = hotelSearchItem(hotels[index]);
      if (hotel === null || !Number.isInteger(hotel.hotelId) ||
        hotel.hotelId <= 0) {
        continue;
      }
      const candidate = candidateFromAction(
        hotelDetailAction(hotel, source.result.query),
        hotel.hotelId.toString()
      );
      if (candidate !== null) {
        candidates.push(candidate);
      }
    }
    return candidates;
  }
}

export class HotelNavigateProjector
  implements ActionCandidateProjector<HotelSearchProjection> {
  actionId(): string {
    return 'hotel.navigate';
  }

  project(source: HotelSearchProjection): ActionCandidate[] {
    const candidates: ActionCandidate[] = [];
    const hotels = source.result.hotels;
    for (let index = 0; index < hotels.length; index++) {
      const hotel = hotelSearchItem(hotels[index]);
      if (hotel === null) {
        continue;
      }
      const candidate = candidateFromAction(
        hotelNavigateAction(hotel),
        hotel.hotelId.toString()
      );
      if (candidate !== null) {
        candidates.push(candidate);
      }
    }
    return candidates;
  }
}

export class HotelBookingOpenProjector
  implements ActionCandidateProjector<HotelDetailProjection> {
  actionId(): string {
    return 'hotel.booking.open';
  }

  project(source: HotelDetailProjection): ActionCandidate[] {
    const candidate = candidateFromAction(
      hotelBookingOpenAction(source.result),
      source.result.hotelId.toString()
    );
    return candidate === null ? [] : [candidate];
  }
}
