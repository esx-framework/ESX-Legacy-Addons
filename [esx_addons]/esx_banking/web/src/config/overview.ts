export interface Transaction {
  title: string;
  date: string;
  amount: number;
  type: 'positive' | 'negative';
}

export interface GraphPoint {
  x: number;
  y: number;
}

export const config = {
  user: {
    name: 'John Doe'
  },
  transactions: [
    {
      title: 'Grocery Store',
      date: 'Today, 2:30 PM',
      amount: -45.20,
      type: 'negative'
    },
    {
      title: 'Salary Deposit',
      date: 'Yesterday, 9:00 AM',
      amount: 2500.00,
      type: 'positive'
    },
    {
      title: 'Gas Station',
      date: 'Yesterday, 5:15 PM',
      amount: -35.00,
      type: 'negative'
    }
  ],
  graph: {
    points: [
      { x: 0, y: 180 },
      { x: 85, y: 160 },
      { x: 170, y: 140 },
      { x: 255, y: 120 },
      { x: 340, y: 100 },
      { x: 425, y: 80 },
      { x: 510, y: 60 }
    ],
    labels: [
      'Mar 18',
      'Mar 19',
      'Mar 20',
      'Mar 21',
      'Mar 22',
      'Mar 23',
      'Mar 24'
    ]
  },
  balances: {
    bank: 25000,
    cash: 5000
  }
} 