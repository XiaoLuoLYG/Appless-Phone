import { describe, expect, it } from '@ohos/hypium';
import { hotelDetailDataResult, hotelSearchDataResult } from '../main/ets/aiphone/runtime/HotelDataResult';
import {
  HotelDetailResult,
  HotelPrice,
  HotelRatePlan,
  HotelSearchItem,
  HotelSearchRequest,
  HotelSearchResult
} from '../main/ets/aiphone/runtime/HotelToolTypes';
import {
  ActionArgsValidator,
  ActionValidationResult
} from '../main/ets/agent/action/ActionCatalogTypes';
import { ActionCandidate } from '../main/ets/agent/action/resolver/ActionCandidateTypes';
import { ActionOfferFactory } from '../main/ets/agent/action/resolver/ActionOfferFactory';
import { ActionOffer, ActionOfferContext } from '../main/ets/agent/action/ActionOfferTypes';
import { createHotelActionOfferResolver } from '../main/ets/agent/action/resolver/hotel/HotelActionOfferResolver';
import { DataResult } from '../main/ets/agent/message/DataResult';

const CONTEXT: ActionOfferContext = {
  conversationId: 'conversation-1',
  turnId: 'turn-1',
  dataTaskId: 'hotel-task-1'
};

interface FixtureArgs {
  value: string;
}

class FixtureArgsValidator implements ActionArgsValidator {
  validate(actionId: string, _args: Object): ActionValidationResult {
    const ok = actionId === 'fixture.allowed';
    return {
      ok,
      code: ok ? '' : 'FIXTURE_REJECTED',
      message: ok ? '' : 'Fixture action rejected.'
    };
  }
}

function searchRequest(): HotelSearchRequest {
  return {
    originQuery: '杭州酒店',
    place: '杭州',
    placeType: 'city',
    countryCode: 'CN',
    checkInDate: '2026-08-01',
    checkOutDate: '2026-08-03',
    stayNights: 2,
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1,
    currency: 'CNY',
    size: 10
  };
}

function price(): HotelPrice {
  return {
    message: '',
    hasPrice: true,
    currency: 'CNY',
    lowestPrice: 699
  };
}

function hotel(
  hotelId: number,
  latitude: number | null,
  longitude: number | null
): HotelSearchItem {
  return {
    hotelId,
    bookingUrl: '',
    name: '测试酒店 ' + hotelId.toString(),
    nameEn: 'Fixture Hotel',
    brand: '',
    address: '杭州市测试路 ' + hotelId.toString() + ' 号',
    destinationId: 'hangzhou',
    latitude,
    longitude,
    distanceInMeters: 1000,
    starRating: 5,
    price: price(),
    areaCode: '0571',
    description: '',
    imageUrl: '',
    hotelAmenities: [],
    tags: []
  };
}

function searchResult(): HotelSearchResult {
  return {
    ok: true,
    error: '',
    message: '',
    query: searchRequest(),
    hotels: [
      hotel(101, 30.2741, 120.1551),
      hotel(102, null, null)
    ]
  };
}

function rate(): HotelRatePlan {
  return {
    roomName: 'Deluxe',
    roomNameCn: '豪华房',
    ratePlanId: 'rate-1',
    ratePlanName: '含早',
    averagePrice: 899,
    bedTypeDescription: '大床',
    currency: 'CNY',
    mealAmount: 2,
    mealTypeStr: '双早',
    isOnRequest: false,
    cancelPolicy: '入住前一天可取消'
  };
}

function detailResult(): HotelDetailResult {
  return {
    ok: true,
    error: '',
    message: '',
    query: {
      hotelId: 101,
      checkInDate: '2026-08-01',
      checkOutDate: '2026-08-03',
      countryCode: 'CN',
      currency: 'CNY',
      adultCount: 2,
      childCount: 0,
      childAgeDetails: [],
      roomCount: 1
    },
    hotelId: 101,
    bookingUrl: 'https://rollinggo.cn/pages/hotel/detail/index?' +
      'id=101&checkInDate=2026-08-01&checkOutDate=2026-08-03&' +
      'roomCount=1&adultCount=2&childCount=0',
    name: '测试酒店 101',
    nameEn: 'Fixture Hotel',
    checkIn: '2026-08-01',
    checkOut: '2026-08-03',
    rates: [rate()]
  };
}

