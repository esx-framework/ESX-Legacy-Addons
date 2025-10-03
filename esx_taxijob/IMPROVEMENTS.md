# ESX Taxi Job - Enhanced Features

## 🎉 Major Improvements Overview

This taxi job has been significantly enhanced with multiple new features to create a more engaging, realistic, and rewarding experience for players.

---

## ✨ New Features

### 1. **Dynamic Pricing System**
- **Distance-based earnings**: Players earn money based on actual distance traveled (0.15 per meter)
- **Time-based compensation**: Earnings for waiting time (2.0 per second)
- **Base fare**: Random base fare between $300-$600 per trip
- **Smart calculation**: Total = Base + Distance Bonus + Time Bonus + Multipliers

### 2. **Tip System** 🎁
- **60% chance** customers will give a tip ($50-$200)
- **Perfect Drive Bonus**: 1.5x tip multiplier for smooth, crash-free rides
- **Enhanced notifications**: Tips are displayed separately in earnings notifications
- **Driver incentive**: Encourages careful, professional driving

### 3. **Reputation System** ⭐
- **Start at 50/100 reputation**
- **Gain +2 reputation** per successful, perfect drive
- **Lose -5 reputation** for crashes or poor service
- **Reputation bonus**: At 75+ reputation, earn **25% more** on all fares
- **Visible in menu**: Check your current reputation in the taxi menu

### 4. **Multiple Vehicle Types**
Choose from different taxi types with earning multipliers:
- **Economy Taxi** (standard taxi): 1.0x multiplier
- **Standard Taxi** (taxi2): 1.2x multiplier  
- **Luxury Limo** (stretch): 1.8x multiplier (requires grade 2+)

Each vehicle shows its earning potential in the spawn menu!

### 5. **Special Mission Types** 🎯

#### VIP Clients
- **15% spawn chance**
- **+$750 bonus**
- Yellow notification: "~y~VIP CLIENT~s~"

#### Airport Runs
- **~5% spawn chance**
- **+$500 bonus**
- Blue notification: "~b~AIRPORT RUN~s~"

#### Long Distance Trips
- **Triggered on 5000+ meter trips**
- **+$400 bonus**
- Green notification: "~g~LONG DISTANCE~s~"

### 6. **Rush Hour System** 🚦
- **Morning rush**: 7:00 AM - 9:00 AM
- **Evening rush**: 5:00 PM - 7:00 PM
- **1.5x earnings multiplier** during rush hours
- Encourages playing during peak times

### 7. **Weather Bonuses** 🌧️
- **1.3x multiplier** during:
  - Rain
  - Thunderstorms
  - Clearing weather
- Rewards drivers who work in difficult conditions

### 8. **Perfect Drive Tracking** 🚗
- Monitors vehicle damage throughout the trip
- Triggers bonuses for crash-free deliveries
- Affects tip amounts and reputation
- Visual "Perfect Drive!" notification on completion

### 9. **Enhanced UI & Notifications** 💬
Improved notifications show:
- Base fare breakdown
- Tips received
- Perfect drive status
- Mission type indicators
- Reputation changes

Example: `"Company: $420 | You: $180 ~g~+$150 tip! ~b~Perfect Drive!"`

---

## 📊 Earnings Calculation Example

**Scenario**: Long distance VIP client during rush hour in luxury limo, perfect drive

```
Base Fare: $450
Distance (4500m × $0.15): $675
Time Bonus (120s × $2.0): $240
Subtotal: $1,365

Vehicle Multiplier (Luxury): ×1.8 = $2,457
Rush Hour Bonus: ×1.5 = $3,685.50
VIP Bonus: +$750 = $4,435.50
Reputation Bonus (75+ rep): ×1.25 = $5,544.38

Tip (perfect drive): $150 × 1.5 = $225

TOTAL EARNINGS: $5,769.38
(Player keeps ~30% + tip = $1,888.31)
```

---

## 🎮 How to Play

### Starting Out
1. Go to taxi depot (marked on map)
2. Change into work clothes at cloakroom
3. Spawn your preferred taxi type
4. Press **F6** or use the menu to start taking fares

### Maximizing Earnings
- **Drive carefully** to maintain reputation and earn perfect drive bonuses
- **Use luxury vehicles** when available for higher multipliers
- **Work during rush hours** for 1.5x earnings
- **Don't refuse bad weather** - it pays more!
- **Build your reputation** to unlock the 25% permanent bonus

### Vehicle Selection
- Early drivers: Use economy taxi to learn the ropes
- Experienced drivers: Upgrade to standard taxi (20% more earnings)
- Senior drivers (Grade 2+): Use luxury limo for 80% more earnings!

---

## ⚙️ Configuration

All features can be toggled in `config.lua`:

```lua
Config.EnableTips = true                    -- Enable/disable tip system
Config.EnableReputation = true              -- Enable/disable reputation
Config.EnableRushHour = true                -- Enable/disable rush hours
Config.EnableWeatherBonus = true            -- Enable/disable weather bonuses
Config.EnableSpecialMissions = true         -- Enable/disable special missions

-- Adjust multipliers, bonuses, and percentages to your liking
Config.TipChance = 60                       -- % chance of receiving a tip
Config.ReputationBonusThreshold = 75        -- Rep level for bonus
Config.RushHourMultiplier = 1.5            -- Rush hour multiplier
```

---

## 🔧 Technical Improvements

### Performance Optimizations
- Efficient thread management with dynamic sleep times
- Vehicle damage tracking only runs during active trips
- Reduced unnecessary calculations

### Anti-Exploit Protection
- Server-side validation of all earnings
- Cooldown system prevents rapid-fire completions
- Job verification on every transaction

### Code Quality
- Modular helper functions
- Comprehensive mission data tracking
- Enhanced server-side reward calculation
- Backwards compatible with existing saves

---

## 📈 Progression System

### Reputation Levels
- **0-24**: Rookie (no bonuses, need improvement)
- **25-49**: Adequate (basic service)
- **50-74**: Professional (good standing)
- **75-100**: Expert (25% bonus earnings!)

### Tips for Success
1. **Avoid crashes** - Costs you reputation and tip bonuses
2. **Complete trips quickly** but safely
3. **Build up to luxury vehicles** for maximum earnings
4. **Check the weather** - Rain = More money!
5. **Watch the clock** - Plan around rush hours

---

## 🎯 Future Enhancement Ideas

Consider adding:
- Player taxi leaderboards
- Daily/weekly challenges
- Custom taxi liveries based on reputation
- Radio/GPS improvements
- Taxi company upgrades (society fund usage)
- NPC personality variations
- Multi-stop routes

---

## 📝 Credits

**Enhanced by**: AI Assistant
**Original Resource**: ESX Framework Team
**Version**: 2.0 Enhanced
**Compatibility**: ESX Legacy

---

## 🐛 Known Issues

    - None currently reported

## 💬 Support

If you encounter issues:
1. Check `config.lua` settings
2. Verify ESX version compatibility
3. Check server console for errors
4. Ensure all dependencies are installed

---

**Enjoy the improved taxi experience! Drive safe and stack that cash! 🚕💰**
