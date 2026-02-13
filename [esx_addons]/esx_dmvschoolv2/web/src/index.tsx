import { render } from 'preact';
import { useState, useEffect } from 'preact/hooks';
import { ConfigProvider, useConfig } from './context/ConfigContext';

import './styles/fonts.css'
import './styles/style.css';
import { Cursor } from './components/Cursor';

import Welcome from './pages/Welcome';
import CategorySelect from './pages/CategorySelect';
import Progress from './pages/Progress';
import LicenseResult from './pages/LicenseResult';
import Questions from './pages/Questions';

console.log('Current URL:', window.location.href);

export function App() {
	const params = new URLSearchParams(window.location.search);
	// @ts-ignore
	const isDui = navigator.userAgent.includes('Firefox') || params.get('dui') === 'yes' || import.meta.env.DEV;
	console.log(navigator.userAgent.includes('Mozilla'), params.get('dui'), isDui);
	const [currentPage, setCurrentPage] = useState(params.get('page')?.toLowerCase() || 'none');
	console.log('Initial page:', currentPage);

	const { config } = useConfig();

	useEffect(() => {
		console.log('isDui value changed:', isDui);
		if (!isDui) {
			document.body.style.display = 'none';
		} else {
			document.body.style.display = 'block';
		}
		console.log('DUI Mode:', isDui);
	}, [isDui]);

	// @ts-ignore
	if ((!isDui || currentPage == 'none') && !import.meta.env.DEV) return;

	return (
		<div className={'w-screen h-screen font-poppins'}>

			<Cursor color="#fb9b04" size={13} />

			{(() => {
				switch (currentPage) {
					case 'welcome':
						return <Welcome />;
					case 'categoryselect':
						return <CategorySelect />;
					case 'progress':
						return <Progress />;
					case 'licenseresult':
						return config ? (
							<LicenseResult
								licensed={config.licenseresult.licensed}
								progress={config.licenseresult.progress}
								age={config.licenseresult.age}
								fullname={config.licenseresult.fullname}
								category={config.licenseresult.category}
							/>
						) : null;
					case 'questions':
						return config ? <Questions questions={config.questions} /> : null;
					default:
						return null;
				}
			})()}

		</div>
	);
}

render(
	<ConfigProvider>
		<App />
	</ConfigProvider>,
	document.getElementById('app')
);
