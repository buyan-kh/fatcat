import type { Goal } from './goals'
import type { LayeredMemory, MemoryEntry } from './memory'
import type { ScreenObservation } from './observation'
import type { ActionRequest } from './risk'
import { verifyAction, type VerificationResult } from './verification'

export type DialogueDecision = { shouldRespond: boolean; reason: string }
export type Plan = { goalId: string; steps: string[]; expectedResult: string }
export type ActionResult = { observedResult: string; confidence: number }

export interface PerceptionAdapter { observe(): Promise<ScreenObservation> }
export interface DialogueAdapter { decideResponse(observation: ScreenObservation, goals: Goal[]): DialogueDecision }
export interface PlannerAdapter { plan(goal: Goal, observation: ScreenObservation): Plan }
export interface ActionAdapter { execute(action: ActionRequest): Promise<ActionResult> }
export interface CriticAdapter { verify(expected: string, result: ActionResult): VerificationResult }
export interface MemoryAdapter { read(): LayeredMemory; remember(layer: keyof LayeredMemory, entry: MemoryEntry): void; delete(id: string): void }
export interface LocalClassifier { classify(observation: ScreenObservation): { label: ScreenObservation['likelyUserState']; confidence: number } }

export class CheapLocalClassifier implements LocalClassifier {
  classify(observation: ScreenObservation) {
    const task = `${observation.task} ${observation.visibleWindow}`.toLowerCase()
    const label: ScreenObservation['likelyUserState'] = task.includes('meeting') ? 'meeting' : task.includes('type') || task.includes('editor') ? 'typing' : observation.activeApp === 'Unknown app' ? 'unknown' : 'focused'
    return { label, confidence: observation.confidence }
  }
}

export class LocalCritic implements CriticAdapter {
  verify(expected: string, result: ActionResult) { return verifyAction({ expected, observed: result.observedResult, confidence: result.confidence }) }
}
