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

    -- Messages Charge hands back.
    ["insufficient_cash"] = "Du hast nicht genug Bargeld.",
    ["insufficient_card"] = "Dein Bankkonto deckt diese Zahlung nicht.",
    ["payment_failed"] = "Die Zahlung konnte nicht abgeschlossen werden. Versuch es noch einmal.",
    ["method_unavailable"] = "Diese Zahlungsart wird hier nicht angenommen.",

    -- A payment handler that failed or did not answer; it may have sold anyway.
    ["payment_unconfirmed"] = "Die Zahlung wurde nicht bestätigt. Prüf erst, ob sie durchgegangen ist, bevor du nochmal bezahlst.",

    -- /testpayment
    ["command_testpayment"] = "Eine Testzahlung für dich selbst öffnen",
    ["command_amount"] = "Betrag in ganzen Dollar",
    ["command_method"] = "cash oder card, ohne Angabe beide",
    ["command_mode"] = "select schließt bei der Wahl, sonst mit Beleg",
    ["command_invalid_amount"] = "Gib einen ganzen Betrag von mindestens 1 an.",
    ["test_paid"] = "Testzahlung über %s mit %s bezahlt.",
}
