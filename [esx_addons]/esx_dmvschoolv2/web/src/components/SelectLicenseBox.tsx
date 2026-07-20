export default function SelectLicenseBox({ label, id, category, price, imageSrc }: { label: string; id: string; category: string; price: string; imageSrc: string }) {

	const formatPrice = (p: string) => {
		const num = Number(p);
		if (Number.isNaN(num)) return p;
		return new Intl.NumberFormat('de-DE').format(num); // de-DE for "." as separator
	};

	const formattedPrice = formatPrice(price);

	return (
		<div className={'select-none relative overflow-hidden bg-[rgba(37,37,37,0.25)] w-[400px] h-[400px] border border-[rgba(56,56,56,0.5)] backdrop-blur-[5px] rounded-[20px] hover:bg-[rgba(37,37,37,0.4)] transition-all duration-200 ease-out active:scale-[0.98]'}>
			<h1 className={'uppercase font-bold text-[22px] fixed top-[30px] left-1/2 transform -translate-x-1/2 text-[rgba(242,242,242,1)] w-full text-center'}>Motorcycle License</h1>
			<div className={'flex justify-center items-center h-full'}>
				<div className={'relative w-[300px] h-[200px]'}>
					<img src={imageSrc} alt={label} className={'w-full'} />
					<div className={'absolute -z-10 top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 blur-[200px]'}>
						<div className={'bg-[rgba(251,155,4,0.8)] w-[100px] h-[100px]'} />
					</div>
				</div>
			</div>
			<div className={'fixed bottom-[30px] left-1/2 transform -translate-x-1/2 text-center text-[rgba(242,242,242,1)] uppercase w-full'}>
				<p className={'text-[22px] font-bold text-[rgba(251,155,4,1)]'}>Category: {category}</p>
				<p className={'text-[20px] text-[rgba(0,251,113,1)]'} style={{
					textShadow: 'rgba(0, 251, 113, 1) 0 0 15px'
				}}>${formattedPrice}</p>
			</div>
		</div>
	)
}
