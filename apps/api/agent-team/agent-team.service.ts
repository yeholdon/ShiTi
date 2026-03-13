import { Injectable } from '@nestjs/common';
import {
  AgentExecutionPlan,
  AgentTeamEvent,
  AgentTeamRunResult,
  TopicMap,
  TopicMessage
} from './agent-team.types';

@Injectable()
export class AgentTeamService {
  runMvpFlow(task: string, topicMap?: Partial<TopicMap>): AgentTeamRunResult {
    const taskId = this.createTaskId();
    const resolvedTopicMap = this.resolveTopicMap(topicMap);
    const messages: TopicMessage[] = [];

    messages.push(this.renderControlMessage(resolvedTopicMap, taskId, `任务已创建\n\n目标：${task}`));

    const coderPlan = this.buildCoderPlan(task);
    const testerPlan = this.buildTesterPlan(task);

    this.emitAgentFlow(messages, resolvedTopicMap, taskId, 'coder', coderPlan);
    this.emitAgentFlow(messages, resolvedTopicMap, taskId, 'tester', testerPlan);

    const finalSummary = [
      `[${taskId}] 任务完成`,
      '',
      'Coder:',
      `- ${coderPlan.result}`,
      '',
      'Tester:',
      `- ${testerPlan.result}`,
      '',
      '结论：',
      'MVP 消息链路已跑通：子 agent 事件先回 parent，再由 parent 路由到角色 topic，最终回到 Control。'
    ].join('\n');

    messages.push(this.renderControlMessage(resolvedTopicMap, taskId, finalSummary));

    return {
      taskId,
      topicMap: resolvedTopicMap,
      messages,
      finalSummary
    };
  }

  private emitAgentFlow(
    messages: TopicMessage[],
    topicMap: TopicMap,
    taskId: string,
    agent: 'coder' | 'tester',
    plan: AgentExecutionPlan
  ) {
    const events: AgentTeamEvent[] = [
      {
        type: 'agent_started',
        taskId,
        agent,
        summary: plan.started
      },
      {
        type: 'agent_progress',
        taskId,
        agent,
        summary: plan.progress
      },
      {
        type: 'agent_result',
        taskId,
        agent,
        summary: plan.result,
        result: plan.payload
      }
    ];

    for (const event of events) {
      messages.push(this.renderAgentEvent(topicMap, event));
    }
  }

  private renderControlMessage(topicMap: TopicMap, taskId: string, text: string): TopicMessage {
    return {
      topic: 'control',
      chatId: topicMap.control.chatId,
      threadId: topicMap.control.threadId,
      text: text.startsWith(`[${taskId}]`) ? text : `[${taskId}]\n${text}`
    };
  }

  private renderAgentEvent(topicMap: TopicMap, event: AgentTeamEvent): TopicMessage {
    const target = topicMap[event.agent];
    const phaseLabel =
      event.type === 'agent_started' ? '已启动' : event.type === 'agent_progress' ? '进度' : '完成';

    return {
      topic: event.agent,
      chatId: target.chatId,
      threadId: target.threadId,
      text: [`[${this.capitalize(event.agent)}] ${phaseLabel}`, event.summary].join('\n')
    };
  }

  private buildCoderPlan(task: string): AgentExecutionPlan {
    return {
      started: '开始扫描项目中与 Telegram / topic / thread 相关的实现入口。',
      progress: '已锁定可落地位置：新增独立 agent-team 模块，不侵入现有题库业务模块。',
      result: `已为任务“${task}”生成 MVP 编排链路所需的最小实现骨架。`,
      payload: {
        focus: ['module', 'controller', 'service'],
        strategy: 'parent-mediated-topic-routing'
      }
    };
  }

  private buildTesterPlan(task: string): AgentExecutionPlan {
    return {
      started: '开始为 MVP 链路准备最小验证路径。',
      progress: '已确认验证重点：Control 建任务、Coder/Tester topic 收到三类事件、Control 收到最终汇总。',
      result: `已为任务“${task}”生成 focused spec，覆盖 parent 路由与最终汇总。`,
      payload: {
        checks: ['control-start', 'coder-events', 'tester-events', 'control-final']
      }
    };
  }

  private resolveTopicMap(topicMap?: Partial<TopicMap>): TopicMap {
    return {
      control: topicMap?.control ?? { chatId: -1000000000000, threadId: 101 },
      coder: topicMap?.coder ?? { chatId: -1000000000000, threadId: 201 },
      tester: topicMap?.tester ?? { chatId: -1000000000000, threadId: 202 }
    };
  }

  private createTaskId() {
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = String(now.getUTCMonth() + 1).padStart(2, '0');
    const d = String(now.getUTCDate()).padStart(2, '0');
    const random = Math.floor(Math.random() * 1000)
      .toString()
      .padStart(3, '0');
    return `task-${y}${m}${d}-${random}`;
  }

  private capitalize(value: string) {
    return value.charAt(0).toUpperCase() + value.slice(1);
  }
}
