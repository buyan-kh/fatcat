import { useEffect, useMemo, useState } from 'react'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import { avatarAnimationForState, transitionState, type CompanionState } from '../lib/companion'
import { decideInterruption } from '../lib/interruption'
import { appendMemory, createEmptyMemory, deleteMemory, readMemory, writeMemory, type LayeredMemory, type MemoryLayer } from '../lib/memory'
import { addGoal, createGoal, readGoals, writeGoals, type Goal } from '../lib/goals'
import { buildObservation, type ScreenObservation } from '../lib/observation'
import { enforceAction, type ActionRequest } from '../lib/risk'
import { verifyAction } from '../lib/verification'
import { applyNativePrivacyConfig, getNativeBridge, isCaptureActive, subscribeNativeCaptureStatus, subscribeNativeObservations, type NativeCaptureStatus } from '../lib/native-bridge'
import { createLearningRecord, readLearningRecords, writeLearningRecords, type LearningRecord } from '../lib/learning'
import { PeppaCompanionAvatar } from './PeppaCompanionAvatar'

type CompanionDashboardProps = { definition: Readonly<AvatarDefinition> }

const inspectAction: ActionRequest = { id: 'inspect-context', kind: 'inspect_state', label: 'Inspect current context', expectedResult: 'context structured locally' }
const typeAction: ActionRequest = { id: 'type-summary', kind: 'type_text', label: 'Type a summary into a document', detail: 'Medium risk · requires approval', expectedResult: 'summary typed into document' }

const defaultObservation = buildObservation({
  activeApp: 'Safari',
  visibleWindow: 'Prep study session',
  task: 'Review the next practice question',
  detectedEvent: 'none',
  repeatedActivity: 'Opening the same study page twice',
  likelyUserState: 'focused',
  confidence: 0.91,
})

function timestamp() { return new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }

