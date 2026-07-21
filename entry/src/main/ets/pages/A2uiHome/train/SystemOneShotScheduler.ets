import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { TrainPresaleTask } from './TrainPresaleTaskStore';

const BUNDLE_NAME: string = 'com.example.aiphonedemo';
const ABILITY_NAME: string = 'EntryAbility';

export function buildReminderRequest(
  task: TrainPresaleTask,
  fireAt: string
): reminderAgentManager.ReminderRequestCalendar {
  const fireDate = new Date(fireAt);
  if (isNaN(fireDate.getTime())) {
    throw new Error('Invalid reminder time');
  }
  return {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
    dateTime: {
      year: fireDate.getFullYear(),
      month: fireDate.getMonth() + 1,
      day: fireDate.getDate(),
      hour: fireDate.getHours(),
      minute: fireDate.getMinutes(),
      second: fireDate.getSeconds()
    },
    wantAgent: {
      pkgName: BUNDLE_NAME,
      abilityName: ABILITY_NAME,
      parameters: { trainPresaleTaskId: task.taskId }
    },
    maxScreenWantAgent: {
      pkgName: BUNDLE_NAME,
      abilityName: ABILITY_NAME
    },
    title: task.trainCode + ' 开售提醒',
    content: task.fromName + ' → ' + task.toName + ' 即将开售',
    tapDismissed: true
  };
}

export class SystemOneShotScheduler {
  async schedule(task: TrainPresaleTask, fireAt: string): Promise<number> {
    const reminderId = await reminderAgentManager.publishReminder(buildReminderRequest(task, fireAt));
    task.reminderId = reminderId;
    return reminderId;
  }

  async cancel(reminderId: number): Promise<void> {
    await reminderAgentManager.cancelReminder(reminderId);
  }

  async list(): Promise<reminderAgentManager.ReminderRequest[]> {
    return reminderAgentManager.getValidReminders();
  }
}
