import InstructorDrivingTest from "../pages/InstructorDrivingTest";

export const mockConfig = {
    licenses: {
        "motorcycle": {
            label: "Motorcycle License",
            price: 500,
            category: "A",
            imageSrc: "assets/motorcycle.png"
        },
        "car": {
            label: "Car License",
            price: 1500,
            category: "B",
            imageSrc: "assets/car.png"
        },
        "truck": {
            label: "Truck License",
            price: 2500,
            category: "C",
            imageSrc: "assets/truck.png"
        }
    },
    questions: [
        {
            question: "Question 1?",
            options: ["Option 1", "Option 2", "Option 3", "Option 4"],
            selected: 0,
            imageSrc: null
        }
    ],
    progressdata: {
        lessons: [
            { label: "Lesson 1", completed: true },
            { label: "Lesson 2", completed: true },
        ],
        tests: [
            { label: "Test 1", completed: false },
            { label: "Test 2", completed: false }
        ],
        progress: 50
    },
    licenseresult: {
        licensed: true,
        fullname: "John Doe",
        age: 25,
        category: "B",
        progress: 100
    },
    resourceName: "esx_dmvschool",
    studentDrivingTest: {
        maxMistakes: 5,
        currentObjective: "Wait for instructor",
        progress: 0,
        checkpointsLeft: 10,
        mistakes: 0
    },
	instructorDrivingTest: {
		maxMistakes: 5,
		speeding: 0,
		unitSystem: "metrics",
		progress: 0,
		mistakes: 0
	}
};
