/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */
import { icon } from './icons.js';

const root = document.getElementById('app');
const modalRoot = document.getElementById('modal-root');
let modalOpen = false;
let modalReturnFocus = null;
const resource = GetParentResourceName();
const reportedSessions = new Set(),
	missingKeys = new Set();
const state = {
	visible: false,
	screen: 'home',
	locale: 'en',
	ui: {},
	labels: {},
	school: {},
	licenses: [],
	currency: '$',
	prices: {},
	owned: {},
	theory: {},
	practicalRules: {},
	selectedLicense: null,
	questions: [],
	answers: [],
	questionIndex: 0,
	reviewIndex: 0,
	session: null,
	result: null,
	hud: null,
	hudErrors: [],
	pending: false,
	error: '',
	confirmClose: false,
};

const escape = (value) =>
	String(value ?? '').replace(
		/[&<>"']/g,
		(char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char],
	);
const plain = (value) =>
	String(value ?? '')
		.replace(/~[a-zA-Z0-9_]+~/g, '')
		.replace(/<[^>]*>/g, '');
function t(key, params = {}) {
	const value = state.ui[key];
	if (typeof value !== 'string') {
		if (!missingKeys.has(key)) {
			console.warn('[esx_dmvschool] Missing UI label:', key);
			missingKeys.add(key);
		}
		return key;
	}
	return value.replace(/\{(\w+)\}/g, (match, name) =>
		Object.prototype.hasOwnProperty.call(params, name) ? String(params[name]) : match,
	);
}
const text = (key, params) => escape(plain(t(key, params)));
const license = (id) => state.licenses.find((entry) => entry.id === id);
const ids = () => state.licenses.map((entry) => entry.id);
const isTheory = (id) => license(id)?.kind === 'theory';
const theoryId = () => state.theory.id || state.licenses.find((entry) => entry.kind === 'theory')?.id;
const licenseName = (id) => plain(license(id)?.label) || plain(state.labels[id] || '');
const licenseIcon = (id) => license(id)?.icon || (isTheory(id) ? 'book-open' : state.school.icon || 'navigation');
const price = (id) => state.prices[id] ?? license(id)?.price;
const schoolTitle = () => plain(state.school.title) || plain(t('school_name'));
function brandHeading() {
	const title = schoolTitle().trim(), label = plain(state.ui.school_label).trim();
	const normalizedTitle = title.toLowerCase(), normalizedLabel = label.toLowerCase();
	let location = '';
	if (label && normalizedTitle.startsWith(normalizedLabel + ' ')) location = title.slice(label.length);
	else if (label && normalizedTitle.endsWith(' ' + normalizedLabel)) location = title.slice(0, -label.length);
	location = location.replace(/^[\s|·:–—-]+|[\s|·:–—-]+$/g, '').trim();
	return `<strong class="dmv-brand-heading"><span class="dmv-brand-title">${escape(location ? label : title)}</span>${location ? ` <small class="dmv-brand-subtitle">${escape(location)}</small>` : ''}</strong>`;
}
const money = (amount) => escape(state.currency) + escape(Number(amount).toLocaleString(state.locale, { maximumFractionDigits: 0 }));
const count = () => Number(state.theory.questionCount), needed = () => Number(state.theory.answersNeeded);
const canSelect = (id) => {
	const entry = license(id);
	return Boolean(entry && !state.owned[id] && (!entry.requires || state.owned[entry.requires]) && Number.isFinite(Number(price(id))));
};
function normalizeSelection() {
	if (!canSelect(state.selectedLicense)) state.selectedLicense = ids().find(canSelect) || null;
}
function button(action, label, kind = 'primary', disabled = false, extra = '') {
	return `<button type="button" class="ui-btn ${kind}" data-action="${action}"${disabled ? ' disabled' : ''}${extra ? ' ' + extra : ''}>${label}</button>`;
}
function responseError(response) {
	const key = 'error_' + String(response?.error || '');
	return plain(typeof state.ui[key] === 'string' ? t(key) : t('request_failed'));
}
async function post(name, data = {}) {
	const controller = new AbortController(),
		timeout = setTimeout(() => controller.abort(), 15000);
	try {
		const response = await fetch(`https://${resource}/${name}`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(data),
			signal: controller.signal,
		});
		if (!response.ok) throw new Error('NUI ' + name + ' returned ' + response.status);
		return await response.json();
	} finally {
		clearTimeout(timeout);
	}
}
function normalizeQuestions(value) {
	if (!Array.isArray(value)) throw new Error('Invalid examination questions');
	const entries = value.map((question) => ({
		id: question.id,
		text: typeof question.text === 'string' ? question.text : '',
		answers: Array.isArray(question.answers) ? question.answers.map((answer) => typeof answer === 'string' ? answer : '') : [],
	}));
	if (
		!entries.length ||
		new Set(entries.map((question) => question.id)).size !== entries.length ||
		entries.some(
			(question) =>
				!question.text || question.id === undefined || question.answers.length !== 4 || question.answers.some((answer) => !answer),
		)
	)
		throw new Error('Invalid examination questions');
	return entries;
}
function validTheory() {
	return (
		Number.isInteger(count()) &&
		count() > 0 &&
		Number.isInteger(needed()) &&
		needed() > 0 &&
		needed() <= count()
	);
}
function context(data = {}) {
	if (data.school && typeof data.school === 'object') state.school = { ...data.school };
	if (Array.isArray(data.licenses)) state.licenses = data.licenses.filter((entry) => typeof entry?.id === 'string' && ['theory', 'practical'].includes(entry.kind)).map((entry) => ({ ...entry }));
	if (typeof data.locale === 'string') state.locale = data.locale;
	if (data.ui && typeof data.ui === 'object') state.ui = { ...state.ui, ...data.ui };
	if (data.labels && typeof data.labels === 'object')
		state.labels = { ...state.labels, ...data.labels };
	if (data.prices && typeof data.prices === 'object') state.prices = { ...data.prices };
	if (data.owned && typeof data.owned === 'object') state.owned = { ...data.owned };
	if (data.theory && typeof data.theory === 'object') state.theory = { ...data.theory };
	if (data.practical && typeof data.practical === 'object')
		state.practicalRules = { ...data.practical };
	if (typeof data.currency === 'string') state.currency = data.currency;
	document.documentElement.lang = state.locale;
	document.title = schoolTitle();
}
function setVisible(visible) {
	state.visible = Boolean(visible);
	document.body.classList.toggle('dmv-visible', state.visible);
	if (!state.visible) {
		stopTaskMotion();
		stopFaultMotion();
		state.confirmClose = false;
		clearModal(false);
	}
}
function home() {
	normalizeSelection();
	const allOwned = ids().length > 0 && ids().every((id) => state.owned[id]),
		step = allOwned ? 3 : state.owned[theoryId()] ? 2 : 1;
	const steps = [
		['flow_theory', 'flow_theory_detail', 'book-open'],
		['flow_practical', 'flow_practical_detail', state.school.icon || 'navigation'],
		['flow_permit', 'flow_permit_detail', 'shield-check'],
	];
	return `<section class="dmv-flow-card" aria-label="${text('flow_label')}"><ol class="dmv-flow-steps">${steps
		.map(([title, detail, symbol], index) => {
			const done = allOwned || index + 1 < step,
				current = !allOwned && index + 1 === step;
			return `<li class="${done ? 'is-done' : current ? 'is-current' : 'is-pending'}"${current ? ' aria-current="step"' : ''}><span class="dmv-flow-node">${icon(done ? 'check' : symbol)}</span><strong>${text(title)}</strong></li>`;
		})
		.join(
			'',
		)}</ol></section><div class="dmv-list-heading"><h2>${text('home_choose')}</h2></div><div class="dmv-permits" aria-label="${text('home_selection')}">${ids()
		.map((id) => {
			const done = Boolean(state.owned[id]),
				locked = Boolean(license(id)?.requires && !state.owned[license(id).requires]);
			return `<button type="button" class="dmv-permit${state.selectedLicense === id ? ' is-selected' : ''}${locked ? ' is-locked' : ''}${done ? ' is-owned' : ''}" data-action="select-license" data-license="${id}" aria-pressed="${state.selectedLicense === id}"${!canSelect(id) ? ' disabled' : ''}><span class="dmv-permit-icon">${icon(licenseIcon(id))}</span><span class="dmv-permit-copy"><strong>${escape(licenseName(id))}</strong><small>${text(done ? 'home_obtained' : locked ? 'home_requires_theory' : isTheory(id) ? 'screen_quiz' : 'common_practical')}</small></span><span class="dmv-permit-price">${done ? icon('check') : Number.isFinite(Number(price(id))) ? money(price(id)) : '—'}</span>${locked ? `<span class="dmv-permit-lock" aria-label="${text('home_locked')}">${icon('lock-keyhole')}</span>` : '<span class="dmv-selected-dot" aria-hidden="true"></span>'}</button>`;
		})
		.join('')}</div>`;
}
function briefing() {
	const theory = isTheory(state.selectedLicense),
		rules = state.practicalRules,
		limits = rules.speedLimits || {};
	const points = theory
		? [
				[
					icon('book-open'),
					t('briefing_question_rule', { count: count() }),
					t('briefing_review_rule'),
				],
				[
					icon('shield-check'),
					t('briefing_pass_rule', { count: needed() }),
					t('briefing_result_rule'),
				],
			]
		: [
				[icon('route'), t('briefing_task_rule', { count: license(state.selectedLicense)?.taskCount ?? rules.checkpoints ?? rules.tasks ?? '—' }), t('briefing_follow_instruction')],
				[icon('shield-check'), t('briefing_error_rule', { count: rules.maxErrors }), t('briefing_manoeuvre_rule')],
				...(state.school.id === 'dmv' && [limits.residence, limits.town, limits.freeway].every(Number.isFinite)
					? [[icon('gauge'), t('briefing_speed_rule', { residence: limits.residence, town: limits.town, freeway: limits.freeway, unit: rules.unit || '' }), t('briefing_traffic_rule')]]
					: []),
			];
	return `<section class="exam-panel"><div class="briefing-license">${icon(licenseIcon(state.selectedLicense))}<div><span class="eyebrow">${text(theory ? 'common_theory' : 'common_practical')}</span><h2>${escape(licenseName(state.selectedLicense))}</h2></div><strong>${money(price(state.selectedLicense))}</strong></div><div class="briefing-points">${points.map(([symbol, title, copy]) => `<div class="briefing-point">${symbol}<span><b>${escape(plain(title))}</b><br>${escape(plain(copy))}</span></div>`).join('')}<div class="briefing-point">${icon('info')}<span><b>${text('briefing_price_rule')}</b><br>${text('briefing_refund_rule')}</span></div></div><div class="exam-bottom briefing-bottom"><div class="exam-bottom-actions">${button('home', text('common_back'), 'ghost', state.pending)}${button('pay-start', text(state.pending ? 'starting' : 'briefing_start') + ' ' + icon('arrow-right'), 'primary', state.pending)}</div></div></section>`;
}
function quiz() {
	const question = state.questions[state.questionIndex];
	if (!question) return '';
	return `<section class="exam-panel"><div class="exam-heading"><h2>${text('screen_quiz')}</h2><div class="exam-step">${String(state.questionIndex + 1).padStart(2, '0')}<span> / ${state.questions.length}</span></div></div><div class="exam-progress" role="progressbar" aria-label="${text('quiz_progress')}" aria-valuemin="0" aria-valuemax="${state.questions.length}" aria-valuenow="${state.questionIndex}">${state.questions.map((_, index) => `<span class="${index < state.questionIndex ? 'done' : index === state.questionIndex ? 'current' : ''}"></span>`).join('')}</div><h3 class="question-text" id="question-text">${escape(question.text)}</h3><div class="answers-grid" role="radiogroup" aria-labelledby="question-text">${question.answers.map((answer, index) => `<button type="button" role="radio" aria-checked="${state.answers[state.questionIndex] === index}" tabindex="${state.answers[state.questionIndex] === index || (!Number.isInteger(state.answers[state.questionIndex]) && index === 0) ? 0 : -1}" class="answer-option ${state.answers[state.questionIndex] === index ? 'selected' : ''}" data-action="answer" data-index="${index}"><span class="answer-letter">${'ABCD'[index]}</span><span class="answer-label">${escape(answer)}</span><span class="answer-check">${icon('check')}</span></button>`).join('')}</div><div class="exam-bottom quiz-bottom"><div class="exam-bottom-actions">${button('previous', icon('arrow-left') + ' ' + text('common_previous'), 'ghost', state.questionIndex === 0)}${button('next', text(state.questionIndex === state.questions.length - 1 ? 'quiz_finish' : 'common_next') + ' ' + icon('arrow-right'), 'primary', !Number.isInteger(state.answers[state.questionIndex]))}</div></div></section>`;
}
function failures() {
	return state.questions.flatMap((question, index) =>
		!Number.isInteger(question.correct) || state.answers[index] === question.correct
			? []
			: [{ question, index, answer: state.answers[index] }],
	);
}
function result() {
	const value = state.result || {},
		practical = value.kind === 'practical',
		wrong = practical ? [] : failures(),
		score = practical ? value.errors : value.score,
		total = practical ? state.practicalRules.maxErrors : value.total || state.questions.length,
		pending = value.pending,
		resultLicense = practical ? value.license : theoryId();
	return `<section class="exam-panel"><div class="result-header"><span class="result-symbol ${value.passed ? '' : 'failed'}">${icon(pending ? 'clock' : value.passed ? 'check' : 'x')}</span><h2>${text(pending ? 'result_pending' : value.passed ? (practical ? 'result_practical_passed' : 'result_theory_passed') : 'result_failed')}</h2></div><div class="result-score"><div><span class="eyebrow">${text(practical ? 'result_errors' : 'result_correct')}</span><p>${text(practical ? 'result_practical_minimum' : 'result_theory_minimum', { count: practical ? state.practicalRules.maxErrors : needed() })}</p></div><strong>${escape(score ?? '—')}<span> / ${escape(total ?? '—')}</span></strong></div>${value.passed && !value.submissionFailed && !value.confirmed && !state.owned[resultLicense] ? `<p class="result-copy" role="status">${text('notify_license_pending')}</p>` : ''}${practical ? incidentLog(value.incidents) : ''}<div class="result-actions">${wrong.length ? button('review', text(wrong.length === 1 ? 'result_review_one' : 'result_review_many', { count: wrong.length }) + ' ' + icon('book-open'), 'secondary') : ''}${button('home', text('result_home'), 'primary', state.pending)}</div></section>`;
}
function review() {
	const wrong = failures(),
		position = Math.min(state.reviewIndex, Math.max(0, wrong.length - 1)),
		entry = wrong[position];
	if (!entry)
		return `<section class="exam-panel"><h2>${text('review_all_correct')}</h2>${button('result', text('review_back'), 'secondary')}</section>`;
	return `<section class="exam-panel exam-review" aria-label="${text('review_label')}"><div class="exam-heading"><h2>${text('screen_review')}</h2><div class="exam-step">${String(position + 1).padStart(2, '0')}<span> / ${wrong.length}</span></div></div><div class="review-question-meta"><span>${text('review_question', { current: entry.index + 1, total: state.questions.length })}</span></div><h3 class="question-text" id="review-question-text" tabindex="-1">${escape(entry.question.text)}</h3><div class="review-answers"><div class="review-answer is-wrong"><span class="review-answer-icon">${icon('x')}</span><div><span class="eyebrow">${text('review_your_answer')}</span><p>${Number.isInteger(entry.answer) ? escape(entry.question.answers[entry.answer]) : text('review_unanswered')}</p></div></div><div class="review-answer is-correct"><span class="review-answer-icon">${icon('check')}</span><div><span class="eyebrow">${text('review_correct_answer')}</span><p>${escape(entry.question.answers[entry.question.correct])}</p></div></div></div><div class="exam-bottom review-bottom"><div class="exam-bottom-actions">${button('review-prev', icon('arrow-left') + ' ' + text('common_previous'), 'ghost', position === 0)}${button('review-next', text('common_next') + ' ' + icon('arrow-right'), 'primary', position === wrong.length - 1)}</div></div><div class="review-result-action">${button('result', text('review_back'), 'secondary')}</div></section>`;
}
function incidentReason(value) {
	const reason = typeof value === 'string' ? value : value?.code || value?.reason || '';
	const key = 'incident_' + reason;
	return plain(typeof state.ui[key] === 'string' ? t(key) : reason || t('incident_unknown'));
}
function incidentLog(entries) {
	if (!Array.isArray(entries) || !entries.length) return '';
	return `<section class="dmv-incidents" aria-label="${text('result_incidents')}"><h3>${text('result_incidents')}</h3><ol>${entries.map((entry) => {
		const seconds = Math.max(0, Math.floor(Number(entry.elapsed || 0) / 1000));
		const time = Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0');
		return `<li><time>${time}</time><div><strong>${escape(incidentReason(entry))}</strong>${entry.stage ? `<span>${escape(plain(entry.stage))}</span>` : ''}</div></li>`;
	}).join('')}</ol></section>`;
}
function practical() {
	const hud = state.hud || {}, hasLimit = hud.limit !== null && hud.limit !== undefined && Number.isFinite(Number(hud.limit)) && Number(hud.limit) > 0;
	const total = Math.max(1, Math.floor(Number(hud.total ?? state.practicalRules.checkpoints) || 1));
	const current = Math.min(total, Math.max(1, Math.floor(Number(hud.checkpoint) || 1)));
	const maximum = Math.max(1, Math.floor(Number(hud.maxErrors ?? state.practicalRules.maxErrors) || 5));
	const faults = Math.min(maximum, Math.max(0, Math.floor(Number(hud.errors) || 0)));
	const taskLabel = text('hud_task', {current, total});
	const faultLabel = text('hud_errors', {count: faults, max: maximum});
	const stepKey = JSON.stringify([state.session, hud.vehicle, state.locale, current, plain(hud.stage), plain(hud.instruction)]);
	const hold = Math.min(1, Math.max(0, Number(hud.holdProgress) || 0));
	const hasHold = ['stop', 'park', 'finish'].includes(hud.taskType);
	const holding = hud.taskStatus === 'ready' || hold > 0;
	const holdKeys = { driver: 'hud_driver', engine: 'hud_engine', engine_off: 'hud_engine_off',
		footprint: hud.taskType === 'park' ? 'hud_fit_park' : 'hud_fit', heading: 'hud_align',
		speed: 'hud_stop', reverse: 'hud_reverse' };
	const parkingHints = { parking_turn_left: 'hud_parking_turn_left', parking_turn_right: 'hud_parking_turn_right' };
	const holdLabel = holding ? 'hud_hold' : parkingHints[hud.parkingHint] || holdKeys[hud.taskStatus] || 'hud_position';
	const errors = state.hudErrors.filter((entry) => Date.now() - entry.received < 9000);
	const metric = (label, value, unit = '', accent = false) => `<div class="dmv-hud-metric${accent ? ' is-warning' : ''}"><span>${text(label)}</span><strong>${escape(value)}<small>${escape(unit)}</small></strong></div>`;
	return `<section class="dmv-task-panel" data-session="${escape(state.session || '')}" data-checkpoint="${current}">
		<div class="dmv-task-summary" data-hud-part="summary">
			<div class="exam-step dmv-task-count" aria-label="${taskLabel}">${String(current).padStart(2, '0')}<span> / ${total}</span></div>
			<div class="dmv-faults${faults === maximum ? ' is-exhausted' : ''}" role="img" aria-label="${faultLabel}" title="${faultLabel}">
				<span class="dmv-faults-label" aria-hidden="true">${text('practical_errors')}</span>
				<div class="dmv-fault-slots" aria-hidden="true">${Array.from({length: maximum}, (_, index) => `<span class="dmv-fault-slot${index < faults ? ' is-used' : ''}" data-fault="${index}">${icon('x')}</span>`).join('')}</div>
			</div>
		</div>
		<div class="dmv-step-viewport"><article class="dmv-step-slide" data-step-key="${escape(stepKey)}"><h2>${escape(plain(hud.stage) || t('common_practical'))}</h2>${hud.instruction ? `<p class="dmv-task-instruction">${escape(plain(hud.instruction))}</p>` : ''}</article></div>
		<div class="exam-progress dmv-task-progress" data-hud-part="progress" role="progressbar" aria-label="${taskLabel}" aria-valuemin="0" aria-valuemax="${total}" aria-valuenow="${current - 1}">${Array.from({length: total}, (_, index) => `<span class="${index < current - 1 ? 'done' : index === current - 1 ? 'current' : ''}"${index === current - 1 ? ' aria-current="step"' : ''}></span>`).join('')}</div>
		<div data-hud-part="telemetry"><div class="dmv-hud-metrics">${Number.isFinite(Number(hud.distance)) && hud.distance !== null ? metric('hud_distance', Math.max(0, Math.round(Number(hud.distance))), 'm') : ''}${hud.speed !== null && hud.speed !== undefined ? metric('hud_speed', Math.round(Number(hud.speed) || 0), hud.unit || state.practicalRules.unit || '', hasLimit && Number(hud.speed) > Number(hud.limit)) : ''}${hasLimit ? metric('practical_limit', hud.limit, hud.unit || state.practicalRules.unit || '') : ''}</div>${hasHold ? `<div class="dmv-hold"><div><span>${text(holdLabel)}</span>${holding ? `<strong>${Math.round(hold * 100)}%</strong>` : ''}</div>${holding ? `<div class="dmv-hold-track" role="progressbar" aria-label="${text('hud_hold')}" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(hold * 100)}"><span style="width:${hold * 100}%"></span></div>` : ''}</div>` : ''}${errors.length ? `<div class="dmv-hud-errors" role="status">${errors.map((entry) => `<p>${icon('triangle-alert')}<span>${escape(incidentReason(entry))}</span></p>`).join('')}</div>` : ''}</div>
	</section>`;
}
function closeDialog() {
	return `<div class="dmv-modal-overlay"><section class="dmv-modal" role="alertdialog" aria-modal="true" aria-labelledby="close-title" aria-describedby="close-copy" tabindex="-1"><div class="dmv-modal-heading">${icon('triangle-alert')}<h2 id="close-title">${text('close_title')}</h2></div><p id="close-copy">${text('close_copy')}</p><div class="dmv-modal-actions">${button('resume', text('close_resume'), 'primary', state.pending)}${button('abandon', text('close_exit'), 'secondary', state.pending)}</div></section></div>`;
}
function rememberModalFocus() {
	const focused = document.activeElement;
	if (focused && root.contains(focused) && focused.dataset.action) {
		modalReturnFocus = {
			action: focused.dataset.action,
			index: focused.dataset.index,
		};
	} else modalReturnFocus = { action: 'close' };
}
function modalButtons() {
	return [...modalRoot.querySelectorAll('button:not([disabled])')];
}
function focusModal(action = 'resume') {
	const buttons = modalButtons();
	const target = buttons.find((button) => button.dataset.action === action) || buttons[0];
	(target || modalRoot.querySelector('.dmv-modal'))?.focus({ preventScroll: true });
}
function clearModal(restoreFocus = true) {
	const wasOpen = modalOpen;
	modalRoot.replaceChildren();
	root.inert = false;
	root.removeAttribute('aria-hidden');
	modalOpen = false;
	if (wasOpen && restoreFocus && state.visible) {
		const descriptor = modalReturnFocus;
		const action = /^[a-z-]+$/.test(descriptor?.action || '') ? descriptor.action : 'close';
		const index = /^[0-3]$/.test(descriptor?.index || '') ? descriptor.index : null;
		const selector = `[data-action="${action}"]${index !== null ? `[data-index="${index}"]` : ''}`;
		const target = root.querySelector(selector) || root.querySelector('[data-action="close"]');
		if (!target?.disabled) target?.focus({ preventScroll: true });
	}
	modalReturnFocus = null;
}
function renderModal() {
	if (!state.visible || !state.confirmClose) {
		clearModal();
		return;
	}
	const activeAction = modalRoot.contains(document.activeElement)
		? document.activeElement?.dataset.action
		: 'resume';
	modalRoot.innerHTML = closeDialog();
	root.inert = true;
	root.setAttribute('aria-hidden', 'true');
	modalOpen = true;
	focusModal(activeAction);
}
function footer() {
	if (state.screen !== 'home') return '';
	if (ids().length && ids().every((id) => state.owned[id]))
		return `<div class="dmv-complete">${icon('shield-check')}<span>${text('home_all_owned')}</span></div>`;
	return `<button class="dmv-primary" type="button" data-action="continue"${!canSelect(state.selectedLicense) || state.pending || (isTheory(state.selectedLicense) && !validTheory()) ? ' disabled' : ''}>${text('home_continue')}${icon('arrow-right')}</button>`;
}
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let sizeAnimation = null;
let taskMotion = null;
const faultMotions = new Set();
function stopFaultMotion() {
	faultMotions.forEach((animation) => animation.cancel());
	faultMotions.clear();
}
function stopTaskMotion() {
	if (!taskMotion) return;
	const previous = taskMotion;
	taskMotion = null;
	previous.animations.forEach((animation) => animation.cancel());
	previous.outgoing.remove();
	previous.viewport.style.height = '';
}
function slideTask(viewport, incoming, direction, animate) {
	const previous = viewport.querySelector('.dmv-step-slide:not(.is-leaving)');
	if (previous?.dataset.stepKey === incoming.dataset.stepKey) return;
	const fromHeight = viewport.getBoundingClientRect().height;
	const outgoing = previous?.cloneNode(true);
	stopTaskMotion();
	viewport.replaceChildren(incoming);
	if (!animate || !outgoing || reducedMotion.matches || typeof incoming.animate !== 'function') return;
	const toHeight = incoming.getBoundingClientRect().height;
	viewport.style.height = fromHeight + 'px';
	outgoing.classList.add('is-leaving');
	outgoing.setAttribute('aria-hidden', 'true');
	viewport.append(outgoing);
	const motion = {viewport, outgoing, animations: []};
	taskMotion = motion;
	const distance = direction < 0 ? -32 : 32;
	motion.animations = [
		outgoing.animate([{transform: 'translateX(0)', opacity: 1}, {transform: `translateX(${-distance}px)`, opacity: 0}], {duration: 180, easing: 'ease-out', fill: 'forwards'}),
		incoming.animate([{transform: `translateX(${distance}px)`, opacity: 0}, {transform: 'translateX(0)', opacity: 1}], {duration: 340, easing: 'cubic-bezier(.22,1,.36,1)'}),
		viewport.animate([{height: fromHeight + 'px'}, {height: toHeight + 'px'}], {duration: 340, easing: 'cubic-bezier(.22,1,.36,1)', fill: 'forwards'}),
	];
	Promise.all(motion.animations.map((animation) => animation.finished)).then(() => {
		if (taskMotion === motion) stopTaskMotion();
	}).catch(() => {});
}
function patchPractical(panel) {
	const current = panel.querySelector('.dmv-task-panel');
	if (!current) return false;
	const template = document.createElement('template');
	template.innerHTML = practical();
	const incoming = template.content.firstElementChild;
	const sameSession = current.dataset.session === incoming.dataset.session;
	const previousFaults = current.querySelectorAll('.dmv-fault-slot.is-used').length;
	const direction = Number(incoming.dataset.checkpoint) - Number(current.dataset.checkpoint);
	for (const part of ['summary', 'progress', 'telemetry']) {
		const existingPart = current.querySelector(`[data-hud-part="${part}"]`);
		const incomingPart = incoming.querySelector(`[data-hud-part="${part}"]`);
		if (existingPart.outerHTML !== incomingPart.outerHTML) existingPart.replaceWith(incomingPart);
	}
	slideTask(current.querySelector('.dmv-step-viewport'), incoming.querySelector('.dmv-step-slide'), direction, sameSession);
	current.dataset.session = incoming.dataset.session;
	current.dataset.checkpoint = incoming.dataset.checkpoint;
	if (sameSession && !reducedMotion.matches) {
		const used = [...current.querySelectorAll('.dmv-fault-slot.is-used')];
		used.slice(previousFaults).forEach((slot) => {
			if (typeof slot.animate !== 'function') return;
			const animation = slot.animate([{opacity: .4, transform: 'translateY(3px)'}, {opacity: 1, transform: 'translateY(0)'}], {duration: 240, easing: 'ease-out'});
			faultMotions.add(animation);
			animation.finished.then(() => faultMotions.delete(animation)).catch(() => faultMotions.delete(animation));
		});
	}
	return true;
}
reducedMotion.addEventListener('change', () => {
	if (reducedMotion.matches) { stopTaskMotion(); stopFaultMotion(); sizeAnimation?.cancel(); }
});
function render() {
	if (!state.visible) return;
	const practicalPanel = root.querySelector('.dmv--practical');
	if (state.screen === 'practical' && practicalPanel && patchPractical(practicalPanel)) return;
	stopTaskMotion();
	stopFaultMotion();
	if (state.confirmClose && !modalOpen) rememberModalFocus();
	const panel = root.querySelector('.dmv'),
		from = panel?.getBoundingClientRect();
	sizeAnimation?.cancel();
	sizeAnimation = null;
	const titles = {
			home: 'school_name',
			briefing: 'screen_briefing',
			quiz: 'screen_quiz',
			result: 'screen_result',
			review: 'screen_review',
			practical: 'screen_practical',
		},
		body = { home, briefing, quiz, result, review, practical }[state.screen] || home,
		bottom = footer(),
		template = document.createElement('template');
	template.innerHTML = `<section class="dmv dmv--${state.screen}" aria-label="${escape(schoolTitle())}"><header class="dmv-top"><div class="dmv-brand"><img src="assets/esx-logo.png" width="800" height="301" alt="ESX"><span></span>${brandHeading()}</div>${state.screen === 'practical' ? '' : `<button class="dmv-close" type="button" data-action="close" aria-label="${text('school_close')}"${state.pending ? ' disabled' : ''}>${icon('x')}</button>`}</header><main class="dmv-body">${state.error ? `<p class="submit-feedback" role="alert">${escape(state.error)}</p>` : ''}${body()}</main>${bottom ? `<footer class="dmv-footer">${bottom}</footer>` : ''}</section>`;
	const next = template.content.querySelector('.dmv');
	if (panel && next) {
		panel.className = next.className;
		for (const attribute of [...panel.attributes])
			if (attribute.name !== 'class') panel.removeAttribute(attribute.name);
		for (const attribute of [...next.attributes])
			if (attribute.name !== 'class') panel.setAttribute(attribute.name, attribute.value);
		panel.replaceChildren(...next.childNodes);
		next.replaceWith(panel);
	}
	root.replaceChildren(template.content);
	root.dataset.screen = state.screen;
	const current = root.querySelector('.dmv'),
		to = current?.getBoundingClientRect();
	if (
		from &&
		to &&
		!reducedMotion.matches &&
		typeof current.animate === 'function' &&
		(Math.abs(from.width - to.width) > 0.5 || Math.abs(from.height - to.height) > 0.5)
	)
		sizeAnimation = current.animate(
			[
				{ width: from.width + 'px', height: from.height + 'px' },
				{ width: to.width + 'px', height: to.height + 'px' },
			],
			{ duration: 280, easing: 'cubic-bezier(.22,1,.36,1)' },
		);
	renderModal();
}
function showError(key) {
	state.error = plain(t(key));
	render();
}
async function payStart() {
	if (state.screen !== 'briefing' || state.pending || !canSelect(state.selectedLicense)) return;
	if (isTheory(state.selectedLicense) && !validTheory()) {
		showError('invalid_test');
		return;
	}
	state.pending = true;
	state.error = '';
	render();
	try {
		const response = await post('startTest', { license: state.selectedLicense });
		if (!response.ok) state.error = responseError(response);
	} catch (error) {
		console.error('[' + resource + ']', 'startTest', error);
		state.error = plain(t('request_failed'));
	} finally {
		state.pending = false;
		render();
	}
}
async function finishTheory() {
	if (
		state.screen !== 'quiz' ||
		!state.session ||
		reportedSessions.has(state.session) ||
		state.questions.some((_, index) => !Number.isInteger(state.answers[index]))
	)
		return;
	const session = state.session;
	reportedSessions.add(session);
	state.result = { kind: 'theory', session, total: state.questions.length, pending: true };
	state.screen = 'result';
	state.pending = true;
	render();
	const fail = (message) => {
		if (state.session !== session) return;
		const finalResult = state.result?.session === session && !state.result.pending &&
			(Number.isInteger(state.result.score) || state.result.cancelled);
		if (!finalResult) {
			reportedSessions.delete(session);
			state.screen = 'quiz';
			state.result = null;
		}
		state.error = message;
	};
	try {
		const response = await post('theoryResult', { session, answers: [...state.answers] });
		if (response.result?.session === session) await receive('dmv:result', response.result);
		if (!response.ok) fail(responseError(response));
	} catch (error) {
		console.error('[' + resource + ']', 'theoryResult', error);
		fail(plain(t('request_failed')));
	} finally {
		if (state.session === session) {
			if (state.result) state.result.pending = false;
			state.pending = false;
			render();
		}
	}
}
async function returnHome() {
	if (state.pending || state.screen === 'practical') return;
	state.pending = true;
	state.error = '';
	render();
	try {
		const response = await post('returnToMenu');
		if (!response.ok) state.error = responseError(response);
	} catch (error) {
		console.error('[' + resource + ']', 'returnToMenu', error);
		state.error = plain(t('request_failed'));
	} finally {
		state.pending = false;
		render();
	}
}
async function close(abandon = false) {
	if (state.pending || state.screen === 'practical') return;
	if (state.screen === 'quiz' && !abandon) {
		state.confirmClose = true;
		render();
		return;
	}
	state.pending = true;
	render();
	try {
		const response = await post('close', { abandon });
		if (response.ok) {
			state.confirmClose = false;
			setVisible(false);
		} else state.error = responseError(response);
	} catch (error) {
		console.error('[' + resource + ']', 'close', error);
		state.error = plain(t('request_failed'));
	} finally {
		state.pending = false;
		render();
	}
}
function act(action, target) {
	if (state.screen === 'practical' || state.pending) return;
	if (action === 'resume') {
		state.confirmClose = false;
		render();
		return;
	}
	if (state.confirmClose) {
		if (action === 'abandon') close(true);
		return;
	}
	if (action === 'close') {
		close();
		return;
	}
	if (action === 'select-license' && state.screen === 'home' && canSelect(target.dataset.license)) {
		state.selectedLicense = target.dataset.license;
		state.error = '';
		render();
		return;
	}
	if (action === 'continue' && state.screen === 'home' && canSelect(state.selectedLicense)) {
		state.screen = 'briefing';
		state.error = '';
		render();
		return;
	}
	if (action === 'pay-start') {
		payStart();
		return;
	}
	if (action === 'home') {
		returnHome();
		return;
	}
	if (action === 'answer' && state.screen === 'quiz') {
		const index = Number(target.dataset.index);
		if (Number.isInteger(index) && index >= 0 && index < 4) {
			state.answers[state.questionIndex] = index;
			render();
			root
				.querySelector(`[data-action="answer"][data-index="${index}"]`)
				?.focus({ preventScroll: true });
		}
		return;
	}
	if (action === 'previous' && state.screen === 'quiz') {
		state.questionIndex = Math.max(0, state.questionIndex - 1);
		render();
		return;
	}
	if (
		action === 'next' &&
		state.screen === 'quiz' &&
		Number.isInteger(state.answers[state.questionIndex])
	) {
		if (state.questionIndex < state.questions.length - 1) {
			state.questionIndex++;
			render();
		} else finishTheory();
		return;
	}
	if (
		action === 'review' &&
		state.screen === 'result' &&
		state.result?.kind === 'theory' &&
		failures().length
	) {
		state.screen = 'review';
		state.reviewIndex = 0;
		render();
		return;
	}
	if (action === 'result' && state.screen === 'review') {
		state.screen = 'result';
		render();
		return;
	}
	if ((action === 'review-prev' || action === 'review-next') && state.screen === 'review') {
		state.reviewIndex = Math.min(
			Math.max(0, state.reviewIndex + (action === 'review-next' ? 1 : -1)),
			failures().length - 1,
		);
		render();
		root.querySelector('#review-question-text')?.focus({ preventScroll: true });
	}
}
async function receive(action, data = {}) {
	if (action === 'dmv:licenses') {
		if (data.owned && typeof data.owned === 'object') {
			state.owned = { ...data.owned };
			if (state.screen === 'home') normalizeSelection();
			render();
		}
		return;
	}
	if (action === 'dmv:close') {
		state.pending = false;
		state.confirmClose = false;
		setVisible(false);
		return;
	}
	if (action === 'dmv:home') {
		context(data);
		state.screen = 'home';
		state.pending = false;
		state.error = '';
		state.confirmClose = false;
		normalizeSelection();
		setVisible(true);
		if (!validTheory()) state.error = plain(t('invalid_test'));
		render();
		return;
	}
	if (action === 'dmv:theory') {
		if (typeof data.session !== 'string' || !data.session || state.session === data.session) return;
		context(data);
		state.theory = {
			...state.theory,
			questionCount: Number(data.questionCount ?? state.theory.questionCount),
			answersNeeded: Number(data.answersNeeded ?? state.theory.answersNeeded),
		};
		try {
			const questions = normalizeQuestions(data.questions);
			if (!validTheory() || questions.length !== count()) throw new Error('Invalid examination question count');
			state.questions = questions;
			state.answers = [];
			state.questionIndex = 0;
			state.reviewIndex = 0;
			state.session = data.session;
			state.result = null;
			state.error = '';
			state.confirmClose = false;
			state.screen = 'quiz';
			setVisible(true);
		} catch (error) {
			console.error('[' + resource + ']', 'Unable to start paid theory test', error);
			state.error = plain(t('notify_bank_unavailable'));
			post('close', { abandon: true }).catch(console.error);
		}
		render();
		return;
	}
	if (action === 'dmv:practical') {
		if (data.active === false) return;
		if (state.session !== data.session) state.hudErrors = [];
		if (data.lastError && !state.hudErrors.some((entry) => entry.time === data.lastError.time && entry.reason === data.lastError.reason)) {
			state.hudErrors = [...state.hudErrors, { ...data.lastError, received: Date.now() }].slice(-2);
		}
		state.hud = { ...data };
		state.session = data.session || state.session;
		state.screen = 'practical';
		state.pending = false;
		state.error = '';
		state.confirmClose = false;
		setVisible(true);
		render();
		return;
	}
	if (action === 'dmv:result') {
		if (data.session && state.session && data.session !== state.session) return;
		if (data.kind === 'theory' && Array.isArray(data.correctAnswers) && data.correctAnswers.length === state.questions.length &&
			data.correctAnswers.every((answer) => Number.isInteger(answer) && answer >= 0 && answer < 4)) {
			state.questions = state.questions.map((question, index) => ({...question, correct: data.correctAnswers[index]}));
		}
		state.result = { ...data, pending: false };
		state.screen = 'result';
		state.pending = false;
		state.confirmClose = false;
		state.error = '';
		setVisible(true);
		render();
	}
}
function onActionClick(event) {
	if (!state.visible) return;
	const target = event.target.closest('[data-action]');
	if (!target || target.disabled) return;
	const fromModal = modalRoot.contains(target);
	if (state.confirmClose ? !fromModal : fromModal) return;
	event.preventDefault();
	act(target.dataset.action, target);
}
root.addEventListener('click', onActionClick);
modalRoot.addEventListener('click', onActionClick);
document.addEventListener('focusin', (event) => {
	if (state.visible && state.confirmClose && !modalRoot.contains(event.target)) focusModal();
});
document.addEventListener('keydown', (event) => {
	if (!state.visible) return;
	if (state.confirmClose) {
		if (event.key === 'Tab') {
			event.preventDefault();
			const buttons = modalButtons();
			if (!buttons.length) focusModal();
			else {
				const index = buttons.indexOf(document.activeElement);
				const next =
					index < 0
						? event.shiftKey
							? buttons.length - 1
							: 0
						: (index + (event.shiftKey ? -1 : 1) + buttons.length) % buttons.length;
				buttons[next].focus({ preventScroll: true });
			}
		} else if (event.key === 'Escape') {
			event.preventDefault();
			if (!state.pending) act('resume', event.target);
		}
		return;
	}
	if (
		!state.visible ||
		state.screen === 'practical' ||
		state.pending ||
		event.target.matches('input,textarea,select')
	)
		return;
	if (event.key === 'Escape') {
		event.preventDefault();
		if (state.confirmClose) {
			state.confirmClose = false;
			render();
		} else close();
		return;
	}
	if (state.screen === 'quiz' && !state.confirmClose) {
		if (/^[1-4]$/.test(event.key)) {
			event.preventDefault();
			act('answer', { dataset: { index: String(Number(event.key) - 1) } });
		}
		if (
			['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp'].includes(event.key) &&
			event.target.closest('[role="radiogroup"]')
		) {
			event.preventDefault();
			const direction = ['ArrowRight', 'ArrowDown'].includes(event.key) ? 1 : -1;
			act('answer', {
				dataset: { index: String((Number(event.target.dataset.index) + direction + 4) % 4) },
			});
		}
	}
});
window.addEventListener('message', (event) => {
	const message = event.data;
	if (!message || typeof message.action !== 'string' || !message.action.startsWith('dmv:')) return;
	receive(
		message.action,
		message.data && typeof message.data === 'object' ? message.data : {},
	).catch((error) => console.error('[' + resource + ']', error));
});
window.addEventListener('beforeunload', () => { sizeAnimation?.cancel(); stopTaskMotion(); stopFaultMotion(); });
post('ready').catch((error) => console.error('[' + resource + ']', 'NUI ready failed', error));
