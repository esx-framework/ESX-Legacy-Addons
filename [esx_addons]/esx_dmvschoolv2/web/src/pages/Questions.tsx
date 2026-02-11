import { useState, useEffect } from 'preact/hooks';
import PageWrapper from "../components/PageWrapper"
const images = import.meta.glob('../assets/*', { eager: true });

interface Question {
	question: string;
	options: string[];
	selected: number;
	imageSrc?: string;
}

interface QuestionsProps {
	questions: Question[]
}

export default function Questions({ questions }: QuestionsProps) {

	const [questionIndex, setQuestionIndex] = useState(0)
	const [selectedAnswers, setSelectedAnswers] = useState<{ [key: number]: number }>({})

	const handleSelectOption = (index: number) => {
		setSelectedAnswers((prev) => ({ ...prev, [questionIndex]: index }))
	}

	const [time, setTime] = useState(0)

	useEffect(() => {
		const interval = setInterval(() => {
			setTime((prevTime) => prevTime + 1)
		}, 1000)

		return () => clearInterval(interval)
	}, [])

	const formatTime = (seconds: number) => {
		const mins = Math.floor(seconds / 60)
		const secs = seconds % 60
		return `${mins < 10 ? '0' : ''}${mins}:${secs < 10 ? '0' : ''}${secs}`
	}

	const letterIndex = (index: number) => {
		return String.fromCharCode(65 + index)
	}

	const handleBack = () => {
		if (questionIndex > 0) {
			setQuestionIndex(prev => prev - 1)
		}
	}

	const handleContinue = () => {
		if (selectedAnswers[questionIndex] === undefined) return
		if (questionIndex < questions.length - 1) {
			setQuestionIndex(prev => prev + 1)
		}
	}

	return (
		<PageWrapper>
			<h1 className="text-[32px] font-bold uppercase text-white text-center top-[60px] absolute inset-0 flex justify-center">Driving School</h1>

			<div className={'w-full h-full flex items-center justify-center select-none'}>
				<div className={`bg-[rgba(37,37,37,0.25)] p-[50px] duration-300 transition-all h-[auto] max-h-full rounded-[20px] border border-[rgba(56,56,56,0.5)] backdrop-blur-[5px]`} style={{
					width: questions[questionIndex].imageSrc && images[questions[questionIndex].imageSrc] ? '1382px' : '733px',
				}}>
					<div className={`flex ${questions[questionIndex].imageSrc && images[questions[questionIndex].imageSrc] ? 'flex-row' : 'flex-col'}`}>
						<div>
							<h1 className={'text-[rgba(251,155,4)] uppercase font-bold text-[22px]'}>Question {questionIndex + 1}</h1>
							<p className={'text-[rgb(242,242,242)] text-[16px] line-clamp-2'}>{questions[questionIndex].question}</p>
							<div className={'mt-[35px] flex flex-col space-y-[15px]'} style={{
								width: questions[questionIndex].imageSrc && images[questions[questionIndex].imageSrc] ? '572px' : '100%',
							}}>
								{questions[questionIndex].options.map((option, index) => {
									const isSelected = selectedAnswers[questionIndex] === index
									return (
										<div key={index}>
											<div
												onClick={() => handleSelectOption(index)}
												className={`${isSelected ? 'bg-[rgba(251,155,4,0.15)] border border-[rgba(251,155,4,1)]' : 'bg-[rgba(56,56,56,1)] border border-transparent'} h-[60px] w-full rounded-[10px] flex p-[10px] items-center cursor-pointer active:scale-[0.98] transition-all duration-200`}
											>
												<div className={'bg-[rgba(251,155,4,1)] size-[40px] rounded-[10px] flex items-center justify-center'}>
													<p className={'font-bold text-[rgba(37,37,37,1)] text-[16px]'}>{letterIndex(index)}</p>
												</div>
												<p className={`${isSelected ? 'text-[rgba(251,155,4,1)] font-bold' : 'text-[rgb(242,242,242)]'} text-[16px] ml-[15px] truncate transition-colors`}>{option}</p>
											</div>
										</div>
									)
								})}
							</div>
						</div>
						{questions[questionIndex].imageSrc && images[questions[questionIndex].imageSrc] && (
							<div className={'w-full h-full'}>
								<img
									// @ts-ignore
									src={images[questions[questionIndex].imageSrc].default}
									alt="Question Illustration"
									className="ml-[20px] w-[690px] h-[400px] object-cover"
								/>
							</div>
						)}

					</div>

					<div className={'mt-[40px] flex justify-between'}>
						<div className={`flex items-center ${questions[questionIndex].imageSrc && images[questions[questionIndex].imageSrc] ? 'w-[572px] justify-between' : ''}`}>
							<button
								onClick={handleBack}
								className={`bg-[rgba(37,37,37,1)] h-[40px] w-[130px] rounded-[10px] flex items-center justify-center mr-[35px] active:scale-95 transition-transform ${questionIndex === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
								disabled={questionIndex === 0}
							>
								<p className={'uppercase font-bold text-[15px] text-[rgba(242,242,242,1)]'}>Back</p>
							</button>
							<div className={'font-bold uppercase text-[15px] flex items-center'}>
								<p className={'text-[rgb(242,242,242)]'}>Questions</p>
								<div className={'rounded-[10px] bg-[rgba(251,155,4,1)] text-[rgba(37,37,37,1)] w-[80px] h-[40px] flex items-center justify-center ml-[10px]'}>
									<p>{questionIndex + 1}/{questions.length}</p>
								</div>
							</div>
						</div>

						<div className={'flex items-center'}>
							<div className={'font-bold uppercase text-[15px] flex items-center mr-[20px]'}>
								<p className={'text-[rgb(242,242,242)]'}>Time</p>
								<div className={'rounded-[10px] bg-[rgba(251,155,4,1)] text-[rgba(37,37,37,1)] w-[80px] h-[40px] flex items-center justify-center ml-[10px]'}>
									<p className="tabular-nums">{formatTime(time)}</p>
								</div>
							</div>
							<button
								onClick={handleContinue}
								className={`bg-[rgba(251,155,4,1)] h-[40px] w-[130px] rounded-[10px] flex items-center justify-center ml-auto transition-transform ${selectedAnswers[questionIndex] === undefined ? 'opacity-50 cursor-not-allowed' : 'active:scale-95'}`}
							>
								<p className={'uppercase font-bold text-[15px] text-[rgba(37,37,37,1)]'}>Continue</p>
							</button>
						</div>
					</div>


				</div>
			</div>
		</PageWrapper >
	)
}
