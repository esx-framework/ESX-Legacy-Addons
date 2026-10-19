-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

return {
    -- Dialog. {amount} is filled with the formatted money by the page.
    ["ui_heading"] = "Payment",
    ["ui_choose"] = "Pay with",
    ["ui_total"] = "Total",
    ["ui_cash"] = "Cash",
    ["ui_card"] = "Card",
    ["ui_remaining"] = "After paying {amount}",
    ["ui_short"] = "{amount} short",
    ["ui_pay_cash"] = "Pay {amount} in cash",
    ["ui_pay_card"] = "Pay {amount} by card",
    ["ui_hold_cash"] = "Hold to pay {amount} in cash",
    ["ui_hold_card"] = "Hold to pay {amount} by card",
    ["ui_unaffordable"] = "Not enough money for this payment",
    ["ui_unreachable"] = "The payment did not go through. Try again.",
    ["ui_processing"] = "Processing",
    ["ui_cancel"] = "Cancel",
    ["ui_success"] = "Payment complete",
    ["ui_paid_with"] = "Paid with",
    ["ui_new_balance"] = "New balance",
    ["ui_reference"] = "Reference",
    ["ui_done"] = "Done",

    -- Messages Charge hands back.
    ["insufficient_cash"] = "You do not have enough cash.",
    ["insufficient_card"] = "Your bank account does not cover this payment.",
    ["payment_failed"] = "The payment could not be completed. Try again.",
    ["method_unavailable"] = "This way of paying is not accepted here.",

    -- /testpayment
    ["command_testpayment"] = "Open a test payment on yourself",
    ["command_amount"] = "Amount, whole dollars",
    ["command_method"] = "cash or card, both when left out",
    ["command_invalid_amount"] = "Give a whole amount of at least 1.",
    ["test_paid"] = "Test payment of %s paid with %s.",
}
