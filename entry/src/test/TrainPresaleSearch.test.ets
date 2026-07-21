import { describe, it, expect } from '@ohos/hypium';
import {
  buildPresaleTrainData,
  parsePresaleRange,
  selectTrainSearchPath
} from '@loop/agent-core';

const PRESALE_RANGE_FIXTURE: string = '{"status":true,"data":{"today":"2026年07月22日","hlwlptysq":"08月05日"}}';

export default function trainPresaleSearchTest() {
  describe('trainPresaleSearch', () => {
    it('routes an exact future train to the presale lookup', 0, () => {
      const range = parsePresaleRange(PRESALE_RANGE_FIXTURE);
      expect(selectTrainSearchPath('2026-08-06 北京南到上海虹桥 G1次', '2026-08-06', range)).assertEqual('presale');
    });

    it('asks for a train code instead of searching an unsupported future route', 0, () => {
      const range = parsePresaleRange(PRESALE_RANGE_FIXTURE);
      expect(selectTrainSearchPath('2026-08-06 北京南到上海虹桥高铁', '2026-08-06', range)).assertEqual('futureTrainCodeRequired');
    });

    it('keeps an on-sale date on the left-ticket path', 0, () => {
      const range = parsePresaleRange(PRESALE_RANGE_FIXTURE);
      expect(selectTrainSearchPath('2026-08-05 北京南到上海虹桥 G1次', '2026-08-05', range)).assertEqual('leftTicket');
    });

    it('routes an exact future train to a provider error when the presale range is unavailable', 0, () => {
      const range = parsePresaleRange('{');
      expect(selectTrainSearchPath('2099-08-06 北京南到上海虹桥 G1次', '2099-08-06', range)).assertEqual('presaleRangeUnavailable');
    });

    it('routes a future route-only query to a provider error when the presale range is unavailable', 0, () => {
      const range = parsePresaleRange('{');
      expect(selectTrainSearchPath('2099-08-06 北京南到上海虹桥高铁', '2099-08-06', range)).assertEqual('presaleRangeUnavailableRouteOnly');
    });

    it('builds a verified presale card with booking details', 0, () => {
      const train = buildPresaleTrainData(
        'G1',
        '2026-08-06',
        '北京南',
        'VNP',
        '上海虹桥',
        'AOH',
        '06:30',
        '11:24',
        '2026-08-06T12:45:00+08:00',
        553
      );
      expect(train === undefined).assertFalse();
      if (train !== undefined) {
        expect(train.trainCode).assertEqual('G1');
        expect(train.travelDate).assertEqual('2026-08-06');
        expect(train.from).assertEqual('北京南');
        expect(train.to).assertEqual('上海虹桥');
        expect(train.saleState).assertEqual('presale');
        expect(train.saleAt).assertEqual('2026-08-06T12:45:00+08:00');
        expect(train.price).assertEqual('553');
        const bookingUrl = train.bookingUrl;
        expect(bookingUrl === undefined).assertFalse();
        if (bookingUrl !== undefined) {
          expect(bookingUrl.includes('date=2026-08-06')).assertTrue();
        }
      }
    });

    it('rejects a provider mismatch instead of producing a plausible presale card', 0, () => {
      expect(buildPresaleTrainData(
        'G1',
        '2026-08-06',
        '北京南',
        'VNP',
        '上海虹桥',
        'AOH',
        '06:30',
        '11:24',
        '2026-08-07T12:45:00+08:00',
        553
      )).assertEqual(undefined);
    });
  });
}
