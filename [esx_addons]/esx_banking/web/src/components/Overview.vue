<template>
  <div class="overview">
    <div class="header">
      <div class="user-info">
        <span class="name">{{ config.user.name }}</span>
        <div class="user-circle">
          <img src="/src/svg/overview/user.svg" alt="User" />
        </div>
      </div>
    </div>

    <div class="content">
      <div class="main-grid">
        <div class="top-section">
          <div class="balance-cards">
            <div class="balance-card">
              <div class="balance-title">Bank Balance</div>
              <div class="balance-amount">${{ config.balances.bank.toLocaleString() }}</div>
            </div>
            <div class="balance-card">
              <div class="balance-title">Cash Balance</div>
              <div class="balance-amount">${{ config.balances.cash.toLocaleString() }}</div>
            </div>
          </div>

          <div class="actions">
            <button class="action-button">
              <span>Deposit</span>
            </button>
            <button class="action-button">
              <span>Withdraw</span>
            </button>
            <button class="action-button">
              <span>Transfer</span>
            </button>
          </div>
        </div>

        <div class="bottom-section">
          <div class="graph-section">
            <div class="section-header">
              <h2>Weekly Overview</h2>
            </div>
            <div class="line-graph">
              <img src="/src/svg/overview/graph.svg" alt="Weekly Overview Graph" class="graph" />
              <div class="graph-labels">
                <span v-for="label in config.graph.labels" :key="label">{{ label }}</span>
              </div>
            </div>
          </div>

          <div class="transactions">
            <div class="section-header">
              <h2>Recent Transactions</h2>
            </div>
            <div class="transaction-list">
              <div v-for="transaction in config.transactions" :key="transaction.title" class="transaction">
                <div class="transaction-icon" :class="transaction.type">
                  <img :src="transaction.type === 'positive' ? positiveIcon : negativeIcon" :alt="transaction.type" />
                </div>
                <div class="transaction-info">
                  <div class="transaction-title">{{ transaction.title }}</div>
                  <div class="transaction-date">{{ transaction.date }}</div>
                </div>
                <div class="transaction-amount" :class="transaction.type">
                  {{ transaction.type === 'positive' ? '+' : '-' }}${{ Math.abs(transaction.amount).toFixed(2) }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { config } from '../config/overview';
import positiveIcon from '../svg/overview/positive.svg';
import negativeIcon from '../svg/overview/negative.svg';
</script>

<style scoped>
.overview {
  padding: 19px 24px 24px 12px;
  margin-left: 170px;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.header {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  width: calc(100% + 170px);
  position: relative;
  left: -170px;
  margin-bottom: 10px;
  border-bottom: 1px solid #3A3A3A;
  padding-bottom: 21px;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.name {
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 16px;
  font-weight: 500;
}

.user-circle {
  width: 40px;
  height: 40px;
  background-color: #2A2A2A;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
}

.user-circle img {
  width: 24px;
  height: 24px;
}

.content {
  margin-top: 24px;
  height: calc(100% - 80px);
}

.main-grid {
  display: flex;
  flex-direction: column;
  gap: 16px;
  height: 100%;
  max-width: 100%;
  overflow: hidden;
  padding: 0 8px;
}

.top-section {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.balance-cards {
  display: flex;
  gap: 12px;
}

.balance-card {
  flex: 1;
  background-color: #2A2A2A;
  border-radius: 8px;
  padding: 16px;
}

.balance-title {
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  font-weight: 500;
  margin-bottom: 8px;
}

.balance-amount {
  color: white;
  font-family: 'Poppins', sans-serif;
  font-size: 24px;
  font-weight: 600;
}

.actions {
  display: flex;
  gap: 12px;
}

.action-button {
  flex: 1;
  background-color: #2A2A2A;
  border: none;
  border-radius: 6px;
  padding: 12px;
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.action-button:hover {
  background-color: #3A3A3A;
  color: white;
  transform: translateY(-1px);
}

.bottom-section {
  display: flex;
  gap: 16px;
  flex: 1;
  min-height: 0;
}

.graph-section {
  flex: 1;
  background-color: #2A2A2A;
  border-radius: 8px;
  padding: 16px;
  display: flex;
  flex-direction: column;
}

.section-header {
  margin-bottom: 12px;
}

.section-header h2 {
  color: white;
  font-family: 'Poppins', sans-serif;
  font-size: 16px;
  font-weight: 600;
}

.line-graph {
  position: relative;
  height: 200px;
  width: 100%;
  padding: 0 16px;
  flex: 1;
  display: flex;
  flex-direction: column;
}

.graph {
  width: 100%;
  height: calc(100% - 24px);
}

.graph-labels {
  display: flex;
  justify-content: space-between;
  margin-top: 8px;
  padding: 0 16px;
  width: calc(100% - 32px);
}

.graph-labels span {
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 12px;
  font-weight: 500;
}

.transactions {
  width: 320px;
  background-color: #2A2A2A;
  border-radius: 8px;
  padding: 16px;
  display: flex;
  flex-direction: column;
  max-height: 100%;
  overflow-y: auto;
}

.transaction-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.transaction {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border-radius: 8px;
  transition: all 0.2s ease;
  cursor: pointer;
  gap: 8px;
  border-bottom: 1px solid #3A3A3A;
}

.transaction:last-child {
  border-bottom: none;
}

.transaction:hover {
  background-color: #333333;
}

.transaction-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex: 1;
}

.transaction-icon {
  width: 32px;
  height: 32px;
  background-color: rgba(255, 68, 68, 0.1);
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 4px;
  flex-shrink: 0;
  margin-left: -8px;
}

.transaction-icon img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  transform: scale(0.9);
}

.transaction-icon.positive {
  background-color: rgba(76, 175, 80, 0.1);
}

.transaction-title {
  color: white;
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  font-weight: 500;
  margin-bottom: 2px;
  line-height: 1.2;
}

.transaction-date {
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 12px;
  opacity: 0.7;
  line-height: 1.2;
}

.transaction-amount {
  color: #FF4444;
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  font-weight: 500;
  background-color: rgba(255, 68, 68, 0.1);
  padding: 4px 8px;
  border-radius: 4px;
  flex-shrink: 0;
  min-width: 80px;
  text-align: right;
}

.transaction-amount.positive {
  color: #4CAF50;
  background-color: rgba(76, 175, 80, 0.1);
}
</style> 