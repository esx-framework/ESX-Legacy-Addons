-- SPDX-License-Identifier: GPL-3.0-only
-- Server question selection and grading boundary checks.
local checks = 0
local function check(value, label)
  checks = checks + 1
  assert(value, label)
end

local function fixture(sources)
  local reads = {}
  local env = setmetatable({}, {__index = _G})
  env.GetCurrentResourceName = function() return 'esx_dmvschool' end
  env.LoadResourceFile = function(resource, name)
    assert(resource == 'esx_dmvschool')
    reads[#reads + 1] = name
    local locale = name:match('^server/questions/([a-z0-9%-]+)%.lua$')
    return (sources or QuestionSources)[locale]
  end
  env.math = setmetatable({random = function(maximum)
    assert(type(maximum) == 'number' and maximum >= 1)
    return 1
  end}, {__index = math})
  assert(load(TheorySource, '@server/theory.lua', 't', env))()
  return env.ESXDMVTheory, reads
end

local license = {kind = 'theory', bank = 'road', questionCount = 10, answersNeeded = 5}
local theory, reads = fixture()
check(#reads == 0, 'bank loading is lazy')
local exam = assert(theory.Create(license, 'en'))
check(exam.total == 10 and exam.needed == 5 and exam.locale == 'en', 'exam uses configured threshold and count')
check(#exam.publicQuestions == 10 and #exam.correctAnswers == 10, 'question and private answer arrays are complete')
check(exam.publicQuestions[1].id ~= 1, 'the server selects question order before publishing it')
local seen = {}
for _, question in ipairs(exam.publicQuestions) do
  check(not seen[question.id], 'questions are selected without duplicates')
  seen[question.id] = true
  check(type(question.text) == 'string' and #question.answers == 4, 'public question has text and four choices')
  for key in pairs(question) do
    check(key == 'id' or key == 'text' or key == 'answers', 'initial question payload contains no answer key')
  end
end
check(#reads == 1, 'one selected bank is loaded')
assert(theory.Create(license, 'en'))
check(#reads == 1, 'selected banks are cached')

local function answersFor(correctCount)
  local answers = {}
  for index, expected in ipairs(exam.correctAnswers) do
    answers[index] = index <= correctCount and expected or (expected + 1) % 4
  end
  return answers
end
local allCorrect = assert(theory.Grade(exam, answersFor(10)))
check(allCorrect.score == 10 and allCorrect.total == 10 and allCorrect.passed, 'all correct answers pass')
local threshold = assert(theory.Grade(exam, answersFor(5)))
check(threshold.score == 5 and threshold.passed, 'the exact configured threshold passes')
local below = assert(theory.Grade(exam, answersFor(4)))
check(below.score == 4 and not below.passed, 'one answer below the threshold fails')
local wrong = assert(theory.Grade(exam, answersFor(0)))
check(wrong.score == 0 and not wrong.passed, 'incorrect answers cannot pass')
check(allCorrect.correctAnswers ~= exam.correctAnswers, 'review corrections are copied')
local originalCorrect = exam.correctAnswers[1]
allCorrect.correctAnswers[1] = (originalCorrect + 1) % 4
check(exam.correctAnswers[1] == originalCorrect, 'review consumers cannot mutate the stored answer key')

local invalid = {
  {}, {true}, {[1] = 0, [3] = 1}, {[0] = 0}, {score = 10, passed = true}
}
for _, value in ipairs({-1, 4, 0.5, true, '0', 0 / 0, math.huge, -math.huge}) do
  local answers = answersFor(10)
  answers[1] = value
  invalid[#invalid + 1] = answers
end
local extra = answersFor(10); extra[11] = 0; invalid[#invalid + 1] = extra
local extraKey = answersFor(10); extraKey.score = 10; invalid[#invalid + 1] = extraKey
local missing = answersFor(10); missing[5] = nil; invalid[#invalid + 1] = missing
for _, answers in ipairs(invalid) do
  local result, reason = theory.Grade(exam, answers)
  check(result == nil and reason == 'invalid_result', 'malformed or forged answers are rejected')
end
local result, reason = theory.Grade(exam, nil)
check(result == nil and reason == 'invalid_result', 'missing answers are rejected')
result, reason = theory.Grade(nil, answersFor(10))
check(result == nil and reason == 'invalid_result', 'missing exam state is rejected')

for _, locale in ipairs({'de', 'en', 'es', 'fi', 'fr', 'it', 'nl', 'pl', 'sr', 'sv'}) do
  local localized = assert(theory.Create(license, locale))
  check(localized.locale == locale and #localized.publicQuestions == 10, locale .. ': original bank is available')
  local original = assert(load(QuestionSources[locale], '@server/questions/' .. locale .. '.lua'))()
  for index, question in ipairs(localized.publicQuestions) do
    local source = original[question.id]
    check(question.text == source.text and localized.correctAnswers[index] == source.correct,
      locale .. ': selected text and grading preserve the original question')
    for choice = 1, 4 do
      check(question.answers[choice] == source.answers[choice], locale .. ': original answer positions are retained')
    end
  end
end

local spanish = assert(theory.Create(license, 'es_ES'))
check(spanish.locale == 'es', 'regional locale falls back to its base language')
check(assert(theory.Create(license, 'ES-mx')).locale == 'es', 'locale matching is case-insensitive')
check(assert(theory.Create(license, 'zh-cn')).locale == 'en', 'unsupported languages use the English bank')
check(assert(theory.Create(license)).locale == 'en', 'missing locale uses English')
local safeTheory, safeReads = fixture()
check(assert(safeTheory.Create(license, '../es')).locale == 'en', 'unsafe locale cannot choose an arbitrary resource file')
check(#safeReads == 1 and safeReads[1] == 'server/questions/en.lua', 'invalid locale reads only the default bank')

local fallbackTheory = fixture({en = QuestionSources.en, es = 'return {}'})
check(assert(fallbackTheory.Create(license, 'es')).locale == 'en', 'malformed selected bank falls back to English')
fallbackTheory = fixture({en = QuestionSources.en, es = 'return broken()'})
check(assert(fallbackTheory.Create(license, 'es')).locale == 'en', 'a bank execution failure is contained')
local missingTheory = fixture({})
result, reason = missingTheory.Create(license, 'en')
check(result == nil and reason == 'unavailable', 'an unavailable bank fails before an exam can start')

for _, badLicense in ipairs({
  {kind = 'practical', questionCount = 10, answersNeeded = 5},
  {kind = 'theory', bank = 'unsupported', questionCount = 10, answersNeeded = 5},
  {kind = 'theory', questionCount = 11, answersNeeded = 5},
  {kind = 'theory', questionCount = 0, answersNeeded = 0},
  {kind = 'theory', questionCount = 10.5, answersNeeded = 5},
  {kind = 'theory', questionCount = 10, answersNeeded = 0},
  {kind = 'theory', questionCount = 10, answersNeeded = 11},
  {kind = 'theory', questionCount = '10', answersNeeded = 5}
}) do
  check(theory.Create(badLicense, 'en') == nil, 'invalid exam configuration cannot start')
end
check(theory.Create(nil, 'en') == nil, 'missing licence configuration cannot start')

exam.publicQuestions[1].answers[1] = 'changed'
local another = assert(theory.Create(license, 'en'))
local original = assert(load(QuestionSources.en, '@server/questions/en.lua'))()
check(another.publicQuestions[1].answers[1] == original[another.publicQuestions[1].id].answers[1],
  'mutating one payload cannot change a later exam')
local subset = assert(theory.Create({kind = 'theory', questionCount = 3, answersNeeded = 2}, 'en'))
check(subset.total == 3 and #subset.publicQuestions == 3 and subset.needed == 2, 'smaller configured exams select only their requested questions')

print(('server theory: %d assertions passed'):format(checks))
return checks
