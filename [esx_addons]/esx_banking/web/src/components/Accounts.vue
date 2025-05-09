<template>
  <div class="accounts">
    <div class="header">
      <div class="title">Accounts</div>
      <button class="new-account-btn">
        <img src="/src/svg/overview/positive.svg" alt="Add" class="btn-icon" />
        <span>New Account</span>
      </button>
    </div>

    <div class="accounts-list">
      <div 
        v-for="account in accounts" 
        :key="account.id" 
        class="account-card"
        :class="{ active: selectedAccount?.id === account.id }"
        @click="selectAccount(account)"
      >
        <div class="account-info">
          <div class="account-header">
            <div class="account-name">{{ account.name }}</div>
          </div>
          <div class="account-number">****{{ account.number.slice(-4) }}</div>
        </div>
        <div class="account-balance">${{ account.balance.toLocaleString() }}</div>
      </div>
    </div>

    <div class="content" v-if="selectedAccount">
      <div class="account-actions">
        <div class="section-header">
          <h2>{{ selectedAccount.name }}</h2>
          <div class="account-number">Account: ****{{ selectedAccount.number.slice(-4) }}</div>
        </div>
        
        <div class="balance-section">
          <div class="balance-label">Available Balance</div>
          <div class="balance-amount">${{ selectedAccount.balance.toLocaleString() }}</div>
          <div class="balance-info">Last updated: {{ new Date().toLocaleDateString() }}</div>
        </div>

        <div class="actions">
          <button class="action-button">
            <img src="/src/svg/overview/positive.svg" alt="Deposit" class="action-icon" />
            <span>Deposit</span>
          </button>
          <button class="action-button">
            <img src="/src/svg/overview/negative.svg" alt="Withdraw" class="action-icon" />
            <span>Withdraw</span>
          </button>
          <button class="action-button">
            <img src="/src/svg/overview/transfer.svg" alt="Transfer" class="action-icon" />
            <span>Transfer</span>
          </button>
        </div>
      </div>

      <div class="account-management">
        <div class="section-header">
          <h2>Account Management</h2>
        </div>
        <div class="management-actions">
          <button class="management-button">
            <img src="/src/svg/overview/transfer.svg" alt="Transfer Ownership" class="action-icon" />
            <span>Transfer Ownership</span>
          </button>
          <button class="management-button">
            <img src="/src/svg/overview/share.svg" alt="Share Account" class="action-icon" />
            <span>Share Account</span>
          </button>
          <button class="management-button">
            <img src="/src/svg/overview/access.svg" alt="Manage Access" class="action-icon" />
            <span>Manage Access</span>
          </button>
          <button class="management-button delete">
            <img src="/src/svg/overview/delete.svg" alt="Delete Account" class="action-icon" />
            <span>Delete Account</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

interface Account {
  id: string;
  name: string;
  number: string;
  balance: number;
}

const accounts = ref<Account[]>([
  {
    id: '1',
    name: 'Main Account',
    number: '1234567890',
    balance: 5000.00
  },
  {
    id: '2',
    name: 'Savings',
    number: '0987654321',
    balance: 10000.00
  },
  {
    id: '3',
    name: 'Investment',
    number: '5678901234',
    balance: 25000.00
  },
  {
    id: '4',
    name: 'Business Account',
    number: '2468135790',
    balance: 75000.00
  },
  {
    id: '5',
    name: 'Emergency Fund',
    number: '1357924680',
    balance: 15000.00
  },
  {
    id: '6',
    name: 'Vacation Fund',
    number: '9876543210',
    balance: 8000.00
  },
  {
    id: '7',
    name: 'Retirement',
    number: '1122334455',
    balance: 100000.00
  },
  {
    id: '8',
    name: 'Education Fund',
    number: '5544332211',
    balance: 30000.00
  }
]);

const selectedAccount = ref<Account | null>(accounts.value[0]);

const selectAccount = (account: Account) => {
  selectedAccount.value = account;
};
</script>

<style scoped>
.accounts {
  padding: 19px 24px 24px 12px;
  margin-left: 170px;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: calc(100% + 170px);
  position: relative;
  left: -170px;
  margin-bottom: 10px;
  border-bottom: 1px solid #3A3A3A;
  padding-bottom: 21px;
  padding-left: 170px;
}

.title {
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 24px;
  font-weight: 600;
  margin-left: 12px;
}

.new-account-btn {
  background-color: #4CAF50;
  border: none;
  border-radius: 6px;
  padding: 10px 20px;
  color: white;
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: 8px;
}

