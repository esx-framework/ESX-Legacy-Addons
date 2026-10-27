/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 */

// question variables
var questionNumber = 1;
var userAnswer = [];
var questionOrder = [];
var submitting = false;
var nbQuestionToAnswer = 10; // don't forget to change the progress bar max value in html

// Partial Functions
function closeMain() {
    $(".home").css("display", "none");
}
function openMain() {
    $(".home").css("display", "block");
}
function closeAll() {
    $(".body").css("display", "none");
}
function openQuestionnaire() {
    $(".questionnaire-container").css("display", "block");
    var randomQuestion = questionOrder[questionNumber - 1];

    $("#questionNumero").html("Question: " + questionNumber);
    $("#question").html(tableauQuestion[randomQuestion].question);
    $(".answerA").html(tableauQuestion[randomQuestion].propositionA);
    $(".answerB").html(tableauQuestion[randomQuestion].propositionB);
    $(".answerC").html(tableauQuestion[randomQuestion].propositionC);
    $(".answerD").html(tableauQuestion[randomQuestion].propositionD);
    $('input[name=question]').attr('checked', false);

    $(".questionnaire-container .progression").val(questionNumber - 1);
}
function openResultGood() {
    $(".resultGood").css("display", "block");
}
function openResultBad() {
    $(".resultBad").css("display", "block");
}
function openContainer() {
    $(".question-container").css("display", "block");
}
function closeContainer() {
    $(".question-container").css("display", "none");
}

// Listen for NUI Events
window.addEventListener('message', function (event) {
    var item = event.data;

    // Open & Close main window
    if (item.openQuestion == true) {
        questionOrder = item.questions;
        userAnswer = [];
        questionNumber = 1;
        submitting = false;

        openContainer();
        openMain();
    }

    if (item.openQuestion == false) {
        closeContainer();
        closeMain();
    }

    // Open sub-windows / partials
    if (item.openSection == "question") {
        closeAll();
        openQuestionnaire();
    }
});

// Handle Button Presses
$(".btnQuestion").click(function () {
    $.post(`https://${GetParentResourceName()}/question`, JSON.stringify({}));
});

$(".btnClose").click(function () {
    $.post(`https://${GetParentResourceName()}/close`, JSON.stringify({}));
    userAnswer = [];
    questionNumber = 1;
});

$(".btnKick").click(function () {
    $.post(`https://${GetParentResourceName()}/kick`, JSON.stringify({}));
    userAnswer = [];
    questionNumber = 1;
});

// Handle Form Submits
$("#question-form").submit(function (e) {
    e.preventDefault();

    var answer = $('input[name="question"]:checked').val();

    if (submitting || !answer) {
        return false;
    }

    userAnswer.push(answer);

    if (questionNumber < nbQuestionToAnswer) {
        closeAll();
        questionNumber++;
        openQuestionnaire();
    } else {
        submitting = true;

        $.post(`https://${GetParentResourceName()}/submitTheory`, JSON.stringify({
            answers: userAnswer
        }), function (result) {
            closeAll();

            if (result && result.passed === true) {
                openResultGood();
            } else {
                openResultBad();
            }
        }, "json").fail(function () {
            closeAll();
            openResultBad();
        });
    }

    return false;
});
