import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react"
import {
  Archive,
  BadgeDollarSign,
  BriefcaseBusiness,
  ClipboardList,
  FileQuestion,
  Home,
  LogOut,
  Pencil,
  ShieldCheck,
  Trash2,
  UserCheck,
  UserRoundX,
  Users,
  X,
  type LucideIcon,
} from "lucide-react"
import { postNui } from "./nui"
import type { Applicant, BossData, Employee, Question, QuestionType } from "./types"

type Page = "home" | "applications" | "form" | "employees" | "bonus"
type Confirmation = { title: string; body: string; run: () => Promise<void> }

const pages: Array<{ id: Page; label: string; icon: LucideIcon }> = [
  { id: "home", label: "Home", icon: Home },
  { id: "applications", label: "Applications", icon: ClipboardList },
  { id: "form", label: "Application Form", icon: FileQuestion },
  { id: "employees", label: "Employees", icon: Users },
  { id: "bonus", label: "Bonus", icon: BadgeDollarSign },
]

const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 })

function HomePage({ data }: { data: BossData }) {
  return (
    <section aria-labelledby="home-title">
      <div className="page-heading">
        <div><p className="eyebrow">Overview</p><h2 id="home-title">Home</h2></div>
      </div>
      <div className="metric-grid">
        <article><BadgeDollarSign /><span>Business balance</span><strong>{money.format(data.bank)}</strong></article>
        <article><Users /><span>Employees</span><strong>{data.employees.length}</strong></article>
        <article><ClipboardList /><span>Applications</span><strong>{data.applicants.length}</strong></article>
      </div>
      <section className="card log-card" aria-labelledby="activity-title">
        <div className="card-heading"><h3 id="activity-title">Recent activity</h3><span>{data.logs.length} entries</span></div>
        {data.logs.length === 0 ? <p className="empty">No activity has been recorded yet.</p> : (
          <ol className="log-list">
            {[...data.logs].reverse().map((entry, index) => (
              <li key={`${entry.date}-${index}`}><span>{entry.message}</span><time>{new Date(entry.date).toLocaleString()}</time></li>
            ))}
          </ol>
        )}
      </section>
    </section>
  )
}

function ApplicationsPage({ applicants, busy, accept, deny }: {
  applicants: Applicant[]
  busy: boolean
  accept: (applicant: Applicant) => void
  deny: (applicant: Applicant) => void
}) {
  return (
    <section aria-labelledby="applications-title">
      <div className="page-heading"><div><p className="eyebrow">Recruitment</p><h2 id="applications-title">Applications</h2></div><span className="count-badge">{applicants.length}</span></div>
      {applicants.length === 0 ? <div className="card empty"><UserCheck />No applications are waiting.</div> : (
        <div className="application-list">
          {applicants.map((applicant) => (
            <article className="card application-card" key={applicant.citizenid}>
              <div className="card-heading"><div><h3>{applicant.name}</h3><span>{applicant.citizenid}</span></div></div>
              <dl>{applicant.questions.map((answer, index) => <div key={`${answer.question}-${index}`}><dt>{answer.question}</dt><dd>{answer.answer}</dd></div>)}</dl>
              <footer>
                <button data-variant="primary" disabled={busy} onClick={() => accept(applicant)}><UserCheck />Accept</button>
                <button data-variant="destructive" disabled={busy} onClick={() => deny(applicant)}><UserRoundX />Deny</button>
              </footer>
            </article>
          ))}
        </div>
      )}
    </section>
  )
}

function QuestionEditor({ initial, busy, cancel, save }: {
  initial?: Question
  busy: boolean
  cancel?: () => void
  save: (question: Question) => void
}) {
  const [question, setQuestion] = useState(initial?.question ?? "")
  const [type, setType] = useState<QuestionType>(initial?.type ?? "short")

  function submit(event: FormEvent) {
    event.preventDefault()
    const trimmed = question.trim()
    if (trimmed) save({ question: trimmed, type })
  }

  return (
    <form className="question-form" onSubmit={submit}>
      <label><span>Question</span><input aria-label={initial ? "Edit question" : "New question"} maxLength={250} value={question} onChange={(event) => setQuestion(event.target.value)} /></label>
      <label><span>Answer type</span><select value={type} onChange={(event) => setType(event.target.value as QuestionType)}><option value="short">Short text</option><option value="long">Long text</option><option value="number">Number</option><option value="yesno">Yes or no</option></select></label>
      <div className="form-actions"><button data-variant="primary" disabled={busy || !question.trim()}>{initial ? "Save Question" : "Add Question"}</button>{cancel && <button type="button" data-variant="ghost" onClick={cancel}>Cancel</button>}</div>
    </form>
  )
}