.new-account-btn:hover {
  background-color: #45a049;
  transform: translateY(-1px);
}

.btn-icon {
  width: 16px;
  height: 16px;
  filter: brightness(0) invert(1);
}

.accounts-list {
  display: flex;
  gap: 12px;
  margin-bottom: 24px;
  overflow-x: auto;
  padding-bottom: 12px;
  scroll-behavior: smooth;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: thin;
  scrollbar-color: #666666 #2A2A2A;
}

.accounts-list::-webkit-scrollbar {
  height: 8px;
}

.accounts-list::-webkit-scrollbar-track {
  background: #2A2A2A;
  border-radius: 4px;
}

.accounts-list::-webkit-scrollbar-thumb {
  background-color: #666666;
  border-radius: 4px;
  border: 2px solid #2A2A2A;
}

.accounts-list::-webkit-scrollbar-thumb:hover {
  background-color: #808080;
}

.account-card {
  background-color: #2A2A2A;
  border-radius: 8px;
  padding: 16px;
  cursor: pointer;
  transition: all 0.3s ease;
  border: 2px solid transparent;
  min-width: 280px;
  flex-shrink: 0;
  position: relative;
  overflow: hidden;
  margin-top: 4px;
}

.account-card::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(45deg, rgba(102, 102, 102, 0.1), transparent);
  opacity: 0;
  transition: opacity 0.3s ease;
}

.account-card:hover::after {
  opacity: 1;
}

.account-card:hover {
  background-color: #333333;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
}

.account-card.active {
  border-color: #666666;
  background-color: #333333;
  box-shadow: 0 4px 12px rgba(102, 102, 102, 0.2);
}

.account-info {
  margin-bottom: 8px;
}

.account-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.account-name {
  color: white;
  font-family: 'Poppins', sans-serif;
  font-size: 16px;
  font-weight: 500;
}

.account-number {
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  opacity: 0.7;
}

.account-balance {
  color: #4CAF50;
  font-family: 'Poppins', sans-serif;
  font-size: 18px;
  font-weight: 600;
}

.content {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  flex: 1;
}

.account-actions, .account-management {
  background-color: #2A2A2A;
  border-radius: 8px;
  padding: 20px;
  display: flex;
  flex-direction: column;
}

.account-actions {
  gap: 16px;
}

.account-management {
  gap: 12px;
  padding: 32px;
}

.section-header {
  margin-bottom: 8px;
}

.section-header h2 {
  color: white;
  font-family: 'Poppins', sans-serif;
  font-size: 22px;
  font-weight: 600;
  margin-bottom: 4px;
}

.balance-section {
  background-color: #333333;
  border-radius: 8px;
  padding: 16px;
}

.balance-label {
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  margin-bottom: 4px;
}

.balance-amount {
  color: white;
  font-family: 'Poppins', sans-serif;
  font-size: 28px;
  font-weight: 600;
  margin-bottom: 4px;
}

.balance-info {
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 12px;
  opacity: 0.7;
}

.actions {
  display: flex;
  gap: 8px;
}

.action-button {
  flex: 1;
  background-color: #333333;
  border: none;
  border-radius: 6px;
  padding: 10px;
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.action-button:hover {
  background-color: #404040;
  color: white;
  transform: translateY(-1px);
}

.action-icon {
  width: 16px;
  height: 16px;
  filter: brightness(0) invert(0.8);
}

.action-button:hover .action-icon {
  filter: brightness(0) invert(1);
}

.management-actions {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.management-button {
  display: flex;
  align-items: center;
  gap: 12px;
  background-color: #333333;
  border: none;
  border-radius: 6px;
  padding: 14px 20px;
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 15px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  text-align: left;
}

.management-button:hover {
  background-color: #404040;
  color: white;
  transform: translateY(-1px);
}

.management-button.delete {
  color: #FF4444;
  margin-top: auto;
}

.management-button.delete:hover {
  background-color: rgba(255, 68, 68, 0.1);
}

.management-button .action-icon {
  width: 22px;
  height: 22px;
  filter: brightness(0) invert(0.8);
}

.management-button:hover .action-icon {
  filter: brightness(0) invert(1);
}

.management-button.delete .action-icon {
  filter: brightness(0) saturate(100%) invert(37%) sepia(93%) saturate(1352%) hue-rotate(325deg) brightness(101%) contrast(101%);
}

.management-button.delete:hover .action-icon {
  filter: brightness(0) saturate(100%) invert(37%) sepia(93%) saturate(1352%) hue-rotate(325deg) brightness(101%) contrast(101%);
}
</style> 