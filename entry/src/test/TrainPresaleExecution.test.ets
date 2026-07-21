import { describe, expect, it } from '@ohos/hypium';
import {
  decideTrainPresaleExecution,
  TrainPresaleAvailabilityCheck,
  TrainPresaleExecutionDecision,
  TrainPresaleExecutionTask
} from '@loop/agent-core';
import {
  claimDueTrainPresaleTask,
  TrainPresaleTask,
  TrainPresaleTaskState
} from '../main/ets/pages/A2uiHome/train/TrainPresaleTaskStore';

function task(state: TrainPresaleTaskState = 'scheduled'): TrainPresaleTask {
  return {
    taskId: 'task-1',
    source: 'presale',
    state: state,
    trainCode: 'G1',
    travelDate: '2026-08-06',
    fromName: '北京南',
    fromCode: 'VNP',
    toName: '上海虹桥',
    toCode: 'AOH',
    saleAt: '2026-07-22T12:45:00+08:00',
    passengerNames: ['张三'],
    seatPriority: '二等座',
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init?date=2026-08-06',
    reminderId: 73,
    createdAt: '2026-07-21T10:00:00+08:00',
    lastError: ''
  };
}

function executionTask(value: TrainPresaleTask): TrainPresaleExecutionTask {
  return {
    state: value.state,
    trainCode: value.trainCode,
    travelDate: value.travelDate,
    fromName: value.fromName,
    fromCode: value.fromCode,
    toName: value.toName,
    toCode: value.toCode,
    seatPriority: value.seatPriority
  };
}

function availability(
  status: 'verified' | 'sold_out' | 'provider_error' | 'mismatch' | 'unsupported_seat',
  reason: string = ''
): TrainPresaleAvailabilityCheck {
  return {
    status: status,
    reason: reason,
    trainCode: 'G1',
    travelDate: '2026-08-06',
    fromCode: 'VNP',
    toCode: 'AOH',
    seatPriority: '二等座',
    bookingUrl: 'https://kyfw.12306.cn/otn/leftTicket/init?linktypeid=dc&fs=%E5%8C%97%E4%BA%AC%E5%8D%97,VNP&ts=%E4%B8%8A%E6%B5%B7%E8%99%B9%E6%A1%A5,AOH&date=2026-08-06&flag=N,N,Y'
  };
}

export default function trainPresaleExecutionTest() {
  describe('trainPresaleExecution', () => {
    it('claims a due scheduled task once but not an executing or cancelled task', 0, () => {
      const due = claimDueTrainPresaleTask([task()], '2026-07-22T12:45:00+08:00', 'task-1');
      const claimedAgain = claimDueTrainPresaleTask(due.tasks, '2026-07-22T12:45:01+08:00', 'task-1');
      const cancelled = claimDueTrainPresaleTask([task('cancelled')], '2026-07-22T12:45:01+08:00', 'task-1');

      expect(due.task?.state).assertEqual('executing');
      expect(claimedAgain.task).assertEqual(undefined);
      expect(cancelled.task).assertEqual(undefined);
    });

    it('requires the user when the requested seat is sold out', 0, () => {
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(task('executing')), availability('sold_out', 'G1 二等座当前无票。'));

      expect(decision.state).assertEqual('needs_user');
      expect(decision.reason).assertEqual('G1 二等座当前无票。');
      expect(decision.bookingUrl).assertEqual('');
    });

    it('preserves the real provider error for user attention', 0, () => {
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(task('executing')), availability('provider_error', '12306 返回 HTTP 503。'));

      expect(decision.state).assertEqual('needs_user');
      expect(decision.reason).assertEqual('12306 返回 HTTP 503。');
    });

    it('rejects a train date or route mismatch', 0, () => {
      const mismatched = availability('verified');
      mismatched.trainCode = 'G3';
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(task('executing')), mismatched);

      expect(decision.state).assertEqual('needs_user');
      expect(decision.reason.indexOf('不匹配') >= 0).assertTrue();
    });

    it('rejects an unsupported requested seat', 0, () => {
      const requested = task('executing');
      requested.seatPriority = '软卧';
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(requested), availability('unsupported_seat', '当前不支持核验席别：软卧。'));

      expect(decision.state).assertEqual('needs_user');
      expect(decision.reason).assertEqual('当前不支持核验席别：软卧。');
    });

    it('keeps verified availability executing and returns only the official booking URL', 0, () => {
      const check = availability('verified');
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(
        executionTask(task('executing')), check);

      expect(decision.state).assertEqual('executing');
      expect(decision.reason).assertEqual('');
      expect(decision.bookingUrl).assertEqual(check.bookingUrl);
    });
  });
}
