<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script>
  import { get } from "svelte/store"
  import Scoreboard from "./components/Scoreboard.svelte"
  import {
    scoreboardStore,
    ingestActivities,
    ingestPage,
    ingestServerPayload,
    ingestSummary,
    setLoading,
    setVisible
  } from "./stores/scoreboard.js"

  const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "esx_scoreboard"

  const mockData = {
    players: [
      { serverId: 1, name: "John_Doe", job: "police", jobLabel: "Police", jobGrade: "Sergeant", ping: 24 },
      { serverId: 2, name: "Jane_Smith", job: "ambulance", jobLabel: "EMS", jobGrade: "Paramedic", ping: 45 },
      { serverId: 3, name: "Mike_Ross", job: "mechanic", jobLabel: "Mechanic", jobGrade: "Expert", ping: 112 },
      { serverId: 4, name: "Sarah_Connor", job: "police", jobLabel: "Police", jobGrade: "Officer", ping: 34 },
      { serverId: 5, name: "Tony_Stark", job: "unemployed", jobLabel: "Civilian", jobGrade: "", ping: 78 },
      { serverId: 6, name: "Bruce_Wayne", job: "police", jobLabel: "Police", jobGrade: "Chief", ping: 12 }
    ],
    jobs: [
      { name: "police", label: "Police", count: 3, color: "#3B82F6" },
      { name: "ambulance", label: "EMS", count: 1, color: "#EF4444" },
      { name: "mechanic", label: "Mechanic", count: 1, color: "#F59E0B" },
      { name: "unemployed", label: "Civilian", count: 1, color: "#6B7280" }
    ],
    activities: [
      { id: 1, type: "robbery", label: "Fleeca Bank", location: "Legion Square", players: [1, 4] }
    ],
    info: {
      serverName: "ESX Development Server",
      maxPlayers: 2048,
      uptime: 3665,
      logoUrl: ""
    }
  }

  function nuiPost(name, data = {}) {
    return fetch(`https://${resourceName}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data)
    })
  }

  function requestPage(overrides = {}) {
    const current = get(scoreboardStore)
    const payload = {
      page: overrides.page ?? current.page,
      pageSize: overrides.pageSize ?? current.pageSize,
      search: overrides.search ?? current.searchQuery,
      sortBy: overrides.sortBy ?? current.sortBy,
      sortAsc: overrides.sortAsc ?? current.sortAsc
    }

    if (!window.invokeNative) {
      buildLocalPage(payload)
      return
    }

    setLoading(true)
    nuiPost("requestPlayersPage", payload).catch(() => setLoading(false))
  }

  function buildLocalPage(payload) {
    const search = String(payload.search || "").toLowerCase()
    let players = mockData.players.filter((player) => {
      if (!search) return true
      return String(player.serverId).includes(search)
        || player.name.toLowerCase().includes(search)
        || player.job.toLowerCase().includes(search)
        || player.jobLabel.toLowerCase().includes(search)
    })

    players = players.sort((a, b) => {
      let av = a[payload.sortBy]
      let bv = b[payload.sortBy]
      if (typeof av === "string") av = av.toLowerCase()
      if (typeof bv === "string") bv = bv.toLowerCase()
      if (av === bv) return a.serverId - b.serverId
      return payload.sortAsc ? (av > bv ? 1 : -1) : (av < bv ? 1 : -1)
    })

    const pageSize = Math.max(10, Number(payload.pageSize) || 50)
    const totalPages = Math.max(1, Math.ceil(players.length / pageSize))
    const page = Math.min(Math.max(1, Number(payload.page) || 1), totalPages)
    const start = (page - 1) * pageSize

    ingestPage({
      players: players.slice(start, start + pageSize),
      page,
      pageSize,
      total: players.length,
      totalPages,
      search: payload.search,
      sortBy: payload.sortBy,
      sortAsc: payload.sortAsc
    })
  }

  function handleKeyup(e) {
    if (e.key !== "Escape") return
    e.preventDefault()
    e.stopPropagation()
    if (window.invokeNative) {
      nuiPost("closeScoreboard").catch(() => {})
    } else {
      setVisible(false)
    }
  }

  $effect(() => {
    function handleNuiMessage(event) {
      const data = event.data
      if (!data || typeof data !== "object") return

      switch (data.type) {
        case "show":
          setVisible(true)
          break
        case "hide":
          setVisible(false)
          setLoading(false)
          break
        case "updateSummary":
          ingestSummary(data.summary)
          break
        case "updatePage":
          ingestPage(data.page)
          break
        case "updateActivities":
          ingestActivities(data.activities)
          break
        case "updateAll":
          ingestServerPayload(data)
          break
        case "updateTheme":
          {
            const root = document.documentElement
            const colorPattern = /^#[0-9a-f]{6}$/i
            if (colorPattern.test(data.primaryColor || "")) root.style.setProperty("--primary-color", data.primaryColor)
            if (colorPattern.test(data.secondaryColor || "")) root.style.setProperty("--secondary-color", data.secondaryColor)
            if (colorPattern.test(data.backgroundColor || "")) root.style.setProperty("--background-color", data.backgroundColor)
            if (colorPattern.test(data.accentColor || "")) root.style.setProperty("--accent-color", data.accentColor)
            if (/^https:\/\//i.test(data.logoUrl || "")) ingestSummary({ info: { logoUrl: data.logoUrl } })
          }
          break
      }
    }

    window.addEventListener("message", handleNuiMessage)
    window.addEventListener("keyup", handleKeyup)

    if (!window.invokeNative) {
      ingestSummary({
        totalPlayers: mockData.players.length,
        jobs: mockData.jobs,
        activities: mockData.activities,
        info: mockData.info
      })
      setVisible(true)
      buildLocalPage({ page: 1, pageSize: 50, search: "", sortBy: "serverId", sortAsc: true })
    } else {
      nuiPost("nuiReady").catch(() => {})
    }

    return () => {
      window.removeEventListener("message", handleNuiMessage)
      window.removeEventListener("keyup", handleKeyup)
    }
  })
</script>

<Scoreboard onRequestPage={requestPage} />
