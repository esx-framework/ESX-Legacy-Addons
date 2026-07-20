export default function ProgrssLicenseBox({label, category, imageSrc}: { label: string; category: string; imageSrc: string }) {
	return (
		<div className={'bg-[rgb(37,37,37)] w-full h-[110px] rounded-[10px] flex items-center pl-[10px] py-[15px] pr-[20px] relative overflow-hidden hover:bg-[rgba(251,155,4,0.1)] transition-all duration-200 ease-out active:scale-[0.98]'}>
			<div className={'min-w-[120px] w-[120px] z-20'}>
				<img src={imageSrc} alt={label} className={'w-full'} />
			</div>
			<div className={'w-full text-end z-20'}>
				<h1 className={'text-[15px] font-bold text-[rgb(242,242,242)] uppercase'}>{label}</h1>
				<p className={'text-[15px] font-medium text-[rgba(251,155,4,1)] uppercase mt-[5px]'}>Category: {category}</p>
			</div>
			<div className={'absolute z-10 bottom-[-0%] left-[-0%] blur-[50px]'}>
				<div className={'bg-[rgba(251,155,4,0.8)] w-[50px] h-[50px]'} />
			</div>
		</div>
	)
}
