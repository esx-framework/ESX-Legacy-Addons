import TabletWrapper from '../components/TabletWrapper';

export default function TabletWelcome() {
	return (
		<TabletWrapper>
			<div className={'w-full h-full flex items-center justify-center select-none rounded-[30px]'}>
				<div>
					<h1 className="font-bold uppercase text-white text-center text-[24px]">Welcome to the driving instructor <span className={'text-[#FB9B04]'}>system</span></h1>
					<p className={'text-center mt-[20px] text-[#F2F2F2]'}>Here you can manage lessons, student registrations, and training materials.<br/>Please log in to start your work.</p>
				</div>
			</div>
		</TabletWrapper>
	)
}
