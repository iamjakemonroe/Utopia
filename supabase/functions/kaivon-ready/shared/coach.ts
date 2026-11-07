// Coach: gets the candidate ready for interviews in their own line of work.
// What to know, the common questions with strong answers, and practice out
// loud with honest feedback on what they said and how they said it.

import type { Profile } from './types.ts'

export interface Topic {
  title: string
  /** Why interviewers in this field care about it. */
  why: string
  /** What a strong candidate can explain. */
  points: string[]
  sampleQuestion: string
}

export type QuestionKind = 'personal' | 'behavioural' | 'knowledge' | 'situational'

export interface CommonQuestion {
  id: string
  question: string
  kind: QuestionKind
  whyAsked: string
  /** The opening line to say. */
  say: string
  points: string[]
  tip: string
  /** True when the model answer had to leave gaps for the candidate's own example. */
  needsStory: boolean
}

export interface FieldPlan {
  field: string
  level: string
  summary: string
  topics: Topic[]
  questions: CommonQuestion[]
  /** How people in this field are expected to speak in interviews. */
  speaking: string[]
  builtAt: number
  sample?: boolean
}

export interface Delivery {
  words: number
  seconds: number
  wordsPerMinute: number
  fillers: { word: string; count: number }[]
  fillerCount: number
  hedges: number
  /** Longest gap between phrases, in seconds. */
  longestPause: number
}

export interface Feedback {
  scores: { answered: number; structure: number; specifics: number; delivery: number }
  strengths: string[]
  fixes: string[]
  better: string
}

export interface Attempt {
  id: string
  question: string
  transcript: string
  delivery: Delivery
  feedback: Feedback | null
  at: number
}

export interface CoachState {
  plan: FieldPlan | null
  attempts: Attempt[]
}

// ---------- How they spoke ----------

const FILLERS = ['um', 'uh', 'ah', 'erm', 'er', 'hmm', 'you know', 'i mean', 'basically', 'actually', 'literally', 'so yeah']
const HEDGES = ['i think', 'i guess', 'maybe', 'probably', 'i feel like', 'kind of', 'sort of', 'a little bit', 'i suppose', 'hopefully']

function count(text: string, phrase: string): number {
  const re = new RegExp(`(^|[^\\p{L}'])${phrase.replace(/ /g, '\\s+')}(?=$|[^\\p{L}'])`, 'giu')
  return (text.match(re) ?? []).length
}

/**
 * Measures delivery from what the listener heard: pace, filler words, hedging
 * and pauses. [segments] carry audio times in seconds.
 */
export function delivery(segments: { text: string; start: number; end: number }[], seconds?: number): Delivery {
  const text = segments.map((s) => s.text).join(' ')
  const lower = text.toLowerCase()
  const words = lower.split(/\s+/).filter((w) => /\p{L}|\p{N}/u.test(w)).length
  const first = segments[0]?.start ?? 0
  const last = segments[segments.length - 1]?.end ?? 0
  const spoken = seconds ?? Math.max(0, last - first)
  const fillers = FILLERS.map((word) => ({ word, count: count(lower, word) })).filter((f) => f.count > 0)
  // "like" is often a real word ("I'd like to"); count it only where it fills a gap.
  const likes = (lower.match(/(?:^|[,.]\s*|\b(?:um|uh|and|so|was)\s+)like\b|\blike,/g) ?? []).length
  if (likes) fillers.push({ word: 'like', count: likes })
  const adjusted = fillers.sort((a, b) => b.count - a.count)
  let longestPause = 0
  for (let i = 1; i < segments.length; i++) longestPause = Math.max(longestPause, segments[i]!.start - segments[i - 1]!.end)
  return {
    words,
    seconds: Math.round(spoken * 10) / 10,
    wordsPerMinute: spoken > 3 ? Math.round((words / spoken) * 60) : 0,
    fillers: adjusted,
    fillerCount: adjusted.reduce((s, f) => s + f.count, 0),
    hedges: HEDGES.reduce((s, h) => s + count(lower, h), 0),
    longestPause: Math.round(Math.max(0, longestPause) * 10) / 10
  }
}

/** Plain advice from the numbers alone, before Claude says anything. */
export function deliveryNotes(d: Delivery): string[] {
  const out: string[] = []
  if (d.words < 25) out.push('Very short. Most answers need 45 seconds to 2 minutes.')
  else if (d.seconds > 150) out.push('Long. Aim to finish in about two minutes, then let them ask more.')
  if (d.wordsPerMinute > 175) out.push(`Fast, at ${d.wordsPerMinute} words a minute. Slow down to about 140 to 160.`)
  else if (d.wordsPerMinute > 0 && d.wordsPerMinute < 110) out.push(`Slow, at ${d.wordsPerMinute} words a minute. Aim for about 140 to 160.`)
  const per100 = d.words ? (d.fillerCount / d.words) * 100 : 0
  if (per100 >= 3) out.push(`${d.fillerCount} filler words. Try a short silent pause instead.`)
  if (d.hedges >= 3) out.push(`${d.hedges} hedges, like "I think" or "maybe". Say what you did plainly.`)
  if (d.longestPause >= 4) out.push(`A ${d.longestPause}-second pause. Fine to think, but say "let me think for a second" first.`)
  if (out.length === 0) out.push('Clear pace and few fillers. Good delivery.')
  return out
}

// ---------- What Claude is told ----------

