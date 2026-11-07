// What the main process, the windows and the native helper say to each other.

export type Speaker = 'you' | 'them'

/** One line from the native helper. */
export type HelperEvent =
  | { type: 'ready'; locale: string; sources: Speaker[] }
  | { type: 'status'; message: string; progress?: number }
  | { type: 'level'; src: Speaker; rms: number }
  | { type: 'text'; src: Speaker; text: string; final: boolean; start: number; end: number }
  | { type: 'error'; src?: Speaker; message: string; fatal?: boolean }
  | { type: 'done' }

/** The candidate's own material. Answers are built only from this. */
export interface Profile {
  name: string
  targetRole: string
  company: string
  jobDescription: string
  resume: string
  stories: Story[]
  /** What to stress, what to avoid, salary and notice positions, anything else. */
  notes: string
  /** Names and terms the listener should expect: companies, tools, people. */
  words: string
}

export interface Story {
  id: string
  title: string
  text: string
}

export const emptyProfile = (): Profile => ({
  name: '',
  targetRole: '',
  company: '',
  jobDescription: '',
  resume: '',
  stories: [],
  notes: '',
  words: ''
})

export type AnswerSpeed = 'fast' | 'deep'

export interface EyeSettings {
  enabled: boolean
  /** How much of the gap to the camera is closed, 0 to 1. */
  strength: number
  /** How far a glance can go and still be corrected, as a share of eye width. Beyond it, eyes move naturally. */
  reach: number
  /** How much up-and-down correction, 0 to 1. Too much looks wrong. */
  vertical: number
  /** Where the eyes sit when looking into this camera, from calibration. */
  calibration: { u: number; v: number } | null
  cameraId: string | null
  mirror: boolean
}

export const defaultEye = (): EyeSettings => ({
  enabled: true,
  strength: 0.85,
  reach: 0.16,
  vertical: 0.5,
  calibration: null,
  cameraId: null,
  mirror: true
})

export interface Settings {
  speed: AnswerSpeed
  locale: string
  echoCancel: boolean
  /** Answer on its own when the interviewer finishes, or only on the shortcut. */
  autoAnswer: boolean
  /** Seconds of quiet that end the interviewer's turn. */
  quietSeconds: number
  eye: EyeSettings
}

export const defaultSettings = (): Settings => ({
  speed: 'fast',
  locale: 'en-GB',
  echoCancel: false,
  autoAnswer: true,
  quietSeconds: 0.9,
  eye: defaultEye()
})

/** A conversation line, as the brain sees it. */
export interface Exchange {
  speaker: Speaker
  text: string
}

export interface AnswerRequest {
  turnId: number
  question: string
  history: Exchange[]
}

/** Streamed to the windows while an answer is written. */
export type AnswerEvent =
  | { kind: 'start'; turnId: number; question: string; model: string }
  | { kind: 'delta'; turnId: number; text: string }
  | { kind: 'done'; turnId: number; text: string; firstMs: number; totalMs: number }
  | { kind: 'error'; turnId: number; message: string }

export type ListenState =
  | { state: 'off' }
  | { state: 'starting'; message?: string; progress?: number }
  | { state: 'on'; sources: Speaker[]; locale: string }
  | { state: 'failed'; message: string }

/** What the windows show of the conversation. */
export interface TranscriptLine {
  id: number
  speaker: Speaker
  text: string
  live: boolean
}
