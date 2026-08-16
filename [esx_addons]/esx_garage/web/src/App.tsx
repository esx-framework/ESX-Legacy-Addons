import { useEffect } from 'react';
import { ThemeProvider } from 'styled-components';
import { NuiProvider } from '@/providers/NuiProvider';
import { LocaleProvider } from '@/providers/LocaleProvider';
import { NotificationProvider } from '@/providers/NotificationProvider';
import { ScaleProvider } from '@/providers/ScaleProvider';
import { GlobalStyles } from '@/styles/GlobalStyles';
import { theme } from '@/styles/theme';
import { GarageMenu } from '@/components/garage/GarageMenu';
import { NotificationContainer } from '@/components/common/Notification';
import { sendMockData } from '@/constants/mockData';
import { enableDebugMode } from '@/utils/debug';

function App() {
  useEffect(() => {
    if (import.meta.env.DEV) {
      enableDebugMode();
      sendMockData();

      console.log('[ESX Garages] Development Mode Active');
      console.log('[ESX Garages] Press ESC to close the menu');
      console.log('[ESX Garages] Debug mode enabled - Check console for NUI events');
    }
  }, []);

  return (
    <NuiProvider>
      <LocaleProvider>
        <NotificationProvider>
          <ScaleProvider>
            <ThemeProvider theme={theme}>
              <GlobalStyles />
              <GarageMenu />
              <NotificationContainer />
            </ThemeProvider>
          </ScaleProvider>
        </NotificationProvider>
      </LocaleProvider>
    </NuiProvider>
  );
}

export default App;