function FormPage({ questions, busy, add, edit, remove }: {
  questions: Question[]
  busy: boolean
  add: (question: Question) => void
  edit: (original: Question, updated: Question) => void
  remove: (question: Question) => void
}) {
  const [editing, setEditing] = useState<number | null>(null)
  return (
    <section aria-labelledby="form-title">
      <div className="page-heading"><div><p className="eyebrow">Recruitment</p><h2 id="form-title">Application Form</h2></div><span className="count-badge">{questions.length}</span></div>
      <div className="card question-list">
        {questions.map((question, index) => editing === index ? (
          <QuestionEditor key={`${question.question}-${index}`} initial={question} busy={busy} cancel={() => setEditing(null)} save={(updated) => { edit(question, updated); setEditing(null) }} />
        ) : (
          <div className="question-row" key={`${question.question}-${index}`}><span><strong>{question.question}</strong><small>{question.type}</small></span><div><button data-size="sm" data-variant="ghost" aria-label={`Edit ${question.question}`} onClick={() => setEditing(index)}><Pencil />Edit</button><button data-size="sm" data-variant="destructive" aria-label={`Remove ${question.question}`} onClick={() => remove(question)}><Trash2 />Remove</button></div></div>
        ))}
        {questions.length === 0 && <p className="empty">Add the first application question below.</p>}
      </div>
      <section className="card add-question"><h3>Add question</h3><QuestionEditor busy={busy} save={add} /></section>
    </section>
  )
}

function EmployeesPage({ data, busy, rank, fire }: {
  data: BossData
  busy: boolean
  rank: (employee: Employee, grade: number) => void
  fire: (employee: Employee) => void
}) {
  return (
    <section aria-labelledby="employees-title">
      <div className="page-heading"><div><p className="eyebrow">Team</p><h2 id="employees-title">Employees</h2></div><span className="count-badge">{data.employees.length}</span></div>
      <div className="card table-wrap"><table><thead><tr><th>Employee</th><th>Status</th><th>Rank</th><th>Pay</th><th><span className="sr-only">Actions</span></th></tr></thead><tbody>{data.employees.map((employee) => <tr key={employee.citizenid}><td><strong>{employee.name}</strong><small>{employee.citizenid}</small></td><td><span className={`status ${employee.online ? "online" : "offline"}`}>{employee.online ? "Online" : "Offline"}</span></td><td><select aria-label={`Rank for ${employee.name}`} disabled={busy} value={employee.level} onChange={(event) => rank(employee, Number(event.target.value))}>{data.jobGrades.map((grade) => <option key={grade.grade} value={grade.grade}>{grade.name}</option>)}</select></td><td>{money.format(employee.pay)}</td><td><button data-size="sm" data-variant="destructive" disabled={busy} onClick={() => fire(employee)}><UserRoundX />Fire</button></td></tr>)}</tbody></table>{data.employees.length === 0 && <p className="empty">There are no employees in this job.</p>}</div>
    </section>
  )
}