export const PLAN_INSTRUCTIONS = `You are Kaivon Ready's coach. Build an interview preparation plan for this candidate, for the exact line of work and level they are applying for. Work out the field and level from the role, the job description and their resume.

The plan has:
- field and level: short names, like "Frontend engineering" and "Senior".
- summary: two or three sentences on what interviews in this field test, and what usually separates strong candidates.
- topics: 8 to 10 things they must know for this field and level, most important first. For each: why interviewers care, 3 to 5 points a strong candidate can explain clearly and correctly, and one realistic sample question.
- questions: 14 to 16 common interview questions for this field and level, mixing personal ("tell me about yourself", "why this role"), behavioural ("a time you..."), knowledge (field-specific, technical or professional), and situational ("what would you do if..."). For each: why it's asked, a model answer, and one tip.
- speaking: 4 to 6 short pieces of advice on how to speak in interviews for this field: tone, structure, level of detail, words to use or avoid.

Model answers:
- "say" is the opening line, first person, natural spoken English. "points" are 3 to 5 short points to cover next.
- Knowledge and situational answers: the best correct answer, from your own knowledge.
- Personal and behavioural answers: only facts from the candidate's material. Never invent employers, titles, dates, numbers, projects, results or skills. When their material has nothing that fits, give an honest structure with a clear placeholder like "[your example]" and set needsStory to true.
- No buzzwords, no "Great question", nothing they couldn't say naturally.

Be accurate. If the field has hard requirements (licences, certifications, safety rules, laws), mention the ones that matter in topics, and say when they vary by country.`

export const FEEDBACK_INSTRUCTIONS = `You are Kaivon Ready's coach. The candidate just answered a practice interview question out loud. You get the question, the transcript of their answer (speech-to-text, so allow for small transcription mistakes), measurements of their delivery, and their background material.

Score 1 to 10, honestly, as a fair interviewer in their field would:
- answered: did they answer the question that was asked?
- structure: was it easy to follow, with a beginning, middle and end?
- specifics: real details, numbers, decisions and results, rather than general claims?
- delivery: pace, filler words, hedging and confidence, using the measurements.

Then give up to 3 strengths, up to 3 fixes (each one concrete and doable next time), and "better": a stronger version of their own answer, in their voice, 90 to 160 words. Keep their real facts. Never add experience, numbers or results they didn't mention and that aren't in their material; where a detail would help, write a placeholder like "[how many users]".`

const str = { type: 'string' } as const
const strs = { type: 'array', items: str } as const

export const PLAN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['field', 'level', 'summary', 'topics', 'questions', 'speaking'],
  properties: {
    field: str,
    level: str,
    summary: str,
    topics: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'why', 'points', 'sampleQuestion'],
        properties: { title: str, why: str, points: strs, sampleQuestion: str }
      }
    },
    questions: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['question', 'kind', 'whyAsked', 'say', 'points', 'tip', 'needsStory'],
        properties: {
          question: str,
          kind: { type: 'string', enum: ['personal', 'behavioural', 'knowledge', 'situational'] },
          whyAsked: str,
          say: str,
          points: strs,
          tip: str,
          needsStory: { type: 'boolean' }
        }
      }
    },
    speaking: strs
  }
}

const score = { type: 'integer' } as const

export const FEEDBACK_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['scores', 'strengths', 'fixes', 'better'],
  properties: {
    scores: {
      type: 'object',
      additionalProperties: false,
      required: ['answered', 'structure', 'specifics', 'delivery'],
      properties: { answered: score, structure: score, specifics: score, delivery: score }
    },
    strengths: strs,
    fixes: strs,
    better: str
  }
}

export function planRequest(p: Profile): string {
  const role = [p.targetRole && `Role: ${p.targetRole}`, p.company && `Company: ${p.company}`].filter(Boolean).join('\n')
  return `${role || 'Role: not given. Infer it from the resume.'}\n\nBuild the plan now.`
}

export function feedbackRequest(question: string, transcript: string, d: Delivery): string {
  const fillers = d.fillers.map((f) => `${f.word} x${f.count}`).join(', ') || 'none'
  return `<question>\n${question}\n</question>

<their_answer>
${transcript.trim() || '(nothing was heard)'}
</their_answer>

<delivery>
Length: ${d.seconds} seconds, ${d.words} words
Pace: ${d.wordsPerMinute || 'unknown'} words a minute
Filler words: ${fillers}
Hedges: ${d.hedges}
Longest pause: ${d.longestPause} seconds
</delivery>`
}

/** Clamps and tidies what came back, so the screen never shows nonsense. */
export function cleanPlan(raw: Omit<FieldPlan, 'builtAt'>): FieldPlan {
  return {
    field: raw.field.trim(),
    level: raw.level.trim(),
    summary: raw.summary.trim(),
    topics: raw.topics.slice(0, 12),
    questions: raw.questions.slice(0, 20).map((q, i) => ({ ...q, id: `q${i + 1}` })),
    speaking: raw.speaking.slice(0, 8),
    builtAt: Date.now()
  }
}

export function cleanFeedback(raw: Feedback): Feedback {
  const c = (n: number) => Math.max(1, Math.min(10, Math.round(n)))
  return {
    scores: { answered: c(raw.scores.answered), structure: c(raw.scores.structure), specifics: c(raw.scores.specifics), delivery: c(raw.scores.delivery) },
    strengths: raw.strengths.slice(0, 3),
    fixes: raw.fixes.slice(0, 3),
    better: raw.better.trim()
  }
}
