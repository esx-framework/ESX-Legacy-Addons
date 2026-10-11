/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

(() => {
  const wrapper = document.getElementById("wrapper");
  const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "esx_banking";
  const quickAmounts = [100, 500, 1000, 5000];
  const actionLabels = {
    deposit: "Deposit",
    withdraw: "Withdraw",
    transfer: "Transfer",
    pincode: "PIN"
  };
  const transactionLabels = {
    DEPOSIT: "Deposit",
    WITHDRAW: "Withdraw",
    TRANSFER: "Transfer",
    TRANSFER_RECEIVE: "Transfer received",
    PINCODE: "PIN updated"
  };

  let state = {
    visible: false,
    unlocked: true,
    activeAction: "deposit",
    busy: false,
    pin: "",
    pinError: "",
    formError: "",
    search: "",
    data: {
      accessType: "bank",
      bankName: "Fleeca Bank",
      playerName: "Unknown",
      cash: 0,
      bank: 0,
      hasPin: false,
      transactions: []
    }
  };

  function isBrowser() {
    return typeof GetParentResourceName !== "function";
  }

  function fetchNui(eventName, data = {}) {
    return fetch(`https://${resourceName}/${eventName}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=UTF-8"
      },
      body: JSON.stringify(data)
    })
      .then((response) => response.json().catch(() => ({})))
      .catch(() => ({}));
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function toNumber(value) {
    const number = Number(value);
    return Number.isFinite(number) ? number : 0;
  }

  function formatMoney(value) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      maximumFractionDigits: 0
    }).format(toNumber(value));
  }

  function formatDate(value) {
    const timestamp = typeof value === "number" ? value : Number(value);
    const date = Number.isFinite(timestamp) ? new Date(timestamp) : new Date(value);

    if (Number.isNaN(date.getTime())) {
      return "Unknown time";
    }

    return new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit"
    }).format(date);
  }

  function normalizeType(type) {
    return String(type || "").toUpperCase();
  }

  function isOutgoing(type) {
    return ["WITHDRAW", "TRANSFER"].includes(normalizeType(type));
  }

  function normalizeTransactions(transactions) {
    if (!Array.isArray(transactions)) {
      return [];
    }

    return transactions.map((transaction) => ({
      label: String(transaction.label || transaction.type || "Transaction"),
      type: normalizeType(transaction.type || transaction.label),
      amount: toNumber(transaction.amount),
      time: toNumber(transaction.time) || Date.parse(transaction.time) || Date.now(),
      balance: toNumber(transaction.balance)
    }));
  }

  function mergePayload(payload) {
    const data = payload || {};
    state.data = {
      ...state.data,
      accessType: data.accessType || state.data.accessType,
      bankName: data.bankName || state.data.bankName,
      playerName: data.playerName || state.data.playerName,
      cash: toNumber(data.cash ?? data.money ?? state.data.cash),
      bank: toNumber(data.bank ?? data.bankMoney ?? state.data.bank),
      hasPin: typeof data.hasPin === "boolean" ? data.hasPin : state.data.hasPin,
      transactions: normalizeTransactions(data.transactions || data.transactionHistory || state.data.transactions)
    };
  }

  function getAvailableActions() {
    if (state.data.accessType === "atm") {
      return ["deposit", "withdraw"];
    }

    return ["deposit", "withdraw", "transfer", "pincode"];
  }

  function ensureValidAction() {
    const actions = getAvailableActions();
    if (!actions.includes(state.activeAction)) {
      state.activeAction = actions[0];
    }
  }

  function getStats() {
    return state.data.transactions.reduce(
      (summary, transaction) => {
        if (isOutgoing(transaction.type)) {
          summary.outgoing += transaction.amount;
        } else {
          summary.incoming += transaction.amount;
        }

        summary.count += 1;
        return summary;
      },
      { incoming: 0, outgoing: 0, count: 0 }
    );
  }

  function filteredTransactions() {
    const search = state.search.trim().toLowerCase();
    if (!search) {
      return state.data.transactions;
    }

    return state.data.transactions.filter((transaction) => {
      const label = `${transaction.label} ${transaction.type} ${transaction.amount}`.toLowerCase();
      return label.includes(search);
    });
  }

  function renderTabs() {
    return getAvailableActions()
      .map((action) => {
        const activeClass = action === state.activeAction ? " active" : "";
        return `<button class="tab-button${activeClass}" type="button" data-action-tab="${action}">${escapeHtml(actionLabels[action])}</button>`;
      })
      .join("");
  }

  function renderQuickAmounts() {
    return `
      <div class="quick-amounts">
        ${quickAmounts
          .map((amount) => `<button class="amount-chip" type="button" data-quick-amount="${amount}">${formatMoney(amount)}</button>`)
          .join("")}
      </div>
    `;
  }

  function renderFormError() {
    return state.formError ? `<div class="form-error">${escapeHtml(state.formError)}</div>` : "";
  }

  function renderActionForm() {
    if (state.activeAction === "transfer") {
      return `
        <form class="form-stack" data-action-form>
          <div class="form-row">
            <input name="amount" type="number" min="1" inputmode="numeric" placeholder="Amount" autocomplete="off" />
            <input name="target" type="number" min="1" inputmode="numeric" placeholder="Player ID" autocomplete="off" />
          </div>
          ${renderQuickAmounts()}
          <button class="primary-button" type="submit" ${state.busy ? "disabled" : ""}>${state.busy ? "Processing" : "Transfer"}</button>
          ${renderFormError()}
        </form>
      `;
    }

    if (state.activeAction === "pincode") {
      return `
        <form class="form-stack" data-action-form>
          <input name="pin" type="password" maxlength="4" inputmode="numeric" placeholder="New 4 digit PIN" autocomplete="off" />
          <button class="primary-button" type="submit" ${state.busy ? "disabled" : ""}>${state.busy ? "Processing" : "Save PIN"}</button>
          ${renderFormError()}
        </form>
      `;
    }

    return `
      <form class="form-stack" data-action-form>
        <input name="amount" type="number" min="1" inputmode="numeric" placeholder="${state.activeAction === "deposit" ? "Cash to deposit" : "Bank funds to withdraw"}" autocomplete="off" />
        ${renderQuickAmounts()}
        <button class="primary-button" type="submit" ${state.busy ? "disabled" : ""}>${state.busy ? "Processing" : escapeHtml(actionLabels[state.activeAction])}</button>
        ${renderFormError()}
      </form>
    `;
  }

  function getActionContextRows() {
    if (state.activeAction === "withdraw") {
      return [
        { label: "Source", title: "Bank", value: formatMoney(state.data.bank) },
        { label: "Destination", title: "Cash", value: formatMoney(state.data.cash) },
      ];
    }

    if (state.activeAction === "transfer") {
      return [
        { label: "Source", title: "Bank", value: formatMoney(state.data.bank) },
        { label: "Destination", title: "Player", value: "Player ID" },
      ];
    }

    if (state.activeAction === "pincode") {
      return [
        { label: "Security", title: "PIN", value: state.data.hasPin ? "Configured" : "Not configured" },
        { label: "Access", title: state.data.accessType === "atm" ? "ATM" : "Branch", value: "Active" },
      ];
    }

    return [
      { label: "Source", title: "Cash", value: formatMoney(state.data.cash) },
      { label: "Destination", title: "Bank", value: formatMoney(state.data.bank) },
    ];
  }

  function renderActionContext(stats) {
    const rows = getActionContextRows();
    const latest = state.data.transactions[0];
    const net = stats.incoming - stats.outgoing;
    const netClass = net < 0 ? " negative" : "";
    const latestOutgoing = latest && isOutgoing(latest.type);
    const latestClass = latestOutgoing ? " negative" : "";
    const latestLabel = latest ? transactionLabels[latest.type] || latest.label || "Movement" : "Latest movement";
    const latestValue = latest
      ? `${latestOutgoing ? "-" : "+"}${formatMoney(latest.amount)}`
      : "No history";

    return `
      <div class="action-context">
        <div class="action-context-grid">
          ${rows
            .map(
              (row) => `
                <div class="action-context-item">
                  <span>${escapeHtml(row.label)}</span>
                  <strong>${escapeHtml(row.title)}</strong>
                  <em>${escapeHtml(row.value)}</em>
                </div>
              `
            )
            .join("")}
        </div>
        <div class="action-context-line">
          <span>Net flow</span>
          <strong class="${netClass}">${net >= 0 ? "+" : "-"}${formatMoney(Math.abs(net))}</strong>
        </div>
        <div class="action-context-line">
          <span>${escapeHtml(latestLabel)}</span>
          <strong class="${latestClass}">${escapeHtml(latestValue)}</strong>
        </div>
      </div>
    `;
  }

  function renderChart() {
    const transactions = state.data.transactions.slice(0, 10).reverse();
    const stats = getStats();
    const net = stats.incoming - stats.outgoing;
    const netClass = net < 0 ? " negative" : "";

    if (!transactions.length) {
      return `
        <div class="flow-header">
          <div>
            <span class="label">Cash flow</span>
            <strong>No movement</strong>
          </div>
          <span class="flow-pill">0 moves</span>
        </div>
        <div class="empty-state">No movement yet</div>
      `;
    }

    const width = 520;
    const height = 150;
    const padding = 18;
    const balances = transactions.map((transaction) => transaction.balance || state.data.bank);
    const minBalance = Math.min(...balances);
    const maxBalance = Math.max(...balances);
    const range = Math.max(1, maxBalance - minBalance);
    const usableWidth = width - padding * 2;
    const usableHeight = height - padding * 2;
    const points = balances.map((balance, index) => {
      const x = transactions.length === 1 ? width / 2 : padding + (index / (transactions.length - 1)) * usableWidth;
      const y = padding + ((maxBalance - balance) / range) * usableHeight;
      return [Number(x.toFixed(1)), Number(y.toFixed(1))];
    });
    const pointString = points.map(([x, y]) => `${x},${y}`).join(" ");
    const baseline = height - padding;
    const areaString = `${points[0][0]},${baseline} ${pointString} ${points[points.length - 1][0]},${baseline}`;
    const firstDate = formatDate(transactions[0].time);
    const lastDate = formatDate(transactions[transactions.length - 1].time);

    return `
      <div class="flow-header">
        <div>
          <span class="label">Cash flow</span>
          <strong class="flow-net${netClass}">${net >= 0 ? "+" : "-"}${formatMoney(Math.abs(net))}</strong>
        </div>
        <span class="flow-pill">${transactions.length} moves</span>
      </div>
      <div class="flow-visual">
        <svg class="flow-svg" viewBox="0 0 ${width} ${height}" preserveAspectRatio="xMidYMid meet" aria-hidden="true">
          <defs>
            <linearGradient id="flowArea" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" stop-color="#fb9b04" stop-opacity="0.38" />
              <stop offset="100%" stop-color="#fb9b04" stop-opacity="0" />
            </linearGradient>
          </defs>
          <line class="flow-grid" x1="${padding}" y1="${padding}" x2="${width - padding}" y2="${padding}" />
          <line class="flow-grid" x1="${padding}" y1="${height / 2}" x2="${width - padding}" y2="${height / 2}" />
          <line class="flow-grid" x1="${padding}" y1="${baseline}" x2="${width - padding}" y2="${baseline}" />
          <polygon class="flow-area" points="${areaString}" />
          <polyline class="flow-line" points="${pointString}" />
          ${points.map(([x, y]) => `<circle class="flow-dot" cx="${x}" cy="${y}" r="4" />`).join("")}
        </svg>
      </div>
      <div class="flow-footer">
        <span>${escapeHtml(firstDate)}</span>
        <span>${formatMoney(minBalance)} - ${formatMoney(maxBalance)}</span>
        <span>${escapeHtml(lastDate)}</span>
      </div>
    `;
  }

  function renderHistoryItems() {
    const transactions = filteredTransactions();

    if (!transactions.length) {
      return '<div class="empty-state">No transactions found</div>';
    }

    return transactions
      .map((transaction) => {
        const outgoing = isOutgoing(transaction.type);
        const amountClass = outgoing ? " out" : "";
        const sign = outgoing ? "-" : "+";
        const label = transactionLabels[transaction.type] || transaction.label;

        return `
          <div class="transaction-item">
            <div class="transaction-icon${amountClass}" aria-hidden="true"></div>
            <div>
              <div class="transaction-title">${escapeHtml(label)}</div>
              <div class="transaction-time">${escapeHtml(formatDate(transaction.time))}</div>
            </div>
            <div class="transaction-amount${amountClass}">${sign}${formatMoney(transaction.amount)}</div>
          </div>
        `;
      })
      .join("");
  }

  function renderHistoryList() {
    const list = wrapper.querySelector("[data-history-list]");
    if (list) {
      list.innerHTML = renderHistoryItems();
    }
  }

  function renderPinDots() {
    return Array.from({ length: 4 }, (_, index) => `<span class="pin-dot${index < state.pin.length ? " filled" : ""}"></span>`).join("");
  }

  function renderPinGate() {
    const hasPin = state.data.hasPin === true;

    return `
      <div class="pin-panel">
        <div class="bank-header">
          <div class="brand">
            <div class="brand-mark">$</div>
            <div>
              <h1>${escapeHtml(state.data.bankName)}</h1>
              <p>ATM access</p>
            </div>
          </div>
          <button class="close-button" type="button" data-close-ui aria-label="Close">
            <span class="close-icon"></span>
          </button>
        </div>
        <div class="pin-content">
          <div class="pin-title">
            <h2>${hasPin ? "Enter PIN" : "PIN required"}</h2>
            <p>${hasPin ? "Unlock this ATM session." : "Set a PIN from a bank branch before using ATMs."}</p>
          </div>
          ${
            hasPin
              ? `
                <div class="pin-dots">${renderPinDots()}</div>
                <div class="pin-grid">
                  ${[1, 2, 3, 4, 5, 6, 7, 8, 9]
                    .map((number) => `<button class="pin-key" type="button" data-pin-key="${number}">${number}</button>`)
                    .join("")}
                  <button class="pin-key danger" type="button" data-pin-clear>Clear</button>
                  <button class="pin-key" type="button" data-pin-key="0">0</button>
                  <button class="pin-key confirm" type="button" data-pin-confirm ${state.busy ? "disabled" : ""}>OK</button>
                </div>
              `
              : ""
          }
          <div class="pin-error">${escapeHtml(state.pinError)}</div>
        </div>
      </div>
    `;
  }

  function renderBanking() {
    ensureValidAction();
    const stats = getStats();
    const total = state.data.cash + state.data.bank;
    const accessLabel = state.data.accessType === "atm" ? "ATM session" : "Branch session";
    const pinLabel = state.data.hasPin ? "Configured" : "Not configured";

    return `
      <main class="bank-shell">
        <header class="bank-header">
          <div class="brand">
            <div class="brand-mark">$</div>
            <div>
              <h1>${escapeHtml(state.data.bankName)}</h1>
              <p>${escapeHtml(accessLabel)}</p>
            </div>
          </div>
          <button class="close-button" type="button" data-close-ui aria-label="Close">
            <span class="close-icon"></span>
          </button>
        </header>

        <div class="bank-layout">
          <section class="main-panel">
            <div class="balance-strip">
              <article class="balance-card accent">
                <span class="label">Bank balance</span>
                <strong class="value">${formatMoney(state.data.bank)}</strong>
                <span class="sub-value">${escapeHtml(state.data.playerName)}</span>
              </article>
              <article class="balance-card">
                <span class="label">Cash</span>
                <strong class="value">${formatMoney(state.data.cash)}</strong>
                <span class="sub-value">Available on hand</span>
              </article>
              <article class="balance-card">
                <span class="label">Total funds</span>
                <strong class="value">${formatMoney(total)}</strong>
                <span class="sub-value">Cash + bank</span>
              </article>
            </div>

            <div class="actions-row">
              <section class="action-panel">
                <div class="tabs">${renderTabs()}</div>
                ${renderActionContext(stats)}
                ${renderActionForm()}
              </section>

              <section class="analytics-panel">
                <div class="mini-stats">
                  <div class="stat-box">
                    <span class="label">In</span>
                    <strong>${formatMoney(stats.incoming)}</strong>
                  </div>
                  <div class="stat-box">
                    <span class="label">Out</span>
                    <strong>${formatMoney(stats.outgoing)}</strong>
                  </div>
                  <div class="stat-box">
                    <span class="label">Moves</span>
                    <strong>${stats.count}</strong>
                  </div>
                </div>
                <div class="chart">${renderChart()}</div>
              </section>
            </div>

            <section class="history-panel">
              <div class="section-header">
                <h2>Recent activity</h2>
                <input class="history-search" type="text" value="${escapeHtml(state.search)}" placeholder="Search transactions..." data-history-search />
              </div>
              <div class="transaction-list" data-history-list>${renderHistoryItems()}</div>
            </section>
          </section>

          <aside class="side-panel">
            <section class="bank-card">
              <div class="card-shine"></div>
              <div class="card-top">
                <span>${escapeHtml(state.data.bankName)}</span>
              </div>
              <div class="card-label">Debit card</div>
              <div class="card-number">2232 2222 2222 2222</div>
              <div class="card-bottom">
                <span>
                  <small>Holder</small>
                  ${escapeHtml(state.data.playerName)}
                </span>
                <span>
                  <small>Expires</small>
                  08/28
                </span>
              </div>
            </section>

            <section class="summary-card">
              <h2>Account</h2>
              <div class="summary-line">
                <span>Access</span>
                <strong>${escapeHtml(accessLabel)}</strong>
              </div>
              <div class="summary-line">
                <span>PIN</span>
                <strong>${escapeHtml(pinLabel)}</strong>
              </div>
              <div class="summary-line">
                <span>Status</span>
                <span class="status-pill">Active</span>
              </div>
            </section>

            <section class="summary-card">
              <h2>Activity</h2>
              <div class="summary-line">
                <span>Incoming</span>
                <strong>${formatMoney(stats.incoming)}</strong>
              </div>
              <div class="summary-line">
                <span>Outgoing</span>
                <strong>${formatMoney(stats.outgoing)}</strong>
              </div>
              <div class="summary-line">
                <span>History</span>
                <strong>${state.data.transactions.length} rows</strong>
              </div>
            </section>
          </aside>
        </div>
      </main>
    `;
  }

  function render() {
    if (!state.visible) {
      wrapper.classList.remove("visible");
      wrapper.setAttribute("aria-hidden", "true");
      wrapper.innerHTML = "";
      return;
    }

    wrapper.classList.add("visible");
    wrapper.setAttribute("aria-hidden", "false");

    if (state.data.accessType === "atm" && !state.unlocked) {
      wrapper.innerHTML = renderPinGate();
      return;
    }

    wrapper.innerHTML = renderBanking();
  }

  function openBanking(payload) {
    mergePayload(payload);
    state.visible = true;
    state.busy = false;
    state.pin = "";
    state.pinError = "";
    state.formError = "";
    state.unlocked = state.data.accessType !== "atm";
    state.activeAction = getAvailableActions()[0];
    render();
  }

  function closeBanking(sendClose = true) {
    state.visible = false;
    state.busy = false;
    state.pin = "";
    state.pinError = "";
    state.formError = "";
    render();

    if (sendClose) {
      fetchNui("close", {});
    }
  }

  function submitAction(form) {
    const formData = new FormData(form);
    const action = state.activeAction;
    let payload = { action };

    if (action === "pincode") {
      const pin = String(formData.get("pin") || "").trim();
      if (!/^\d{4}$/.test(pin)) {
        state.formError = "PIN must be 4 digits";
        render();
        return;
      }

      payload.pin = pin;
    } else {
      const amount = Number(formData.get("amount"));
      if (!Number.isFinite(amount) || amount <= 0) {
        state.formError = "Enter a valid amount";
        render();
        return;
      }

      payload.amount = Math.round(amount);

      if (action === "transfer") {
        const target = Number(formData.get("target"));
        if (!Number.isInteger(target) || target <= 0) {
          state.formError = "Enter a valid player ID";
          render();
          return;
        }

        payload.target = target;
      }
    }

    state.busy = true;
    state.formError = "";
    render();

    fetchNui("clickButton", payload).finally(() => {
      setTimeout(() => {
        state.busy = false;
        render();
      }, 900);
    });
  }

  function submitPin() {
    if (state.pin.length !== 4 || state.busy) {
      return;
    }

    state.busy = true;
    state.pinError = "";
    render();

    fetchNui("checkPincode", state.pin).then((response) => {
      state.busy = false;

      if (response && response.success) {
        state.unlocked = true;
        state.pin = "";
        render();
        return;
      }

      state.pin = "";
      state.pinError = "Invalid PIN";
      render();
    });
  }

  document.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) {
      return;
    }

    const closeButton = target.closest("[data-close-ui]");
    if (closeButton) {
      closeBanking(true);
      return;
    }

    const tabButton = target.closest("[data-action-tab]");
    if (tabButton) {
      state.activeAction = tabButton.getAttribute("data-action-tab") || "deposit";
      state.formError = "";
      render();
      return;
    }

    const quickAmount = target.closest("[data-quick-amount]");
    if (quickAmount) {
      const input = wrapper.querySelector('input[name="amount"]');
      if (input) {
        input.value = quickAmount.getAttribute("data-quick-amount") || "";
        input.focus();
      }
      return;
    }

    const pinKey = target.closest("[data-pin-key]");
    if (pinKey && state.pin.length < 4) {
      state.pin += pinKey.getAttribute("data-pin-key") || "";
      state.pinError = "";
      render();
      return;
    }

    if (target.closest("[data-pin-clear]")) {
      state.pin = "";
      state.pinError = "";
      render();
      return;
    }

    if (target.closest("[data-pin-confirm]")) {
      submitPin();
    }
  });

  document.addEventListener("submit", (event) => {
    const form = event.target;
    if (form instanceof HTMLFormElement && form.matches("[data-action-form]")) {
      event.preventDefault();
      submitAction(form);
    }
  });

  document.addEventListener("input", (event) => {
    const target = event.target;
    if (target instanceof HTMLInputElement && target.matches("[data-history-search]")) {
      state.search = target.value;
      renderHistoryList();
    }
  });

  document.addEventListener("keyup", (event) => {
    if (event.key === "Escape" && state.visible) {
      closeBanking(true);
    }
  });

  window.addEventListener("message", ({ data }) => {
    if (!data || typeof data !== "object") {
      return;
    }

    if (data.action === "openBanking") {
      openBanking(data.payload || {});
      return;
    }

    if (data.action === "closeBanking" || data.showMenu === false) {
      closeBanking(false);
      return;
    }

    if (data.action === "updateBanking") {
      mergePayload(data.payload || {});
      state.busy = false;
      render();
      return;
    }

    if (data.showMenu && data.datas) {
      const accounts = data.datas.your_money_panel?.accountsData || [];
      const cash = accounts.find((account) => account.name === "cash")?.amount || 0;
      const bank = accounts.find((account) => account.name === "bank")?.amount || 0;

      openBanking({
        accessType: data.openATM ? "atm" : "bank",
        bankName: data.datas.bankCardData?.bankName,
        playerName: data.datas.bankCardData?.name,
        cash,
        bank,
        hasPin: true,
        transactions: data.datas.transactionsData || []
      });
      return;
    }

    if (data.updateData) {
      mergePayload(data.data || {});
      state.busy = false;
      render();
    }
  });

  if (isBrowser()) {
    openBanking({
      accessType: "bank",
      bankName: "Fleeca Bank",
      playerName: "Development User",
      cash: 12850,
      bank: 76400,
      hasPin: true,
      transactions: [
        { label: "Paycheck", type: "DEPOSIT", amount: 2500, time: Date.now() - 900000, balance: 76400 },
        { label: "Vehicle repair", type: "WITHDRAW", amount: 650, time: Date.now() - 3400000, balance: 73900 },
        { label: "Transfer", type: "TRANSFER", amount: 1200, time: Date.now() - 8600000, balance: 74550 },
        { label: "Transfer received", type: "TRANSFER_RECEIVE", amount: 4200, time: Date.now() - 14800000, balance: 75750 },
        { label: "Store purchase", type: "WITHDRAW", amount: 180, time: Date.now() - 24000000, balance: 71550 }
      ]
    });
  }
})();
