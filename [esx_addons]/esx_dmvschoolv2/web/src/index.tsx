import { render } from 'preact';
import { useState, useEffect } from 'preact/hooks';

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
	const isDui = navigator.userAgent.includes('Firefox') || params.get('dui') === 'yes';
	console.log(navigator.userAgent.includes('Mozilla'), params.get('dui'), isDui);
	const [currentPage, setCurrentPage] = useState(params.get('page')?.toLowerCase() || 'none');
	console.log('Initial page:', currentPage);

	useEffect(() => {
		console.log('isDui value changed:', isDui);
		if (!isDui) {
			document.body.style.display = 'none';
		} else {
			document.body.style.display = 'block';
		}
		console.log('DUI Mode:', isDui);
	}, [isDui]);

	if (!isDui || currentPage == 'none') return;

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
						return <LicenseResult licensed={true} progress={25} age={20} fullname='Name Lastname' category='b' />;
					case 'questions':
						return <Questions questions={[
							{
								question: "Lorem Ipsum is simply dummy text of the printing and typesetting industry.",
								options: ["Lorem Ipsum is simply dummy text of the printing and typesetting industry.", "Lorem Ipsum is simply dummy text of the printing and typesetting industry.", "Lorem Ipsum is simply dummy text of the printing and typesetting industry.", "Lorem Ipsum is simply dummy text of the printing and typesetting industry."],
								selected: 0,
								imageSrc: '../assets/questions-image.png'
							},
							{
								question: "What is 2 + 2?",
								options: ["3", "4", "5", "6"],
								selected: 0
							},
							{
								question: "Some question?",
								options: ["Text Text Text", "Text Text Text", "Text Text Text", "Text Text Text"],
								selected: 0
							}
						]} />;
					default:
						return null;
				}
			})()}

		</div>
	);
}

render(<App />, document.getElementById('app'));
