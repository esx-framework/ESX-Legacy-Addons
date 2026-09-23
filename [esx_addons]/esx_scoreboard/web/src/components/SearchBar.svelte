<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script>
  import { setPageSize, setSearchQuery } from "../stores/scoreboard.js"

  let { jobs, pageSize = 50, maxPageSize = 100, onRequestPage = () => {} } = $props()

  let searchValue = $state("")
  let searchTimer = 0

  function handleInput(e) {
    searchValue = e.target.value.slice(0, 48)
    setSearchQuery(searchValue)
    clearTimeout(searchTimer)
    searchTimer = setTimeout(() => onRequestPage({ page: 1, search: searchValue }), 350)
  }

  function clearSearch() {
    searchValue = ""
    setSearchQuery("")
    onRequestPage({ page: 1, search: "" })
  }

  function handlePageSize(e) {
    const nextSize = Number(e.target.value)
    setPageSize(nextSize)
    onRequestPage({ page: 1, pageSize: nextSize })
  }
</script>

<div class="search-bar">
  <div class="search-input-wrapper">
    <svg class="search-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <circle cx="11" cy="11" r="8"></circle>
      <path d="m21 21-4.3-4.3"></path>
    </svg>
    <input
      type="text"
      class="search-input"
      placeholder="Search players by name, job, or ID..."
      maxlength="48"
      value={searchValue}
      oninput={handleInput}
    />
    {#if searchValue}
      <button class="clear-btn" onclick={clearSearch} aria-label="Clear search">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 6 6 18"></path>
          <path d="m6 6 12 12"></path>
        </svg>
      </button>
    {/if}
  </div>

  <select class="page-size" value={pageSize} onchange={handlePageSize}>
    {#each [25, 50, 100].filter((size) => size <= maxPageSize) as size}
      <option value={size}>{size} rows</option>
    {/each}
  </select>

  <div class="job-filters">
    {#each jobs.slice(0, 6) as job}
      <span class="job-pill">
        {job.label} <strong>{job.count}</strong>
      </span>
    {/each}
  </div>
</div>

<style>
  .search-bar {
    padding: 14px 28px;
    background: var(--darkest-color);
    border-bottom: 1px solid var(--mid-color);
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 10px;
  }

  .search-input-wrapper {
    position: relative;
    display: flex;
    align-items: center;
  }

  .search-icon {
    position: absolute;
    left: 14px;
    color: var(--light-color);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: 10px 14px 10px 42px;
    background: var(--dark-color);
    border: 1px solid var(--mid-color);
    border-radius: 8px;
    color: var(--lightest-color);
    font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    font-size: 14px;
    outline: none;
    transition: border-color 0.2s ease;
  }

  .page-size {
    width: 108px;
    height: 40px;
    padding: 0 8px;
    background: var(--dark-color);
    border: 1px solid var(--mid-color);
    border-radius: 8px;
    color: var(--lightest-color);
    font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    font-size: 13px;
  }

  .search-input::placeholder {
    color: var(--light-color);
  }

  .search-input:focus {
    border-color: var(--brand-color);
  }

  .clear-btn {
    position: absolute;
    right: 10px;
    background: none;
    border: none;
    color: var(--light-color);
    cursor: pointer;
    padding: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    transition: color 0.2s ease;
  }

  .clear-btn:hover {
    color: var(--lightest-color);
  }

  .job-filters {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 10px;
    grid-column: 1 / -1;
  }

  .job-pill {
    padding: 3px 10px;
    background: var(--dark-color);
    border: 1px solid var(--mid-color);
    border-radius: 12px;
    font-size: 11px;
    color: var(--light-color);
    font-weight: 400;
  }

  .job-pill strong {
    color: var(--brand-color);
    margin-left: 4px;
  }
</style>
