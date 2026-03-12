export type AgentTeamRole = 'main' | 'coder' | 'tester';
export type AgentTeamTopicAlias = 'control' | 'coder' | 'tester';
export type AgentTeamEventType = 'agent_started' | 'agent_progress' | 'agent_result';

export interface AgentTeamEvent {
  type: AgentTeamEventType;
  taskId: string;
  agent: Exclude<AgentTeamRole, 'main'>;
  summary: string;
  result?: Record<string, unknown>;
}

export interface TopicTarget {
  chatId: number;
  threadId: number;
}

export interface TopicMap {
  control: TopicTarget;
  coder: TopicTarget;
  tester: TopicTarget;
}

export interface TopicMessage {
  topic: AgentTeamTopicAlias;
  chatId: number;
  threadId: number;
  text: string;
}

export interface AgentExecutionPlan {
  started: string;
  progress: string;
  result: string;
  payload?: Record<string, unknown>;
}

export interface AgentTeamRunResult {
  taskId: string;
  topicMap: TopicMap;
  messages: TopicMessage[];
  finalSummary: string;
}
