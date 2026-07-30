import { describe, it, expect } from '@ohos/hypium';
import { ChatCompletionSseParser, StreamingLeaderToolParser } from '@loop/agent-core';

export default function streamingLeaderProtocolTest() {
  describe('StreamingLeaderProtocol', () => {
    it('reassembles SSE events across arbitrary network chunks', 0, () => {
      const parser: ChatCompletionSseParser = new ChatCompletionSseParser();
      let payloads: string[] = [];
      payloads = payloads.concat(parser.feed('data: {"choices":[{"delta":{"content":"<ap'));
      expect(payloads.length).assertEqual(0);
      payloads = payloads.concat(parser.feed('pless"}}]}\r\n\r'));
      expect(payloads.length).assertEqual(0);
      payloads = payloads.concat(parser.feed('\ndata: {"choices":[{"delta":{"content":"_tool>"}}]}\n\n'));
      expect(payloads.length).assertEqual(2);
      expect(payloads[0]).assertEqual('{"choices":[{"delta":{"content":"<appless"}}]}');
      expect(payloads[1]).assertEqual('{"choices":[{"delta":{"content":"_tool>"}}]}');
      expect(parser.finish().length).assertEqual(0);
    });

    it('emits each complete tagged task and preserves valid decision JSON', 0, () => {
      const parser: StreamingLeaderToolParser = new StreamingLeaderToolParser();
      const first: string = '{"localId":"time","goal":"read time","allowedToolIds":["time.query"],' +
        '"toolId":"time.query","input":{},"required":true}';
      const second: string = '{"localId":"food","goal":"find coffee","allowedToolIds":["food.search"],' +
        '"toolId":"food.search","input":{"place":"坂田","keyword":"咖啡"},"required":true}';
      const chunks: string[] = [
        '{"personaId":"default_companion","skillId":"","requestedCapabilityIds":' +
          '["time.query","food.search"],"roundAction":"execute","dataTasks":[<appless_',
        'tool>' + first.substring(0, 45),
        first.substring(45) + '</appless_to',
        'ol>,<appless_tool>' + second + '</appless_tool>],"uiIntent":{"purpose":"results",',
        '"preferredDensity":"comfortable","requiredSections":["time","food"]}}'
      ];
      let bodies: string[] = [];
      for (let index: number = 0; index < chunks.length; index++) {
        bodies = bodies.concat(parser.feed(chunks[index]));
      }
      expect(bodies.length).assertEqual(2);
      expect(bodies[0]).assertEqual(first);
      expect(bodies[1]).assertEqual(second);
      const normalized: string = parser.finish();
      const parsed = JSON.parse(normalized) as Record<string, Object>;
      const tasks = parsed['dataTasks'] as Object[];
      expect(tasks.length).assertEqual(2);
    });

    it('keeps a closing tag literal inside a task JSON string', 0, () => {
      const parser: StreamingLeaderToolParser = new StreamingLeaderToolParser();
      const body: string = '{"localId":"protocol","goal":"explain </appless_tool> framing",' +
        '"allowedToolIds":["time.query"],"toolId":"time.query","input":{},"required":true}';
      let bodies: string[] = parser.feed('<appless_tool>{"localId":"protocol","goal":"explain </appless_');
      expect(bodies.length).assertEqual(0);
      bodies = bodies.concat(parser.feed('tool> framing","allowedToolIds":["time.query"],' +
        '"toolId":"time.query","input":{},"required":true}</appless_tool>'));

      expect(bodies.length).assertEqual(1);
      expect(bodies[0]).assertEqual(body);
      expect(parser.finish()).assertEqual(body);
    });

    it('rejects an unfinished tool tag at stream end', 0, () => {
      const parser: StreamingLeaderToolParser = new StreamingLeaderToolParser();
      parser.feed('{"dataTasks":[<appless_tool>{"localId":"unfinished"}');
      let failed: boolean = false;
      try {
        parser.finish();
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
    });
  });
}
