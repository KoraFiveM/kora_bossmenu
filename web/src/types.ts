export type QuestionType = "short" | "long" | "number" | "yesno"

export interface Question {
  question: string
  type: QuestionType
}

export interface ApplicantAnswer {
  question: string
  answer: string
}

export interface Applicant {
  citizenid: string
  name: string
  questions: ApplicantAnswer[]
}

export interface Employee {
  citizenid: string
  name: string
  grade: number
  gradeName: string
  pay: number
  online: boolean
}

export interface JobGrade {
  name: string
  grade: number
  pay: number
}

export interface BossLog {
  date: string
  message: string
}

export interface BossData {
  jobGrades: JobGrade[]
  employees: Employee[]
  applicants: Applicant[]
  questions: Question[]
  bank: number
  logs: BossLog[]
  jobName: string
}
