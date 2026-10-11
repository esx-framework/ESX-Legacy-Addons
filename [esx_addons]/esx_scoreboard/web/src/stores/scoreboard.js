/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

import { writable, derived } from "svelte/store"

/**
 * @typedef {Object} PlayerData
 * @property {number} serverId
 * @property {string} name
 * @property {string} job
 * @property {string} jobLabel
 * @property {string} jobGrade
 * @property {number} ping
 * @property {string|null} activity
 */

/**
 * @typedef {Object} JobCount
 * @property {string} name
 * @property {string} label
 * @property {number} count
 * @property {string} color
 */

/**
 * @typedef {Object} ActivityData
 * @property {number} id
 * @property {string} type
 * @property {string} label
 * @property {string} location
 * @property {number} startTime
 */

const initialState = {
  visible: false,
  loading: false,
  players: [],
  jobs: [],
  activities: [],
  searchQuery: "",
  sortBy: "serverId",
  sortAsc: true,
  serverName: "ESX Server",
  maxPlayers: 128,
  uptime: 0,
  logoUrl: "",
  totalPlayers: 0,
  page: 1,
  pageSize: 50,
  total: 0,
  totalPages: 1,
  paging: {
    defaultPageSize: 50,
    maxPageSize: 100
  }
}

const VALID_COLUMNS = ["serverId", "name", "job", "ping"]

export const scoreboardStore = writable(initialState)

export const filteredPlayers = derived(scoreboardStore, ($state) => $state.players)
export const totalPlayers = derived(scoreboardStore, ($state) => $state.totalPlayers)
export const activeActivityCount = derived(scoreboardStore, ($state) => $state.activities.length)

function asText(value, fallback = "") {
  if (typeof value !== "string") return fallback
  const text = value.replace(/[\u0000-\u001f\u007f]/g, "").trim()
  return text || fallback
}

function asNumber(value, fallback = 0) {
  const number = Number(value)
  return Number.isFinite(number) ? number : fallback
}

function safeHex(value, fallback = "#6B7280") {
  return /^#[0-9a-f]{6}$/i.test(value || "") ? value : fallback
}

function safeUrl(value) {
  const url = asText(value, "")
  return /^https:\/\//i.test(url) ? url : ""
}

function normalizePlayer(player) {
  const job = asText(player?.job, "unemployed")
  return {
    serverId: Math.max(0, Math.floor(asNumber(player?.serverId, 0))),
    name: asText(player?.name, "Unknown").slice(0, 64),
    job,
    jobLabel: asText(player?.jobLabel, job).slice(0, 64),
    jobGrade: asText(player?.jobGrade, "").slice(0, 64),
    ping: Math.max(0, Math.floor(asNumber(player?.ping, 0))),
    activity: asText(player?.activity, "")
  }
}

function normalizeJob(job) {
  const name = asText(job?.name, "unemployed")
  return {
    name,
    label: asText(job?.label, name).slice(0, 64),
    count: Math.max(0, Math.floor(asNumber(job?.count, 0))),
    color: safeHex(job?.color)
  }
}

function normalizeActivity(activity) {
  return {
    id: Math.floor(asNumber(activity?.id, 0)),
    type: asText(activity?.type, "activity").slice(0, 50),
    label: asText(activity?.label, "Activity").slice(0, 100),
    location: asText(activity?.location, "").slice(0, 100),
    startTime: Math.max(0, Math.floor(asNumber(activity?.startTime, 0)))
  }
}

export function setVisible(visible) {
  scoreboardStore.update((s) => ({ ...s, visible }))
}

export function setLoading(loading) {
  scoreboardStore.update((s) => ({ ...s, loading }))
}

export function setSearchQuery(query) {
  scoreboardStore.update((s) => ({ ...s, searchQuery: asText(query, "").slice(0, 48) }))
}

export function setPageSize(pageSize) {
  scoreboardStore.update((s) => ({
    ...s,
    pageSize: Math.max(10, Math.min(s.paging.maxPageSize, Math.floor(asNumber(pageSize, s.pageSize))))
  }))
}

export function setSortBy(column) {
  if (!VALID_COLUMNS.includes(column)) return
  scoreboardStore.update((s) => ({
    ...s,
    sortBy: column,
    sortAsc: s.sortBy === column ? !s.sortAsc : true
  }))
}

export function ingestSummary(summary) {
  if (!summary || typeof summary !== "object") return

  scoreboardStore.update((s) => {
    const maxPageSize = Math.max(10, Math.min(100, Math.floor(asNumber(summary.paging?.maxPageSize, s.paging.maxPageSize))))
    const defaultPageSize = Math.max(10, Math.min(maxPageSize, Math.floor(asNumber(summary.paging?.defaultPageSize, s.paging.defaultPageSize))))

    return {
      ...s,
      jobs: Array.isArray(summary.jobs) ? summary.jobs.map(normalizeJob) : s.jobs,
      activities: Array.isArray(summary.activities) ? summary.activities.map(normalizeActivity) : s.activities,
      totalPlayers: Math.max(0, Math.floor(asNumber(summary.totalPlayers, s.totalPlayers))),
      serverName: asText(summary.info?.serverName, s.serverName).slice(0, 80),
      maxPlayers: Math.max(1, Math.floor(asNumber(summary.info?.maxPlayers, s.maxPlayers))),
      uptime: Math.max(0, Math.floor(asNumber(summary.info?.uptime, s.uptime))),
      logoUrl: safeUrl(summary.info?.logoUrl),
      paging: { defaultPageSize, maxPageSize },
      pageSize: Math.min(s.pageSize, maxPageSize)
    }
  })
}

export function ingestPage(page) {
  if (!page || typeof page !== "object") return

  scoreboardStore.update((s) => ({
    ...s,
    loading: false,
    players: Array.isArray(page.players) ? page.players.map(normalizePlayer) : [],
    page: Math.max(1, Math.floor(asNumber(page.page, 1))),
    pageSize: Math.max(10, Math.min(s.paging.maxPageSize, Math.floor(asNumber(page.pageSize, s.pageSize)))),
    total: Math.max(0, Math.floor(asNumber(page.total, 0))),
    totalPages: Math.max(1, Math.floor(asNumber(page.totalPages, 1))),
    searchQuery: asText(page.search, s.searchQuery).slice(0, 48),
    sortBy: VALID_COLUMNS.includes(page.sortBy) ? page.sortBy : s.sortBy,
    sortAsc: page.sortAsc === true
  }))
}

export function ingestActivities(activities) {
  scoreboardStore.update((s) => ({
    ...s,
    activities: Array.isArray(activities) ? activities.map(normalizeActivity) : []
  }))
}

export function ingestServerPayload(data) {
  const players = Array.isArray(data.players) ? data.players.map(normalizePlayer) : []

  scoreboardStore.update((s) => ({
    ...s,
    loading: false,
    players,
    jobs: Array.isArray(data.jobs) ? data.jobs.map(normalizeJob) : s.jobs,
    activities: Array.isArray(data.activities) ? data.activities.map(normalizeActivity) : s.activities,
    totalPlayers: players.length,
    total: players.length,
    totalPages: 1,
    serverName: asText(data.info?.serverName, s.serverName).slice(0, 80),
    maxPlayers: Math.max(1, Math.floor(asNumber(data.info?.maxPlayers, s.maxPlayers))),
    uptime: Math.max(0, Math.floor(asNumber(data.info?.uptime, s.uptime))),
    logoUrl: safeUrl(data.info?.logoUrl)
  }))
}
