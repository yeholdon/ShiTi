import { Module } from '@nestjs/common';
import { AgentTeamController } from './agent-team.controller';
import { AgentTeamService } from './agent-team.service';

@Module({
  controllers: [AgentTeamController],
  providers: [AgentTeamService]
})
export class AgentTeamModule {}
