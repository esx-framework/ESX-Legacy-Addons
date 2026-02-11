import PageWrapper from "../components/PageWrapper";

import MotorcycleImage from '../assets/motorcycle.png';
import CarImage from '../assets/car.png';
import TruckImage from '../assets/truck.png';

import ProgressLicenseBox from "../components/ProgressLicenseBox";

export default function Progress() {
	return (
		<PageWrapper>
			<h1 className="text-[32px] font-bold uppercase text-white text-center mt-[60px]">Welcome <span className={'text-[rgba(251,155,4,1)]'}>Driving School</span></h1>

			<p className={'text-[rgba(242,242,242,1)] font-[500] text-[20px] mt-[100px] text-center'}>Lorem Ipsum is simply dummy text of the printing and typesetting industry.</p>

			<div className={'mt-[50px] w-full flex justify-center space-x-[20px]'}>
				<div className={'p-[30px] select-none relative overflow-hidden bg-[rgba(37,37,37,0.25)] w-[400px] h-[418px] border border-[rgba(56,56,56,0.5)] backdrop-blur-[5px] rounded-[20px] space-y-[14px]'}>
					<ProgressLicenseBox label="Motorcycle License" category="A" imageSrc={MotorcycleImage} />
					<ProgressLicenseBox label="Car License" category="A" imageSrc={CarImage} />
					<ProgressLicenseBox label="Truck License" category="A" imageSrc={TruckImage} />
				</div>
				<div className={'select-none relative overflow-hidden w-[200px] h- backdrop-blur-[5px] rounded-[10px]'}>
					<div className={'w-full bg-[rgba(37,37,37,0.25)] h-[50px] border border-[rgba(56,56,56,0.5)] backdrop-blur-[5px] rounded-[10px] flex items-center justify-center relative'}>
						<svg className={'absolute left-[20px]'} width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
							<path d="M18.4 0C20 0 20.8 0 20.8 1.6V22.4C20.8 24 20 24 18.4 24H5.59995C3.99995 24 3.19995 24 3.19995 22.4V1.6C3.19995 0 3.99995 0 5.59995 0H18.4ZM20 20H4.79995V21.6C4.79995 22.4 5.59995 22.4 5.59995 22.4H20V20ZM16.8 8H7.19995C6.39995 8 6.39995 9.6 7.19995 9.6H16.8C17.6 9.6 17.6 8 16.8 8ZM16.8 4.8H7.19995C6.39995 4.8 6.39995 6.4 7.19995 6.4H16.8C17.6 6.4 17.6 4.8 16.8 4.8Z" fill="#FB9B04" />
						</svg>
						<h1 className={'font-bold text-[rgb(242,242,242)] text-[15px] uppercase'}>Lessons</h1>
					</div>

					<div className={'flex mt-[20px]'}>
						<div className={'flex-1 space-y-[3px] flex flex-col justify-center items-center'}>
							<div className={'size-[30px] rounded-[5px] bg-[rgb(251,155,4)] flex justify-center items-center mb-[2px]'} style={{
								boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)'
							}}>
								<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
									<path d="M7.95832 12.625L15.0208 5.5625C15.1875 5.39583 15.3819 5.3125 15.6042 5.3125C15.8264 5.3125 16.0208 5.39583 16.1875 5.5625C16.3542 5.72917 16.4375 5.92722 16.4375 6.15667C16.4375 6.38611 16.3542 6.58389 16.1875 6.75L8.54165 14.4167C8.37499 14.5833 8.18054 14.6667 7.95832 14.6667C7.7361 14.6667 7.54165 14.5833 7.37499 14.4167L3.79165 10.8333C3.62499 10.6667 3.54499 10.4689 3.55165 10.24C3.55832 10.0111 3.64527 9.81306 3.81249 9.64583C3.97971 9.47861 4.17777 9.39528 4.40665 9.39583C4.63554 9.39639 4.83332 9.47972 4.99999 9.64583L7.95832 12.625Z" fill="#252525" />
								</svg>
							</div>

							<div className={'w-[28px] h-[3px] bg-[rgb(251,155,4)] rounded-[1px]'} style={{ boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)' }} />
							<div className={'w-[22px] h-[3px] bg-[rgb(251,155,4)] rounded-[1px]'} style={{ boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)' }} />
							<div className={'w-[16px] h-[3px] bg-[rgb(251,155,4)] rounded-[1px]'} style={{ boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)' }} />
							<div className={'w-[14px] h-[3px] bg-[rgb(251,155,4)] rounded-[1px]'} style={{ boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)' }} />

							<div className={'w-[16px] h-[3px] bg-[rgb(37,37,37)] rounded-[1px] border border-[rgba(56,56,56,0.5)]'} />
							<div className={'w-[22px] h-[3px] bg-[rgb(37,37,37)] rounded-[1px] border border-[rgba(56,56,56,0.5)]'} />
							<div className={'w-[28px] h-[3px] bg-[rgb(37,37,37)] rounded-[1px] border border-[rgba(56,56,56,0.5)]'} />

							<div className={'size-[30px] rounded-[5px] bg-[rgba(37,37,37,0.25)] flex justify-center items-center mb-[2px] border border-[rgba(56,56,56,0.5)]'}>
								<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
									<path d="M10 11.1668L5.91671 15.2502C5.76393 15.4029 5.56949 15.4793 5.33337 15.4793C5.09726 15.4793 4.90282 15.4029 4.75004 15.2502C4.59726 15.0974 4.52087 14.9029 4.52087 14.6668C4.52087 14.4307 4.59726 14.2363 4.75004 14.0835L8.83337 10.0002L4.75004 5.91683C4.59726 5.76405 4.52087 5.56961 4.52087 5.3335C4.52087 5.09738 4.59726 4.90294 4.75004 4.75016C4.90282 4.59738 5.09726 4.521 5.33337 4.521C5.56949 4.521 5.76393 4.59738 5.91671 4.75016L10 8.8335L14.0834 4.75016C14.2362 4.59738 14.4306 4.521 14.6667 4.521C14.9028 4.521 15.0973 4.59738 15.25 4.75016C15.4028 4.90294 15.4792 5.09738 15.4792 5.3335C15.4792 5.56961 15.4028 5.76405 15.25 5.91683L11.1667 10.0002L15.25 14.0835C15.4028 14.2363 15.4792 14.4307 15.4792 14.6668C15.4792 14.9029 15.4028 15.0974 15.25 15.2502C15.0973 15.4029 14.9028 15.4793 14.6667 15.4793C14.4306 15.4793 14.2362 15.4029 14.0834 15.2502L10 11.1668Z" fill="#F2F2F2" />
								</svg>
							</div>
						</div>

						<div className={'flex-none'}>
							<div className={'w-[145px] h-[50px] rounded-[10px] bg-[rgba(251,155,4,0.25)] border border-[rgba(251,155,4,0.5)] flex items-center justify-center'}>
								<p className={'uppercase text-[rgb(22,22,22)] font-semibold text-[15px]'}>Lorem Ipsum</p>
							</div>
							<div className={'mt-[30px] w-[145px] h-[50px] rounded-[10px] bg-[rgba(37,37,37,0.25)] border border-[rgba(56,56,56,0.5)] flex items-center justify-center'}>
								<p className={'uppercase text-[rgb(242,242,242)] font-semibold text-[15px]'}>Lorem Ipsum</p>
							</div>
						</div>
					</div>

					<div className={'mt-[20px] w-full bg-[rgba(37,37,37,0.25)] h-[50px] border border-[rgba(56,56,56,0.5)] backdrop-blur-[5px] rounded-[10px] flex items-center justify-center relative'}>
						<svg className={'absolute left-[20px]'} width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
							<path fill-rule="evenodd" clip-rule="evenodd" d="M19.5 6.5C19.1022 6.5 18.7206 6.65804 18.4393 6.93934C18.158 7.22064 18 7.60218 18 8V9H21V8C21 7.60218 20.842 7.22064 20.5607 6.93934C20.2794 6.65804 19.8978 6.5 19.5 6.5ZM21 10H18V18.25L19.5 20.5L21 18.25V10ZM3 4.5V19.5C3 19.8978 3.15804 20.2794 3.43934 20.5607C3.72064 20.842 4.10218 21 4.5 21H15.5C15.8978 21 16.2794 20.842 16.5607 20.5607C16.842 20.2794 17 19.8978 17 19.5V4.5C17 4.10218 16.842 3.72064 16.5607 3.43934C16.2794 3.15804 15.8978 3 15.5 3H4.5C4.10218 3 3.72064 3.15804 3.43934 3.43934C3.15804 3.72064 3 4.10218 3 4.5ZM10 7.5C10 7.36739 10.0527 7.24021 10.1464 7.14645C10.2402 7.05268 10.3674 7 10.5 7H14.5C14.6326 7 14.7598 7.05268 14.8536 7.14645C14.9473 7.24021 15 7.36739 15 7.5C15 7.63261 14.9473 7.75979 14.8536 7.85355C14.7598 7.94732 14.6326 8 14.5 8H10.5C10.3674 8 10.2402 7.94732 10.1464 7.85355C10.0527 7.75979 10 7.63261 10 7.5ZM10.5 9C10.3674 9 10.2402 9.05268 10.1464 9.14645C10.0527 9.24021 10 9.36739 10 9.5C10 9.63261 10.0527 9.75979 10.1464 9.85355C10.2402 9.94732 10.3674 10 10.5 10H14.5C14.6326 10 14.7598 9.94732 14.8536 9.85355C14.9473 9.75979 15 9.63261 15 9.5C15 9.36739 14.9473 9.24021 14.8536 9.14645C14.7598 9.05268 14.6326 9 14.5 9H10.5ZM10 14C10 13.8674 10.0527 13.7402 10.1464 13.6464C10.2402 13.5527 10.3674 13.5 10.5 13.5H14.5C14.6326 13.5 14.7598 13.5527 14.8536 13.6464C14.9473 13.7402 15 13.8674 15 14C15 14.1326 14.9473 14.2598 14.8536 14.3536C14.7598 14.4473 14.6326 14.5 14.5 14.5H10.5C10.3674 14.5 10.2402 14.4473 10.1464 14.3536C10.0527 14.2598 10 14.1326 10 14ZM10.5 15.5C10.3674 15.5 10.2402 15.5527 10.1464 15.6464C10.0527 15.7402 10 15.8674 10 16C10 16.1326 10.0527 16.2598 10.1464 16.3536C10.2402 16.4473 10.3674 16.5 10.5 16.5H14.5C14.6326 16.5 14.7598 16.4473 14.8536 16.3536C14.9473 16.2598 15 16.1326 15 16C15 15.8674 14.9473 15.7402 14.8536 15.6464C14.7598 15.5527 14.6326 15.5 14.5 15.5H10.5ZM6 14V15.5H7.5V14H6ZM5.5 13H8C8.13261 13 8.25979 13.0527 8.35355 13.1464C8.44732 13.2402 8.5 13.3674 8.5 13.5V16C8.5 16.1326 8.44732 16.2598 8.35355 16.3536C8.25979 16.4473 8.13261 16.5 8 16.5H5.5C5.36739 16.5 5.24021 16.4473 5.14645 16.3536C5.05268 16.2598 5 16.1326 5 16V13.5C5 13.3674 5.05268 13.2402 5.14645 13.1464C5.24021 13.0527 5.36739 13 5.5 13ZM8.8535 7.8535C8.94458 7.7592 8.99498 7.6329 8.99384 7.5018C8.9927 7.3707 8.94011 7.24529 8.84741 7.15259C8.75471 7.05989 8.6293 7.0073 8.4982 7.00616C8.3671 7.00502 8.2408 7.05542 8.1465 7.1465L6.5 8.793L5.8535 8.1465C5.7592 8.05542 5.6329 8.00502 5.5018 8.00616C5.3707 8.0073 5.24529 8.05989 5.15259 8.15259C5.05989 8.24529 5.0073 8.3707 5.00616 8.5018C5.00502 8.6329 5.05542 8.7592 5.1465 8.8535L6.5 10.207L8.8535 7.8535Z" fill="#FB9B04" />
						</svg>


						<h1 className={'font-bold text-[rgb(242,242,242)] text-[15px] uppercase'}>Tests</h1>
					</div>

					<div className={'flex mt-[20px]'}>
						<div className={'flex-1 space-y-[3px] flex flex-col justify-center items-center'}>
							<div className={'size-[30px] rounded-[5px] bg-[rgb(251,155,4)] flex justify-center items-center mb-[2px]'} style={{
								boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)'
							}}>
								<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
									<path d="M7.95832 12.625L15.0208 5.5625C15.1875 5.39583 15.3819 5.3125 15.6042 5.3125C15.8264 5.3125 16.0208 5.39583 16.1875 5.5625C16.3542 5.72917 16.4375 5.92722 16.4375 6.15667C16.4375 6.38611 16.3542 6.58389 16.1875 6.75L8.54165 14.4167C8.37499 14.5833 8.18054 14.6667 7.95832 14.6667C7.7361 14.6667 7.54165 14.5833 7.37499 14.4167L3.79165 10.8333C3.62499 10.6667 3.54499 10.4689 3.55165 10.24C3.55832 10.0111 3.64527 9.81306 3.81249 9.64583C3.97971 9.47861 4.17777 9.39528 4.40665 9.39583C4.63554 9.39639 4.83332 9.47972 4.99999 9.64583L7.95832 12.625Z" fill="#252525" />
								</svg>
							</div>

							<div className={'w-[28px] h-[3px] bg-[rgb(251,155,4)] rounded-[1px]'} style={{ boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)' }} />
							<div className={'w-[22px] h-[3px] bg-[rgb(251,155,4)] rounded-[1px]'} style={{ boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)' }} />
							<div className={'w-[16px] h-[3px] bg-[rgb(251,155,4)] rounded-[1px]'} style={{ boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)' }} />
							<div className={'w-[14px] h-[3px] bg-[rgb(251,155,4)] rounded-[1px]'} style={{ boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)' }} />

							<div className={'w-[16px] h-[3px] bg-[rgb(37,37,37)] rounded-[1px] border border-[rgba(56,56,56,0.5)]'} />
							<div className={'w-[22px] h-[3px] bg-[rgb(37,37,37)] rounded-[1px] border border-[rgba(56,56,56,0.5)]'} />
							<div className={'w-[28px] h-[3px] bg-[rgb(37,37,37)] rounded-[1px] border border-[rgba(56,56,56,0.5)]'} />

							<div className={'size-[30px] rounded-[5px] bg-[rgba(37,37,37,0.25)] flex justify-center items-center mb-[2px] border border-[rgba(56,56,56,0.5)]'}>
								<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
									<path d="M10 11.1668L5.91671 15.2502C5.76393 15.4029 5.56949 15.4793 5.33337 15.4793C5.09726 15.4793 4.90282 15.4029 4.75004 15.2502C4.59726 15.0974 4.52087 14.9029 4.52087 14.6668C4.52087 14.4307 4.59726 14.2363 4.75004 14.0835L8.83337 10.0002L4.75004 5.91683C4.59726 5.76405 4.52087 5.56961 4.52087 5.3335C4.52087 5.09738 4.59726 4.90294 4.75004 4.75016C4.90282 4.59738 5.09726 4.521 5.33337 4.521C5.56949 4.521 5.76393 4.59738 5.91671 4.75016L10 8.8335L14.0834 4.75016C14.2362 4.59738 14.4306 4.521 14.6667 4.521C14.9028 4.521 15.0973 4.59738 15.25 4.75016C15.4028 4.90294 15.4792 5.09738 15.4792 5.3335C15.4792 5.56961 15.4028 5.76405 15.25 5.91683L11.1667 10.0002L15.25 14.0835C15.4028 14.2363 15.4792 14.4307 15.4792 14.6668C15.4792 14.9029 15.4028 15.0974 15.25 15.2502C15.0973 15.4029 14.9028 15.4793 14.6667 15.4793C14.4306 15.4793 14.2362 15.4029 14.0834 15.2502L10 11.1668Z" fill="#F2F2F2" />
								</svg>
							</div>
						</div>

						<div className={'flex-none'}>
							<div className={'w-[145px] h-[50px] rounded-[10px] bg-[rgba(251,155,4,0.25)] border border-[rgba(251,155,4,0.5)] flex items-center justify-center'}>
								<p className={'uppercase text-[rgb(22,22,22)] font-semibold text-[15px]'}>Lorem Ipsum</p>
							</div>
							<div className={'mt-[30px] w-[145px] h-[50px] rounded-[10px] bg-[rgba(37,37,37,0.25)] border border-[rgba(56,56,56,0.5)] flex items-center justify-center'}>
								<p className={'uppercase text-[rgb(242,242,242)] font-semibold text-[15px]'}>Lorem Ipsum</p>
							</div>
						</div>
					</div>

					<div className={'flex justify-end'}>
						<button className={'bg-[rgb(251,155,4)] mt-[30px] rounded-[10px] uppercase font-bold text-[rgb(37,37,37)] w-[145px] h-[50px]'}>Continue</button>
					</div>
				</div>
			</div>

		</PageWrapper>
	);
}
