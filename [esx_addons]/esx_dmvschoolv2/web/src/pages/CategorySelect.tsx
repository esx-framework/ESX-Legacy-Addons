import PageWrapper from "../components/PageWrapper";
import SelectLicenseBox from "../components/SelectLicenseBox";

import { useConfig } from "../context/ConfigContext";

export default function CategorySelect() {
	const { config } = useConfig();
	const images = import.meta.glob('../assets/*', { eager: true });

	if (!config) return null;

	return (
		<PageWrapper>
			<h1 className="text-[32px] font-bold uppercase text-white text-center mt-[60px]">Welcome <span className={'text-[rgba(251,155,4,1)]'}>Driving School</span></h1>

			<p className={'text-[rgba(242,242,242,1)] font-[500] text-[20px] mt-[100px] text-center'}>Lorem Ipsum is simply dummy text of the printing and typesetting industry.</p>

			<div className={'flex justify-center mt-[101px]'}>
				<div className={'grid grid-cols-3 space-x-[40px]'}>
					{Object.entries(config.licenses).map(([key, license]) => {
						const imagePath = `../${license.imageSrc}`;
						// @ts-ignore
						const imageSrc = images[imagePath]?.default || license.imageSrc;

						return (
							<SelectLicenseBox
								key={key}
								label={license.label}
								id={key}
								category={license.category}
								price={license.price.toString()}
								imageSrc={imageSrc}
							/>
						);
					})}
				</div>
			</div>
		</PageWrapper>
	)
}