function BonusPage({ data, busy, pay }: { data: BossData; busy: boolean; pay: (employee: Employee, amount: number) => void }) {
  const [citizenid, setCitizenid] = useState(data.employees[0]?.citizenid ?? "")
  const [amount, setAmount] = useState("")
  const [validation, setValidation] = useState("")

  function submit(event: FormEvent) {
    event.preventDefault()
    const employee = data.employees.find((entry) => entry.citizenid === citizenid)
    const parsed = Math.floor(Number(amount))
    if (!employee || !Number.isFinite(parsed) || parsed <= 0) return setValidation("Choose an employee and enter a positive amount.")
    if (parsed > data.bank) return setValidation("The bonus cannot exceed the business balance.")
    setValidation("")
    pay(employee, parsed)
  }

  return (
    <section aria-labelledby="bonus-title">
      <div className="page-heading"><div><p className="eyebrow">Compensation</p><h2 id="bonus-title">Bonus</h2></div></div>
      <div className="bonus-layout"><form className="card bonus-form" onSubmit={submit}><label><span>Employee</span><select aria-label="Bonus employee" value={citizenid} onChange={(event) => setCitizenid(event.target.value)}><option value="">Select employee</option>{data.employees.map((employee) => <option key={employee.citizenid} value={employee.citizenid}>{employee.name}{employee.online ? "" : " (offline)"}</option>)}</select></label><label><span>Amount</span><input aria-label="Bonus amount" inputMode="numeric" min="1" type="number" value={amount} onChange={(event) => setAmount(event.target.value)} /></label>{validation && <p className="field-error" role="alert">{validation}</p>}<button data-variant="primary" disabled={busy || data.employees.length === 0}><BadgeDollarSign />Pay Bonus</button></form><aside className="card balance-card"><span>Available balance</span><strong>{money.format(data.bank)}</strong><small>Bonuses are paid to online employees.</small></aside></div>
    </section>
  )
}

function ConfirmDialog({ confirmation, busy, close }: { confirmation: Confirmation; busy: boolean; close: () => void }) {
  return <div className="dialog-backdrop"><div role="dialog" aria-modal="true" aria-labelledby="confirm-title" className="confirm-dialog"><ShieldCheck /><h2 id="confirm-title">{confirmation.title}</h2><p>{confirmation.body}</p><footer><button data-variant="destructive" disabled={busy} onClick={() => void confirmation.run()}>Confirm</button><button data-variant="ghost" disabled={busy} onClick={close}>Cancel</button></footer></div></div>
}

