export function resourceName(): string {
  return typeof window.GetParentResourceName === "function"
    ? window.GetParentResourceName()
    : "kora_bossmenu"
}

export async function postNui<T = boolean>(name: string, data: unknown = {}): Promise<T> {
  if (typeof window.GetParentResourceName !== "function") return true as T
  const response = await fetch(`https://${resourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  })
  if (!response.ok) throw new Error(`${name} failed (${response.status})`)
  return response.json() as Promise<T>
}

declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}
