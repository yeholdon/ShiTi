import { Body, Controller, Post } from '@nestjs/common';
import { AgentTeamService } from './agent-team.service';
import { TopicMap } from './agent-team.types';

@Controller('agent-team')
export class AgentTeamController {
  constructor(private readonly agentTeamService: AgentTeamService) {}

  @Post('mvp/run')
  runMvpFlow(
    @Body()
    body: {
      task?: string;
      topicMap?: Partial<TopicMap>;
    }
  ) {
    const task = body?.task?.trim() || '执行一个 MVP 流程测试';
    return this.agentTeamService.runMvpFlow(task, body?.topicMap);
  }
}
