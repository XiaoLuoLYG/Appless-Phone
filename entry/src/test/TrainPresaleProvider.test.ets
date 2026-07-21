import { describe, it, expect } from '@ohos/hypium';
import {
  extractExactTrainCode,
  parseFutureTrainMetadata,
  parseLowestTrainPrice,
  parsePresaleRange,
  parseStationSaleTime
} from '@loop/agent-core';

const PRESALE_FIXTURE: string = '{"data":{"ysq_count":15,"hlwlptysq":"08月05日","today":"2026年07月22日"},"httpstatus":200,"status":true}';
const TRAIN_SEARCH_FIXTURE: string = '{"data":[{"date":"20260806","from_station":"北京南","station_train_code":"G1","to_station":"上海虹桥","train_no":"24000000G10L"},{"date":"20260806","from_station":"北京南","station_train_code":"G10","to_station":"上海虹桥","train_no":"2400000G1000"}]}';
const TRAIN_STOPS_FIXTURE: string = '{"status":true,"data":{"data":[{"station_name":"北京南","station_train_code":"G1","station_no":"01","start_time":"06:30"},{"station_name":"上海虹桥","station_no":"07","arrive_time":"11:24"}]}}';
const STATION_SALE_FIXTURE: string = '{"data":[{"name":"北京","value":"10:00"},{"name":"北京南","value":"12:45"}],"status":true}';
const PRICE_FIXTURE: string = '{"status":true,"data":{"O":"553.0","M":"672.5","WZ":"--","A9":"0"}}';

export default function trainPresaleProviderTest() {
  describe('trainPresaleProvider', () => {
    it('parses the official presale range', 0, () => {
      const range = parsePresaleRange(PRESALE_FIXTURE);
      expect(range === undefined).assertFalse();
      if (range !== undefined) {
        expect(range.today).assertEqual('2026-07-22');
        expect(range.lastSaleDate).assertEqual('2026-08-05');
      }
    });

    it('selects only an exact official train code', 0, () => {
      const metadata = parseFutureTrainMetadata(TRAIN_SEARCH_FIXTURE, extractExactTrainCode('查询 G1 次'));
      expect(metadata === undefined).assertFalse();
      if (metadata !== undefined) {
        expect(metadata.trainCode).assertEqual('G1');
        expect(metadata.trainNo).assertEqual('24000000G10L');
        expect(metadata.from).assertEqual('北京南');
        expect(metadata.to).assertEqual('上海虹桥');
      }
      expect(parseFutureTrainMetadata(TRAIN_SEARCH_FIXTURE, 'G2') === undefined).assertTrue();
    });

    it('resolves verified origin and destination stops', 0, () => {
      const metadata = parseFutureTrainMetadata(TRAIN_STOPS_FIXTURE, 'G1');
      expect(metadata === undefined).assertFalse();
      if (metadata !== undefined) {
        expect(metadata.from).assertEqual('北京南');
        expect(metadata.fromStopNo).assertEqual('01');
        expect(metadata.depart).assertEqual('06:30');
        expect(metadata.to).assertEqual('上海虹桥');
        expect(metadata.toStopNo).assertEqual('07');
        expect(metadata.arrive).assertEqual('11:24');
      }
    });

    it('reads the official origin station sale time', 0, () => {
      expect(parseStationSaleTime(STATION_SALE_FIXTURE, '北京南')).assertEqual('12:45');
    });

    it('uses the lowest valid official train price', 0, () => {
      expect(parseLowestTrainPrice(PRICE_FIXTURE)).assertEqual(553);
    });

    it('fails closed for malformed or non-matching provider responses', 0, () => {
      expect(parsePresaleRange('{')).assertEqual(undefined);
      expect(extractExactTrainCode('没有指定车次')).assertEqual('');
      expect(parseFutureTrainMetadata('{"data":[]}', 'G1')).assertEqual(undefined);
      expect(parseStationSaleTime('{"data":[]}', '北京南')).assertEqual('');
      expect(parseLowestTrainPrice('{"data":{"O":"--"}}')).assertEqual(undefined);
    });
  });
}
