---@meta

-- Annotation-only declaration of kora_bossmenu's cross-resource contract. Keep
-- this in sync with the executable export contract in test/contracts.lua so
-- LuaLS can flag misspelled or renamed calls before they reach FXServer.

---@class KoraBossMenuClientExports
---@field openBossMenu fun(self: KoraBossMenuClientExports)
---@field openApplication fun(self: KoraBossMenuClientExports, jobName: string)
---@field AddBossMenuItem fun(self: KoraBossMenuClientExports, data: table, id?: string|integer): string|integer
---@field RemoveBossMenuItem fun(self: KoraBossMenuClientExports, id: string|integer)
---@field AddGangMenuItem fun(self: KoraBossMenuClientExports, data: table, id?: string|integer): string|integer
---@field RemoveGangMenuItem fun(self: KoraBossMenuClientExports, id: string|integer)

---@class KoraBossMenuServerExports
---@field addBusinessMoney fun(self: KoraBossMenuServerExports, jobName: string, amount: number, reason?: string): boolean, string?
---@field removeBusinessMoney fun(self: KoraBossMenuServerExports, jobName: string, amount: number, reason?: string): boolean, string?
---@field getBusinessBalance fun(self: KoraBossMenuServerExports, jobName: string): number?, string?
---@field AddMoney fun(self: KoraBossMenuServerExports, jobName: string, amount: number): boolean
---@field RemoveMoney fun(self: KoraBossMenuServerExports, jobName: string, amount: number): boolean
---@field AddGangMoney fun(self: KoraBossMenuServerExports, gangName: string, amount: number): boolean
---@field RemoveGangMoney fun(self: KoraBossMenuServerExports, gangName: string, amount: number): boolean
---@field GetAccount fun(self: KoraBossMenuServerExports, jobName: string): number
---@field GetGangAccount fun(self: KoraBossMenuServerExports, gangName: string): number