function actionCount(offers: ActionOffer[], actionId: string): number {
  let count = 0;
  for (let index = 0; index < offers.length; index++) {
    if (offers[index].actionId === actionId) {
      count++;
    }
  }
  return count;
}

export default function hotelActionOfferResolverTests(): void {
  describe('ActionOfferFactory', (): void => {
    it('validates, clones, identifies, and deduplicates candidates', 0,
      (): void => {
        const factory = new ActionOfferFactory(new FixtureArgsValidator());
        const sourceArgs: FixtureArgs = {
          value: 'before'
        };
        const candidate: ActionCandidate = {
          identity: 'subject-1',
          actionId: 'fixture.allowed',
          label: 'Allowed',
          variant: 'primary',
          args: sourceArgs
        };
        const offers = factory.createAll([candidate, candidate], CONTEXT);
        sourceArgs.value = 'after';
        expect(offers.length).assertEqual(1);
        expect(offers[0].offerId).assertEqual(
          'hotel-task-1:fixture.allowed:subject-1'
        );
        expect((offers[0].args as FixtureArgs).value).assertEqual('before');
      });

    it('rejects candidates through the shared action validator', 0,
      (): void => {
        const factory = new ActionOfferFactory(new FixtureArgsValidator());
        const rejectedArgs: FixtureArgs = {
          value: 'unused'
        };
        const rejected: ActionCandidate = {
          identity: 'subject-1',
          actionId: 'fixture.rejected',
          label: 'Rejected',
          variant: 'primary',
          args: rejectedArgs
        };
        expect(factory.createAll([rejected], CONTEXT).length).assertEqual(0);
      });
  });

  describe('HotelActionOfferResolver', (): void => {
    it('projects detail offers per hotel and navigation only with coordinates', 0,
      async (): Promise<void> => {
        const resolver = createHotelActionOfferResolver();
        const offers = await resolver(
          hotelSearchDataResult(searchResult(), []),
          CONTEXT
        );
        expect(actionCount(offers, 'hotel.detail')).assertEqual(2);
        expect(actionCount(offers, 'hotel.navigate')).assertEqual(1);
        expect(offers[0].offerId).assertEqual(
          'hotel-task-1:hotel.detail:101'
        );
        expect(offers[2].offerId).assertEqual(
          'hotel-task-1:hotel.navigate:101'
        );
      });

    it('projects one booking offer from a valid hotel detail result', 0,
      async (): Promise<void> => {
        const resolver = createHotelActionOfferResolver();
        const offers = await resolver(
          hotelDetailDataResult(detailResult(), []),
          CONTEXT
        );
        expect(offers.length).assertEqual(1);
        expect(offers[0].actionId).assertEqual('hotel.booking.open');
        expect(offers[0].offerId).assertEqual(
          'hotel-task-1:hotel.booking.open:101'
        );
      });

    it('fails closed for an unknown source contract', 0,
      async (): Promise<void> => {
        const resolver = createHotelActionOfferResolver();
        const mismatched: DataResult = hotelSearchDataResult(
          searchResult(),
          []
        );
        mismatched.outputSchema = 'hotelSearchResults.v2';
        const offers = await resolver(mismatched, CONTEXT);
        expect(offers.length).assertEqual(0);
      });

    it('does not project offers from empty or error results', 0,
      async (): Promise<void> => {
        const resolver = createHotelActionOfferResolver();
        const empty = searchResult();
        empty.hotels = [];
        const failed = searchResult();
        failed.ok = false;
        failed.error = 'provider failed';
        expect((await resolver(
          hotelSearchDataResult(empty, []),
          CONTEXT
        )).length).assertEqual(0);
        expect((await resolver(
          hotelSearchDataResult(failed, []),
          CONTEXT
        )).length).assertEqual(0);
      });
  });
}
