import { describe, it, expect } from '@ohos/hypium';
import {
  extractExactTrainCode,
  parseFutureTrainForTravelDate,
  parseFutureTrainMetadata,
  parseLowestTrainPrice,
  parsePresaleRange,
  parseStationSaleTime,
  presaleSaleAt
} from '@loop/agent-core';

const PRESALE_FIXTURE: string = '{"data":{"ysq_count":15,"hlwlptysq":"08月05日","today":"2026年07月22日"},"httpstatus":200,"status":true}';
const TRAIN_SEARCH_FIXTURE: string = '{"data":[{"date":"20260806","from_station":"北京南","station_train_code":"G1","to_station":"上海虹桥","train_no":"24000000G10L"},{"date":"20260806","from_station":"北京南","station_train_code":"G10","to_station":"上海虹桥","train_no":"2400000G1000"}]}';
const TRAIN_STOPS_FIXTURE: string = '{"status":true,"data":{"data":[{"station_name":"北京南","station_train_code":"G1","station_no":"01","start_time":"06:30"},{"station_name":"上海虹桥","station_no":"07","arrive_time":"11:24"}]}}';
const STATION_SALE_FIXTURE: string = '{"data":[{"name":"北京","value":"10:00"},{"name":"北京南","value":"12:45"}],"status":true}';
const PRICE_FIXTURE: string = '{"status":true,"data":{"O":"553.0","M":"672.5","WZ":"--","A9":"0"}}';
const NUMERIC_TRAIN_FIXTURE: string = '{"data":[{"date":"20260806","from_station":"北京南","station_train_code":"1234","to_station":"上海虹桥","train_no":"24000000N10L"},{"date":"20260806","from_station":"北京南","station_train_code":"12345","to_station":"上海虹桥","train_no":"2400000N1000"}]}';

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

    it('fails closed when an exact train record is for another travel date', 0, () => {
      expect(parseFutureTrainForTravelDate(TRAIN_SEARCH_FIXTURE, 'G1', '2026-08-06') === undefined).assertFalse();
      expect(parseFutureTrainForTravelDate(TRAIN_SEARCH_FIXTURE, 'G1', '2026-08-07')).assertEqual(undefined);
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
      const saleTime = parseStationSaleTime(STATION_SALE_FIXTURE, '北京南');
      expect(saleTime).assertEqual('12:45');
      expect(presaleSaleAt('2026-08-06', saleTime)).assertEqual('2026-08-06T12:45:00+08:00');
    });

    it('rolls a yearless presale date into the next year', 0, () => {
      const range = parsePresaleRange('{"status":true,"data":{"today":"2026年12月25日","hlwlptysq":"01月08日"}}');
      expect(range === undefined).assertFalse();
      if (range !== undefined) {
        expect(range.lastSaleDate).assertEqual('2027-01-08');
      }
    });

    it('accepts an exact numeric-only train code', 0, () => {
      const metadata = parseFutureTrainMetadata(NUMERIC_TRAIN_FIXTURE, extractExactTrainCode('查询 1234次'));
      expect(metadata === undefined).assertFalse();
      if (metadata !== undefined) {
        expect(metadata.trainCode).assertEqual('1234');
        expect(metadata.trainNo).assertEqual('24000000N10L');
      }
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
      expect(parsePresaleRange('{"status":true,"data":{"today":"2026年99月99日","hlwlptysq":"08月05日"}}')).assertEqual(undefined);
      expect(parseFutureTrainMetadata('{"data":[{"date":"20269999","from_station":"北京南","station_train_code":"G1","to_station":"上海虹桥","train_no":"24000000G10L"}]}', 'G1')).assertEqual(undefined);
      expect(parseFutureTrainMetadata('{"status":true,"data":{"data":[{"station_name":"北京南","station_train_code":"G1","station_no":"01","start_time":"99:99"},{"station_name":"上海虹桥","station_no":"07","arrive_time":"11:24"}]}}', 'G1')).assertEqual(undefined);
      expect(parseStationSaleTime('{"status":true,"data":[{"name":"北京南","value":"99:99"}]}', '北京南')).assertEqual('');
      expect(presaleSaleAt('2026-99-99', '12:45')).assertEqual('');
      expect(presaleSaleAt('2026-08-06', '99:99')).assertEqual('');
    });
  });
}
