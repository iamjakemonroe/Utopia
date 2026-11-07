// What Claude is told. The candidate's own material is the only source of
// facts: an answer that invents experience falls apart at the first follow-up.

import type { Exchange, Profile } from './types.ts'

export const INSTRUCTIONS = `You are Kaivon Ready, a quiet helper on a candidate's screen during a live job interview. The interviewer has just spoken. Give the candidate the best answer they can say straight away, in their own voice.

Write only in this format, with nothing before or after it:
SAY: one or two sentences the candidate can say right now, first person, natural spoken English.
- a point to cover next, at most 12 words
- another point
- a third point, only if it helps
ASK: a short question back to the interviewer, only when it fits naturally. Otherwise leave this line out.
NOTE: only when needed, a short warning for the candidate. Otherwise leave this line out.

Two kinds of question, two rules:
- Knowledge questions (technical, how something works, "how would you design", "what would you do if"): give the best correct answer you can, from your own knowledge. Be accurate and specific. Add one example from the candidate's own work only if their material has one that fits.
- Personal questions (their experience, past roles, projects, achievements, reasons, background, "tell me about a time"): use only facts from the candidate's material: their resume, their stories, what they've written about themselves, and the job. Never invent employers, job titles, dates, numbers, project names, results, tools or skills. If a detail isn't in the material, leave it out.
- If a personal question has nothing in their material that fits, write "NOTE: Nothing you've taught Kaivon fits this. Use a real example of your own." Keep SAY and the points to an honest shape they can fill with a true example.

Style:
- Sound like a person talking, not a cover letter: short sentences, contractions, no buzzwords, never "Great question".
- "Tell me about a time" questions: choose the one best matching story. Points follow what happened, what they did, the result, and what they learned.
- Technical questions: the approach in plain words, the main trade-off, and one example from their own work if one fits.
- Small talk, "can you hear me", or a remark that needs no answer: a short natural reply in SAY and no points.
- If the words look garbled or cut off, answer the most likely question and add "NOTE: Check you heard the question right."
- Salary, notice period, visa and start date: use only what they've written about themselves. If it doesn't say, write "NOTE: Decide this before the interview." and give a neutral reply that doesn't commit to a number.
- Never suggest lying, dodging something the interviewer asks directly, or claiming a skill they don't have.
- The whole answer must be readable in five seconds.`

const block = (tag: string, text: string): string => {
  const t = text.trim()
  return t ? `<${tag}>\n${t}\n</${tag}>` : ''
}

/** The candidate's material, in a fixed order so it stays cached between questions. */
export function profileText(p: Profile): string {
  const stories = p.stories
    .filter((s) => s.text.trim())
    .map((s) => `<story title="${s.title.replace(/"/g, "'").trim() || 'Untitled'}">\n${s.text.trim()}\n</story>`)
    .join('\n')
  const parts = [
    block('candidate_name', p.name),
    block('role_they_want', p.targetRole),
    block('company', p.company),
    block('job_description', p.jobDescription),
    block('resume', p.resume),
    stories ? `<stories>\n${stories}\n</stories>` : '',
    block('about_them', p.notes)
  ].filter(Boolean)
  if (parts.length === 0) return '<candidate_material>\nThe candidate has not added any material yet.\n</candidate_material>'
  return `<candidate_material>\n${parts.join('\n\n')}\n</candidate_material>`
}

/** The conversation so far and what the interviewer just said. */
export function questionText(question: string, history: Exchange[]): string {
  const lines = history.map((e) => `${e.speaker === 'them' ? 'Interviewer' : 'Candidate'}: ${e.text}`)
  const so = lines.length ? `<conversation_so_far>\n${lines.join('\n')}\n</conversation_so_far>\n\n` : ''
  return `${so}<interviewer_just_said>\n${question.trim()}\n</interviewer_just_said>`
}

export interface Answer {
  say: string
  points: string[]
  ask: string
  note: string
}

/** Reads an answer, complete or still streaming, into its parts. */
export function parseAnswer(text: string): Answer {
  const out: Answer = { say: '', points: [], ask: '', note: '' }
  let last: 'say' | 'ask' | 'note' | 'point' | null = null
  for (const raw of text.split('\n')) {
    const line = raw.trim()
    if (!line) continue
    const tag = /^(SAY|ASK|NOTE)\s*:\s*(.*)$/i.exec(line)
    if (tag) {
      const key = tag[1]!.toLowerCase() as 'say' | 'ask' | 'note'
      out[key] = tag[2]!.trim()
      last = key
      continue
    }
    const point = /^[-•*]\s*(.*)$/.exec(line)
    if (point) {
      out.points.push(point[1]!.trim())
      last = 'point'
      continue
    }
    // A wrapped line belongs to whatever came before it.
    if (last === 'point' && out.points.length) out.points[out.points.length - 1] += ` ${line}`
    else if (last && last !== 'point') out[last] = `${out[last]} ${line}`.trim()
    else out.say = `${out.say} ${line}`.trim()
  }
  return out
}
