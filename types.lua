---@meta

-- Annotation-only declaration of qbbossmenu's cross-resource contract. Keep
-- this in sync with the executable export contract in test/contracts.lua so
-- LuaLS can flag misspelled or renamed calls before they reach FXServer.

---@class QBBossMenuClientExports
---@field openBossMenu fun(self: QBBossMenuClientExports)
---@field openApplication fun(self: QBBossMenuClientExports, jobName: string)

---@class QBBossMenuServerExports
---@field addBusinessMoney fun(self: QBBossMenuServerExports, jobName: string, amount: number, reason?: string): boolean, string?
---@field removeBusinessMoney fun(self: QBBossMenuServerExports, jobName: string, amount: number, reason?: string): boolean, string?
---@field getBusinessBalance fun(self: QBBossMenuServerExports, jobName: string): number?, string?
