import PageWrapper from "../components/PageWrapper";
import SelectLicenseBox from "../components/SelectLicenseBox";

import MotorcycleImage from '../assets/motorcycle.png';
import CarImage from '../assets/car.png';
import TruckImage from '../assets/truck.png';

export default function CategorySelect() {
	return (
		<PageWrapper>
			<h1 className="text-[32px] font-bold uppercase text-white text-center mt-[60px]">Welcome <span className={'text-[rgba(251,155,4,1)]'}>Driving School</span></h1>

			<p className={'text-[rgba(242,242,242,1)] font-[500] text-[20px] mt-[100px] text-center'}>Lorem Ipsum is simply dummy text of the printing and typesetting industry.</p>

			<div className={'flex justify-center mt-[101px]'}>
				<div className={'grid grid-cols-3 space-x-[40px]'}>

					<SelectLicenseBox label="Motorcycle License" id="motorcycle" category="A" price="2000" imageSrc={MotorcycleImage} />
					<SelectLicenseBox label="Car License" id="car" category="B" price="2000" imageSrc={CarImage} />
					<SelectLicenseBox label="Truck License" id="truck" category="C" price="2000" imageSrc={TruckImage} />
				</div>
			</div>
		</PageWrapper>
	)
}
