import { AgentTeamService } from './agent-team.service';

describe('AgentTeamService', () => {
  it('routes coder and tester events to their own topics and posts final summary to control', () => {
    const service = new AgentTeamService();

    const result = service.runMvpFlow('扫描 Telegram topic MVP', {
      control: { chatId: 1, threadId: 101 },
      coder: { chatId: 1, threadId: 201 },
      tester: { chatId: 1, threadId: 202 }
    });

    expect(result.taskId).toMatch(/^task-\d{8}-\d{3}$/);
    expect(result.messages).toHaveLength(8);

    const controlMessages = result.messages.filter((message) => message.topic === 'control');
    const coderMessages = result.messages.filter((message) => message.topic === 'coder');
    const testerMessages = result.messages.filter((message) => message.topic === 'tester');

    expect(controlMessages).toHaveLength(2);
    expect(coderMessages).toHaveLength(3);
    expect(testerMessages).toHaveLength(3);

    expect(coderMessages.map((message) => message.threadId)).toEqual([201, 201, 201]);
    expect(testerMessages.map((message) => message.threadId)).toEqual([202, 202, 202]);
    expect(controlMessages.map((message) => message.threadId)).toEqual([101, 101]);

    expect(coderMessages[0].text).toContain('[Coder] 已启动');
    expect(coderMessages[1].text).toContain('[Coder] 进度');
    expect(coderMessages[2].text).toContain('[Coder] 完成');

    expect(testerMessages[0].text).toContain('[Tester] 已启动');
    expect(testerMessages[1].text).toContain('[Tester] 进度');
    expect(testerMessages[2].text).toContain('[Tester] 完成');

    expect(controlMessages[0].text).toContain('任务已创建');
    expect(controlMessages[1].text).toContain('任务完成');
    expect(controlMessages[1].text).toContain('MVP 消息链路已跑通');
    expect(result.finalSummary).toContain('MVP 消息链路已跑通');
  });
});
