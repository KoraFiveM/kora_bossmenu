import { act, fireEvent, render, screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { App } from "./App"
import type { BossData } from "./types"

const data: BossData = {
  jobName: "police",
  jobLabel: "Law Enforcement",
  jobGrades: [
    { grade: 1, name: "Officer", pay: 500 },
    { grade: 2, name: "Sergeant", pay: 750 },
  ],
  employees: [
    { citizenid: "EMP001", name: "Alex Stone", jobName: "police", jobLabel: "Law Enforcement", level: 1, gradeName: "Officer", pay: 500, online: true },
  ],
  applicants: [
    { citizenid: "APP001", name: "Jordan Lane", questions: [{ question: "Why join?", answer: "To help the city." }] },
  ],
  questions: [{ question: "Why join?", type: "long" }],
  logs: [{ date: "2026-09-05T12:00:00Z", message: "Business received $5000." }],
}

function response(value = true): Response {
  return { ok: true, json: async () => value } as Response
}

async function openApp() {
  render(<App />)
  await act(async () => {
    window.dispatchEvent(new MessageEvent("message", { origin: "nui://game", data: { action: "openBossMenu", data: structuredClone(data) } }))
  })
  return userEvent.setup()
}

function called(action: string) {
  return vi.mocked(fetch).mock.calls.some(([url]) => String(url).endsWith(`/${action}`))
}

beforeEach(() => {
  window.GetParentResourceName = () => "kora_bossmenu"
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue(response()))
})

afterEach(() => {
  vi.unstubAllGlobals()
})

test("renders Home, Applications, Application Form, Employees, and Bonus pages", async () => {
  const user = await openApp()
  expect(screen.getByRole("heading", { name: "Home" })).toBeInTheDocument()
  expect(screen.queryByText("Business balance")).not.toBeInTheDocument()
  await user.click(screen.getByRole("button", { name: /Applications/ }))
  expect(screen.getByRole("heading", { name: "Applications" })).toBeInTheDocument()
  await user.click(screen.getByRole("button", { name: "Application Form" }))
  expect(screen.getByRole("heading", { name: "Application Form" })).toBeInTheDocument()
  await user.click(screen.getByRole("button", { name: "Employees" }))
  expect(screen.getByRole("heading", { name: "Employees" })).toBeInTheDocument()
  await user.click(screen.getByRole("button", { name: "Bonus" }))
  expect(screen.getByRole("heading", { name: "Bonus" })).toBeInTheDocument()
})

test("accepts an applicant only after a successful mutation", async () => {
  const user = await openApp()
  await user.click(screen.getByRole("button", { name: /Applications/ }))
  await user.click(screen.getByRole("button", { name: "Accept" }))
  await waitFor(() => expect(called("acceptApplicant")).toBe(true))
  expect(screen.queryByText("Jordan Lane")).not.toBeInTheDocument()
})

test("denies an applicant through a text-only confirmation", async () => {
  const user = await openApp()
  await user.click(screen.getByRole("button", { name: /Applications/ }))
  await user.click(screen.getByRole("button", { name: "Deny" }))
  expect(screen.getByRole("dialog")).toHaveTextContent("Jordan Lane's application will be removed.")
  await user.click(screen.getByRole("button", { name: "Confirm" }))
  await waitFor(() => expect(called("denyApplicant")).toBe(true))
  expect(screen.queryByText("Jordan Lane")).not.toBeInTheDocument()
})

test("adds, edits, and removes application questions", async () => {
  const user = await openApp()
  await user.click(screen.getByRole("button", { name: "Application Form" }))
  await user.type(screen.getByLabelText("New question"), "Can you drive?")
  await user.click(screen.getByRole("button", { name: "Add Question" }))
  await waitFor(() => expect(screen.getByText("Can you drive?")).toBeInTheDocument())
  expect(called("addQuestion")).toBe(true)

  await user.click(screen.getByRole("button", { name: "Edit Why join?" }))
  const editor = screen.getByLabelText("Edit question")
  await user.clear(editor)
  await user.type(editor, "Why should we hire you?")
  await user.click(screen.getByRole("button", { name: "Save Question" }))
  await waitFor(() => expect(screen.getByText("Why should we hire you?")).toBeInTheDocument())
  expect(called("editQuestion")).toBe(true)

  await user.click(screen.getByRole("button", { name: "Remove Can you drive?" }))
  await user.click(screen.getByRole("button", { name: "Confirm" }))
  await waitFor(() => expect(screen.queryByText("Can you drive?")).not.toBeInTheDocument())
  expect(called("removeQuestion")).toBe(true)
})

test("changes an employee rank after success", async () => {
  const user = await openApp()
  await user.click(screen.getByRole("button", { name: "Employees" }))
  await user.selectOptions(screen.getByLabelText("Rank for Alex Stone"), "2")
  await waitFor(() => expect(called("setRank")).toBe(true))
  expect(screen.getByLabelText("Rank for Alex Stone")).toHaveValue("2")
})

test("fires an employee through confirmation", async () => {
  const user = await openApp()
  await user.click(screen.getByRole("button", { name: "Employees" }))
  await user.click(screen.getByRole("button", { name: "Fire" }))
  expect(screen.getByRole("dialog")).toHaveTextContent("Alex Stone will be removed")
  await user.click(screen.getByRole("button", { name: "Confirm" }))
  await waitFor(() => expect(called("fireEmployee")).toBe(true))
  expect(screen.queryByText("Alex Stone")).not.toBeInTheDocument()
})

test("validates and successfully pays a bonus through the server", async () => {
  const user = await openApp()
  await user.click(screen.getByRole("button", { name: "Bonus" }))
  await user.clear(screen.getByLabelText("Bonus amount"))
  await user.click(screen.getByRole("button", { name: "Pay Bonus" }))
  expect(screen.getByRole("alert")).toHaveTextContent("positive amount")
  expect(called("giveBonus")).toBe(false)

  await user.clear(screen.getByLabelText("Bonus amount"))
  await user.type(screen.getByLabelText("Bonus amount"), "250")
  await user.click(screen.getByRole("button", { name: "Pay Bonus" }))
  await waitFor(() => expect(called("giveBonus")).toBe(true))
})

test("retains local state and reports an error when a mutation fails", async () => {
  vi.mocked(fetch).mockImplementation(async (url) => response(!String(url).endsWith("/acceptApplicant")))
  const user = await openApp()
  await user.click(screen.getByRole("button", { name: /Applications/ }))
  await user.click(screen.getByRole("button", { name: "Accept" }))
  expect(await screen.findByRole("alert")).toHaveTextContent("Nothing was changed")
  expect(screen.getByText("Jordan Lane")).toBeInTheDocument()
})

test("closes through Escape and the close control", async () => {
  const user = await openApp()
  fireEvent.keyDown(window, { key: "Escape" })
  await waitFor(() => expect(called("hideUI")).toBe(true))
  expect(screen.queryByRole("heading", { name: "Home" })).not.toBeInTheDocument()

  await act(async () => window.dispatchEvent(new MessageEvent("message", { origin: "nui://game", data: { action: "openBossMenu", data: structuredClone(data) } })))
  await user.click(screen.getByRole("button", { name: "Close boss menu" }))
  await waitFor(() => expect(screen.queryByRole("heading", { name: "Home" })).not.toBeInTheDocument())
})

test("hands off to the stash and closes only after success", async () => {
  const user = await openApp()
  await user.click(screen.getByRole("button", { name: "Open Stash" }))
  await waitFor(() => expect(called("openStash")).toBe(true))
  expect(screen.queryByRole("heading", { name: "Home" })).not.toBeInTheDocument()
})
