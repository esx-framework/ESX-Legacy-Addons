-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

return {
    -- Dialog. {amount} is filled with the formatted money by the page.
    ["ui_heading"] = "Zahlung",
    ["ui_choose"] = "Bezahlen mit",
    ["ui_total"] = "Gesamt",
    ["ui_cash"] = "Bargeld",
    ["ui_card"] = "Karte",
    ["ui_remaining"] = "Danach {amount}",
    ["ui_short"] = "Es fehlen {amount}",
    ["ui_pay_cash"] = "{amount} bar bezahlen",
    ["ui_pay_card"] = "{amount} mit Karte bezahlen",
    ["ui_hold_cash"] = "Halten, um {amount} bar zu bezahlen",
    ["ui_hold_card"] = "Halten, um {amount} mit Karte zu bezahlen",
    ["ui_unaffordable"] = "Nicht genug Geld für diese Zahlung",
    ["ui_unreachable"] = "Die Zahlung ist nicht durchgegangen. Versuch es noch einmal.",
    ["ui_processing"] = "Wird bezahlt",
    ["ui_cancel"] = "Abbrechen",
    ["ui_success"] = "Zahlung erfolgreich",
    ["ui_paid_with"] = "Bezahlt mit",
    ["ui_new_balance"] = "Neues Guthaben",
    ["ui_reference"] = "Beleg",
    ["ui_done"] = "Fertig",

    -- Answers of the server.
    ["insufficient_cash"] = "Du hast nicht genug Bargeld.",
    ["insufficient_card"] = "Dein Bankkonto deckt diese Zahlung nicht.",
    ["payment_failed"] = "Die Zahlung konnte nicht abgeschlossen werden. Versuch es noch einmal.",
    ["method_unavailable"] = "Diese Zahlungsart wird hier nicht angenommen.",
    ["payment_expired"] = "Die Zahlung ist abgelaufen.",
}
