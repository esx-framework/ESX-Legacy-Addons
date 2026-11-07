-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXDMVTheory = {}

local RESOURCE_NAME = GetCurrentResourceName()
local banks = {}

local function integer(value, minimum, maximum)
  return type(value) == 'number'
    and value == value
    and value >= minimum
    and value <= maximum
    and value == math.floor(value)
end

local function denseArray(value, count)
  if type(value) ~= 'table' then
    return false
  end
  for key in pairs(value) do
    if not integer(key, 1, count) then
      return false
    end
  end
  for index = 1, count do
    if value[index] == nil then
      return false
    end
  end
  return true
end

local function validBank(bank)
  if type(bank) ~= 'table' or #bank < 1 or not denseArray(bank, #bank) then
    return false
  end
  for index, question in ipairs(bank) do
    if
      type(question) ~= 'table'
      or question.id ~= index
      or type(question.text) ~= 'string'
      or question.text == ''
      or not integer(question.correct, 0, 3)
      or not denseArray(question.answers, 4)
    then
      return false
    end
    for _, answer in ipairs(question.answers) do
      if type(answer) ~= 'string' or answer == '' then
        return false
      end
    end
  end
  return true
end

local function readBank(locale)
  if banks[locale] ~= nil then
    return banks[locale]
  end
  local ok, result = pcall(function()
    local source = LoadResourceFile(RESOURCE_NAME, ('server/questions/%s.lua'):format(locale))
    if not source then
      return false
    end
    local chunk = load(source, '@server/questions/' .. locale .. '.lua', 't', {})
    if not chunk then
      return false
    end
    local bank = chunk()
    return validBank(bank) and bank or false
  end)
  banks[locale] = ok and result or false
  return banks[locale]
end

local function selectBank(locale)
  locale = type(locale) == 'string' and locale:lower():gsub('_', '-') or 'en'
  if #locale > 32 or not locale:match('^[a-z][a-z0-9%-]*$') then
    locale = 'en'
  end
  local bank = readBank(locale)
  if bank then
    return bank, locale
  end
  local base = locale:match('^[^-]+')
  if base ~= locale then
    bank = readBank(base)
    if bank then
      return bank, base
    end
  end
  return readBank('en'), 'en'
end

function ESXDMVTheory.Create(license, locale)
  if type(license) ~= 'table' or license.kind ~= 'theory' then
    return nil, 'invalid_license'
  end
  if license.bank and license.bank ~= 'road' then
    return nil, 'unavailable'
  end
  local bank, selectedLocale = selectBank(locale)
  if
    not bank
    or not integer(license.questionCount, 1, #bank)
    or not integer(license.answersNeeded, 1, license.questionCount)
  then
    return nil, 'unavailable'
  end

  local order = {}
  for index = 1, #bank do
    order[index] = index
  end
  for index = #order, 2, -1 do
    local other = math.random(index)
    order[index], order[other] = order[other], order[index]
  end

  local exam = {
    publicQuestions = {},
    correctAnswers = {},
    total = license.questionCount,
    needed = license.answersNeeded,
    locale = selectedLocale,
  }
  for index = 1, exam.total do
    local question = bank[order[index]]
    exam.publicQuestions[index] = {
      id = question.id,
      text = question.text,
      answers = { question.answers[1], question.answers[2], question.answers[3], question.answers[4] },
    }
    exam.correctAnswers[index] = question.correct
  end
  return exam
end

function ESXDMVTheory.Grade(exam, answers)
  if
    type(exam) ~= 'table'
    or not integer(exam.total, 1, 1000)
    or not integer(exam.needed, 1, exam.total)
    or not denseArray(exam.correctAnswers, exam.total)
    or not denseArray(answers, exam.total)
  then
    return nil, 'invalid_result'
  end
  local score, correctAnswers = 0, {}
  for index = 1, exam.total do
    local expected, answer = exam.correctAnswers[index], answers[index]
    if not integer(expected, 0, 3) or not integer(answer, 0, 3) then
      return nil, 'invalid_result'
    end
    correctAnswers[index] = expected
    if answer == expected then
      score = score + 1
    end
  end
  return { score = score, total = exam.total, passed = score >= exam.needed, correctAnswers = correctAnswers }
end