export function App() {
  const [data, setData] = useState<BossData | null>(null)
  const [page, setPage] = useState<Page>("home")
  const [pending, setPending] = useState<string | null>(null)
  const [error, setError] = useState("")
  const [confirmation, setConfirmation] = useState<Confirmation | null>(null)

  const close = useCallback(async () => {
    try { await postNui("hideUI") } finally { setData(null); setConfirmation(null) }
  }, [])

  useEffect(() => {
    const receive = (event: MessageEvent) => {
      if (event.origin !== "nui://game" || event.data?.action !== "openBossMenu") return
      setData(event.data.data as BossData)
      setPage("home")
      setError("")
    }
    window.addEventListener("message", receive)
    void postNui("qbbossmenu:ready")
    return () => window.removeEventListener("message", receive)
  }, [])

  useEffect(() => {
    if (!data) return
    const escape = (event: KeyboardEvent) => { if (event.key === "Escape") { event.preventDefault(); void close() } }
    window.addEventListener("keydown", escape)
    return () => window.removeEventListener("keydown", escape)
  }, [close, data])

  const mutate = useCallback(async (action: string, payload: unknown, success: () => void) => {
    setPending(action)
    setError("")
    try {
      if (await postNui<boolean>(action, payload)) success()
      else setError("The action was refused. Nothing was changed.")
    } catch {
      setError("The action could not be completed. Nothing was changed.")
    } finally {
      setPending(null)
      setConfirmation(null)
    }
  }, [])

  const busy = pending !== null
  const online = useMemo(() => data?.employees.filter((employee) => employee.online).length ?? 0, [data])
  if (!data) return null

  const payload = { jobName: data.jobName }
  const accept = (applicant: Applicant) => void mutate("acceptApplicant", { ...payload, citizenid: applicant.citizenid }, () => setData((current) => {
    if (!current) return current
    const grade = current.jobGrades.find((entry) => entry.grade === 1) ?? current.jobGrades[0]
    const hired: Employee = { citizenid: applicant.citizenid, name: applicant.name, jobName: current.jobName, jobLabel: current.jobLabel, level: grade?.grade ?? 1, gradeName: grade?.name ?? "Employee", pay: grade?.pay ?? 0, online: false }
    return { ...current, applicants: current.applicants.filter((entry) => entry.citizenid !== applicant.citizenid), employees: [...current.employees, hired] }
  }))
  const deny = (applicant: Applicant) => setConfirmation({ title: "Deny application?", body: `${applicant.name}'s application will be removed.`, run: () => mutate("denyApplicant", { ...payload, citizenid: applicant.citizenid }, () => setData((current) => current && ({ ...current, applicants: current.applicants.filter((entry) => entry.citizenid !== applicant.citizenid) }))) })
  const addQuestion = (question: Question) => void mutate("addQuestion", { ...payload, new: question }, () => setData((current) => current && ({ ...current, questions: [...current.questions, question] })))
  const editQuestion = (original: Question, updated: Question) => void mutate("editQuestion", { ...payload, originalQuestion: original.question, updatedQuestion: updated }, () => setData((current) => current && ({ ...current, questions: current.questions.map((entry) => entry === original ? updated : entry) })))
  const removeQuestion = (question: Question) => setConfirmation({ title: "Remove question?", body: `“${question.question}” will no longer appear on new applications.`, run: () => mutate("removeQuestion", { ...payload, question: question.question }, () => setData((current) => current && ({ ...current, questions: current.questions.filter((entry) => entry !== question) }))) })
  const setRank = (employee: Employee, gradeNumber: number) => void mutate("setRank", { ...payload, citizenid: employee.citizenid, grade: gradeNumber }, () => setData((current) => {
    if (!current) return current
    const grade = current.jobGrades.find((entry) => entry.grade === gradeNumber)
    return { ...current, employees: current.employees.map((entry) => entry.citizenid === employee.citizenid ? { ...entry, level: gradeNumber, gradeName: grade?.name ?? entry.gradeName, pay: grade?.pay ?? entry.pay } : entry) }
  }))
  const fire = (employee: Employee) => setConfirmation({ title: "Fire employee?", body: `${employee.name} will be removed from ${data.jobName}.`, run: () => mutate("fireEmployee", { ...payload, employee: employee.citizenid }, () => setData((current) => current && ({ ...current, employees: current.employees.filter((entry) => entry.citizenid !== employee.citizenid) }))) })
  const pay = (employee: Employee, amount: number) => void mutate("giveBonus", { ...payload, citizenid: employee.citizenid, amount }, () => setData((current) => current && ({ ...current, bank: current.bank - amount })))
  const stash = () => void mutate("openStash", {}, () => setData(null))

  return (
    <div className="boss-shell">
      <aside className="sidebar">
        <div className="brand"><BriefcaseBusiness /><span><strong>Management</strong><small>{data.jobLabel}</small></span></div>
        <nav aria-label="Boss menu">{pages.map(({ id, label, icon: Icon }) => <button key={id} className={page === id ? "active" : ""} aria-current={page === id ? "page" : undefined} onClick={() => setPage(id)}><Icon />{label}{id === "applications" && data.applicants.length > 0 && <span>{data.applicants.length}</span>}</button>)}</nav>
        <div className="sidebar-footer"><button onClick={stash} disabled={busy}><Archive />Open Stash</button><button onClick={() => void close()}><LogOut />Close <kbd>Esc</kbd></button></div>
      </aside>
      <main>
        <header className="topbar"><div><span className="status online">{online} online</span><span>{data.employees.length} employees</span></div><button aria-label="Close boss menu" data-variant="ghost" onClick={() => void close()}><X /></button></header>
        {error && <div className="error-banner" role="alert"><span>{error}</span><button data-variant="ghost" aria-label="Dismiss error" onClick={() => setError("")}><X /></button></div>}
        <div className="page-content">
          {page === "home" && <HomePage data={data} />}
          {page === "applications" && <ApplicationsPage applicants={data.applicants} busy={busy} accept={accept} deny={deny} />}
          {page === "form" && <FormPage questions={data.questions} busy={busy} add={addQuestion} edit={editQuestion} remove={removeQuestion} />}
          {page === "employees" && <EmployeesPage data={data} busy={busy} rank={setRank} fire={fire} />}
          {page === "bonus" && <BonusPage data={data} busy={busy} pay={pay} />}
        </div>
      </main>
      {confirmation && <ConfirmDialog confirmation={confirmation} busy={busy} close={() => setConfirmation(null)} />}
    </div>
  )
}
