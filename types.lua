---@meta

-- Annotation-only declaration of kora_bossmenu's cross-resource contract. Keep
-- this in sync with the executable export contract in test/contracts.lua so
-- LuaLS can flag misspelled or renamed calls before they reach FXServer.

---@class QBBossMenuClientExports
---@field openBossMenu fun(self: QBBossMenuClientExports)
---@field openApplication fun(self: QBBossMenuClientExports, jobName: string)
---@field AddBossMenuItem fun(self: QBBossMenuClientExports, data: table, id?: string|integer): string|integer
---@field RemoveBossMenuItem fun(self: QBBossMenuClientExports, id: string|integer)
---@field AddGangMenuItem fun(self: QBBossMenuClientExports, data: table, id?: string|integer): string|integer
---@field RemoveGangMenuItem fun(self: QBBossMenuClientExports, id: string|integer)

---@class QBBossMenuServerExports
---@field addBusinessMoney fun(self: QBBossMenuServerExports, jobName: string, amount: number, reason?: string): boolean, string?
---@field removeBusinessMoney fun(self: QBBossMenuServerExports, jobName: string, amount: number, reason?: string): boolean, string?
---@field getBusinessBalance fun(self: QBBossMenuServerExports, jobName: string): number?, string?
---@field AddMoney fun(self: QBBossMenuServerExports, jobName: string, amount: number): boolean
---@field RemoveMoney fun(self: QBBossMenuServerExports, jobName: string, amount: number): boolean
---@field AddGangMoney fun(self: QBBossMenuServerExports, gangName: string, amount: number): boolean
---@field RemoveGangMoney fun(self: QBBossMenuServerExports, gangName: string, amount: number): boolean
---@field GetAccount fun(self: QBBossMenuServerExports, jobName: string): number
---@field GetGangAccount fun(self: QBBossMenuServerExports, gangName: string): number