export function CompanionDashboard({ definition }: CompanionDashboardProps) {
  const [state, setState] = useState<CompanionState>('idle')
  const [paused, setPaused] = useState(false)
  const [observing, setObserving] = useState(true)
  const [nativeCaptureStatus, setNativeCaptureStatus] = useState<NativeCaptureStatus>()
  const [permissionStatus, setPermissionStatus] = useState('Local demo context is active.')
  const [observation, setObservation] = useState<ScreenObservation>(defaultObservation)
  const [privateApps, setPrivateApps] = useState(['1Password', 'Messages'])
  const [privateAppDraft, setPrivateAppDraft] = useState('')
  const [memory, setMemory] = useState<LayeredMemory>(() => typeof window === 'undefined' ? createEmptyMemory() : readMemory(window.localStorage))
  const [goals, setGoals] = useState<Goal[]>(() => typeof window === 'undefined' ? [] : readGoals(window.localStorage))
  const [learningRecords, setLearningRecords] = useState<LearningRecord[]>(() => typeof window === 'undefined' ? [] : readLearningRecords(window.localStorage))
  const [activeMemoryLayer, setActiveMemoryLayer] = useState<MemoryLayer>('semantic')
  const [correction, setCorrection] = useState('')
  const [approvalQueue, setApprovalQueue] = useState<ActionRequest[]>([typeAction])
  const [history, setHistory] = useState<string[]>(['Observation started · local-only'])
  const [lastVerification, setLastVerification] = useState('No action has run yet.')
  const native = useMemo(() => getNativeBridge(), [])

  useEffect(() => {
    if (typeof window !== 'undefined') {
      writeMemory(window.localStorage, memory)
      writeGoals(window.localStorage, goals)
      writeLearningRecords(window.localStorage, learningRecords)
    }
  }, [memory, goals, learningRecords])

  useEffect(() => subscribeNativeObservations((next) => {
    if (!observing || !isCaptureActive(native !== undefined, nativeCaptureStatus, observing)) return
    setObservation(next)
    setPermissionStatus('ScreenCaptureKit is delivering structured local context.')
    setHistory((current) => [`${timestamp()} · Native observation received`, ...current].slice(0, 6))
  }), [native, nativeCaptureStatus, observing])

  useEffect(() => subscribeNativeCaptureStatus((next) => {
    setNativeCaptureStatus(next)
    setPermissionStatus(next.status)
  }), [])

  useEffect(() => {
    applyNativePrivacyConfig(native, privateApps)
  }, [native, privateApps])

  function move(next: CompanionState, reason: string) {
    setState((current) => transitionState(current, next, reason).state)
  }

  function requestPermission() {
    move('asking_permission', 'screen recording permission requested')
    if (native?.requestScreenAccess) {
      native.requestScreenAccess()
      setPermissionStatus('Permission request sent to macOS. Approve Screen Recording in System Settings, then observe again.')
    } else {
      setPermissionStatus('Native host unavailable; demo mode remains local and does not capture your screen.')
    }
  }

  function observeNow() {
    if (!observing) return
    move('listening', 'new local observation')
    const next = buildObservation({ ...defaultObservation, privateApps })
    setObservation(next)
    setPermissionStatus(native ? 'Native host connected; structured context stays local.' : 'Local demo context refreshed; no screenshot retained.')
    setHistory((current) => [`${timestamp()} · Saw ${next.activeApp} · ${next.task}`, ...current].slice(0, 6))
    window.setTimeout(() => move('understanding', 'structured context ready'), 350)
  }

  function runInspect() {
    const enforcement = enforceAction(inspectAction, false)
    if (!enforcement.allowed) return
    move('acting', 'low-risk inspection approved autonomously')
    setHistory((current) => [`${timestamp()} · Inspected structured context`, ...current].slice(0, 6))
    window.setTimeout(() => {
      move('verifying', 'inspection result returned')
      const result = verifyAction({ expected: inspectAction.expectedResult ?? '', observed: 'context structured locally', confidence: 0.96 })
      setLastVerification(result.verified ? 'Verified: observation is structured locally; no raw screenshot was retained.' : result.difference)
      setLearningRecords((current) => [...current, createLearningRecord({
        plan: 'Inspect the current structured screen context',
        action: inspectAction.label,
        observedResult: 'context structured locally',
        expectedResult: inspectAction.expectedResult ?? '',
        difference: result.difference,
        correction: result.verified ? 'Keep raw screenshots disabled by default.' : 'Do not reuse this workflow until the difference is resolved.',
        reusableLesson: result.verified ? 'Local structured observation is enough for a low-risk context check.' : 'This workflow is unreliable until verification succeeds.',
      })].slice(-10))
      if (result.verified) {
        move('celebrating', 'critic verified the observed result')
        setHistory((current) => [`${timestamp()} · Verified success · FatCat celebrated`, ...current].slice(0, 6))
        setMemory((current) => appendMemory(current, 'episodic', { id: `lesson-${Date.now()}`, content: 'Structured local observation completed and verified.', createdAt: new Date().toISOString(), source: 'learning_record' }))
      } else move('recovering', 'observed result differed')
    }, 700)
  }

  function approveAction(action: ActionRequest) {
    const enforcement = enforceAction(action, true)
    if (!enforcement.allowed) {
      setHistory((current) => [`${timestamp()} · Blocked ${action.label} · ${enforcement.reason}`, ...current].slice(0, 6))
      return
    }
    setApprovalQueue((current) => current.filter((item) => item.id !== action.id))
    move('acting', 'user approved medium-risk action')
    setHistory((current) => [`${timestamp()} · Approved ${action.label}`, ...current].slice(0, 6))
    window.setTimeout(() => {
      move('verifying', 'approved action returned')
      setLastVerification('Prepared only: this browser MVP does not type into another app. Native action adapters remain disabled.')
      move('recovering', 'action adapter is unavailable')
    }, 500)
  }

  function addCorrection(layer: MemoryLayer) {
    const content = correction.trim()
    if (!content) return
    setMemory((current) => appendMemory(current, layer, { id: `memory-${Date.now()}`, content, createdAt: new Date().toISOString(), source: 'user_correction' }))
    setCorrection('')
    setHistory((current) => [`${timestamp()} · Saved correction to ${layer}`, ...current].slice(0, 6))
  }

  function addPrivateApp() {
    const app = privateAppDraft.trim()
    if (!app || privateApps.includes(app)) return
    setPrivateApps((current) => [...current, app])
    setPrivateAppDraft('')
  }

  function removePrivateApp(app: string) {
    setPrivateApps((current) => current.filter((item) => item !== app))
  }

  function addDefaultGoal() {
    setGoals((current) => addGoal(current, createGoal({ goal: 'Keep the study session moving', priority: 'high', successCondition: 'A useful next practice question is ready' })))
  }

  function toggleObservation() {
    setObserving((current) => {
      native?.setObservationPaused?.(current)
      return !current
    })
  }

  const interruption = decideInterruption({ reason: 'verified_completion', confidence: observation.confidence, inCooldown: false, userIsTyping: observation.likelyUserState === 'typing', inMeeting: observation.likelyUserState === 'meeting' })
  const activeEntries = memory[activeMemoryLayer]
  const captureActive = isCaptureActive(native !== undefined, nativeCaptureStatus, observing)

  return (
    <>
      <section className="companion-hero" aria-labelledby="companion-heading">
        <div className="companion-copy">
          <p className="eyebrow">FatCat · local companion MVP</p>
          <h1 id="companion-heading">A small presence<br /><i>that earns trust.</i></h1>
          <p className="companion-lede">FatCat sees structured context, understands what it means, and helps only when the next step is safe and relevant.</p>
          <div className="companion-actions"><button className="button button-accent" type="button" onClick={observeNow} disabled={!captureActive}>Observe now</button><button className="button button-secondary" type="button" onClick={toggleObservation}>{observing ? 'Pause observation' : 'Resume observation'}</button></div>
        </div>
        <PeppaCompanionAvatar definition={definition} state={state} paused={paused} onPauseChange={setPaused} />
      </section>

      <section className="trust-strip" aria-label="Trust status">
        <div className={`trust-status ${captureActive ? 'is-on' : 'is-off'}`}><span className="trust-pulse" /> <strong>{captureActive ? 'Observing' : 'Paused'}</strong><span>{captureActive ? 'structured context only' : native ? 'capture is stopped' : 'FatCat is quiet'}</span></div>
        <div><span className="trust-label">Mode</span><strong>Local-only</strong></div>
        <div><span className="trust-label">Raw screenshots</span><strong>Permanently off</strong></div>
        <div><span className="trust-label">Native host</span><strong>{native ? 'Connected' : 'Demo mode'}</strong></div>
      </section>

      <section className="companion-grid" aria-label="FatCat controls and context">
        <article className="companion-card observation-card">
          <div className="card-heading"><div><p className="eyebrow">01 · Perception</p><h2>What FatCat saw</h2></div><span className="card-status">{observation.confidence.toFixed(2)} confidence</span></div>
          <div className="observation-readout"><div><span>Active app</span><strong>{observation.activeApp}</strong></div><div><span>Window / task</span><strong>{observation.visibleWindow} · {observation.task}</strong></div><div><span>Detected event</span><strong>{observation.detectedEvent}</strong></div><div><span>Repeated activity</span><strong>{observation.repeatedActivity}</strong></div><div><span>Likely state</span><strong>{observation.likelyUserState}</strong></div></div>
          <div className="privacy-note"><span className="privacy-lock">⌑</span><div><strong>{observation.privacy.redacted ? 'Private context redacted' : 'No raw screenshot retained'}</strong><p>{observation.privacy.reason}</p></div></div>
          <div className="card-actions"><button className="button button-secondary" type="button" onClick={requestPermission}>Request Screen Recording</button><span>{permissionStatus}</span></div>
          <div className="privacy-controls">
            <div className="privacy-toggle privacy-toggle-static"><span className="privacy-check">✓</span> Raw screenshot retention is permanently off <span>(MVP policy)</span></div>
            <div className="private-app-heading"><span className="trust-label">Private-app exclusions</span><span>redact before memory</span></div>
            <div className="private-app-list">{privateApps.map((app) => <button key={app} type="button" onClick={() => removePrivateApp(app)}>{app} ×</button>)}</div>
            <div className="private-app-add"><input value={privateAppDraft} onChange={(event) => setPrivateAppDraft(event.target.value)} placeholder="Add an app…" aria-label="Add private app" /><button type="button" onClick={addPrivateApp}>Add</button></div>
          </div>
        </article>

        <article className="companion-card action-card">
          <div className="card-heading"><div><p className="eyebrow">02 · Agency</p><h2>Safe next steps</h2></div><span className="card-status">{approvalQueue.length} awaiting approval</span></div>
          <div className="action-item action-item-safe"><div><strong>{inspectAction.label}</strong><span>Low risk · autonomous</span></div><button className="button button-accent" type="button" onClick={runInspect}>Run</button></div>
          {approvalQueue.map((action) => <div className="action-item" key={action.id}><div><strong>{action.label}</strong><span>{action.detail}</span></div><button className="button button-secondary" type="button" onClick={() => approveAction(action)}>Approve</button></div>)}
          <div className="risk-rules"><span><b>Low</b> inspect / explain / highlight · may run</span><span><b>Medium</b> type / edit / move · approval</span><span><b>High</b> send / delete / spend · always blocked here</span></div>
          <div className="verification-readout"><span className="trust-label">Critic / verification</span><p>{lastVerification}</p></div>
        </article>

        <article className="companion-card goals-card">
          <div className="card-heading"><div><p className="eyebrow">03 · Goals</p><h2>What matters now</h2></div><button className="button button-quiet" type="button" onClick={addDefaultGoal}>+ Add goal</button></div>
          {goals.length === 0 ? <div className="empty-state"><strong>No personal goals yet.</strong><p>FatCat will check goals before deciding whether to respond.</p></div> : goals.map((goal) => <div className="goal-item" key={goal.id}><div className="goal-priority">{goal.priority}</div><div><strong>{goal.goal}</strong><span>{goal.currentState} · next: {goal.nextAction}</span><small>Success: {goal.successCondition}</small></div></div>)}
        </article>

        <article className="companion-card memory-card">
          <div className="card-heading"><div><p className="eyebrow">04 · Memory</p><h2>Inspectable, deletable</h2></div><span className="card-status">local storage</span></div>
          <div className="memory-tabs" role="tablist" aria-label="Memory layers">{(['shortTerm', 'episodic', 'semantic', 'procedural'] as MemoryLayer[]).map((layer) => <button key={layer} className={activeMemoryLayer === layer ? 'is-active' : ''} type="button" role="tab" aria-selected={activeMemoryLayer === layer} onClick={() => setActiveMemoryLayer(layer)}>{layer === 'shortTerm' ? 'Short term' : layer}</button>)}</div>
          <div className="memory-list">{activeEntries.length === 0 ? <p className="muted-copy">Nothing stored here yet.</p> : activeEntries.map((entry) => <div className="memory-entry" key={entry.id}><div><strong>{entry.content}</strong><span>{entry.source} · {new Date(entry.createdAt).toLocaleDateString()}</span></div><button type="button" aria-label={`Delete memory: ${entry.content}`} onClick={() => setMemory((current) => deleteMemory(current, entry.id))}>Delete</button></div>)}</div>
          <div className="memory-compose"><input value={correction} onChange={(event) => setCorrection(event.target.value)} placeholder="Store a correction or preference…" aria-label="New memory entry" /><button className="button button-secondary" type="button" onClick={() => addCorrection(activeMemoryLayer)}>Remember</button></div>
        </article>
      </section>

      <section className="explanation-panel" aria-labelledby="explanation-heading">
        <div><p className="eyebrow">Trust receipt</p><h2 id="explanation-heading">What FatCat saw, and why it acted</h2><p>Every response is grounded in a local observation, a goal check, and a risk decision. {interruption.interrupt ? 'This result is actionable and may interrupt.' : interruption.reason}</p></div>
        <div className="receipt-steps"><div><span>1</span><strong>Observe</strong><small>{observation.activeApp} · {observation.timestamp ? new Date(observation.timestamp).toLocaleTimeString() : 'now'}</small></div><div><span>2</span><strong>Decide</strong><small>{avatarAnimationForState[state].label} · {state}</small></div><div><span>3</span><strong>Remember</strong><small>{history[0]}</small></div></div>
      </section>

      <section className="history-panel" aria-labelledby="history-heading"><div className="history-heading"><div><p className="eyebrow">Audit trail</p><h2 id="history-heading">Recent actions</h2></div><span>{history.length} local events</span></div><div className="history-list">{history.map((item, index) => <div key={`${item}-${index}`}><span className="history-dot" />{item}</div>)}</div><div className="learning-summary"><span className="trust-label">Learning record · {learningRecords.length} stored</span><span>{learningRecords.at(-1)?.reusableLesson ?? 'Verified actions will record plan, result, difference, correction, and reusable lesson.'}</span></div></section>

      <button className="lab-toggle" type="button" onClick={() => document.getElementById('avatar-lab')?.scrollIntoView({ behavior: 'smooth' })}>Jump to preserved FatCat avatar lab <span>↘</span></button>
    </>
  )
}
