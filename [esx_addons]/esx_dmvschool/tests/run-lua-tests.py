# SPDX-License-Identifier: GPL-3.0-only
"""Offline Lua 5.4 checks; no FiveM connection or live resource mutations."""
from pathlib import Path
import hashlib
import json
import os
import sys

runtime_path = os.environ.get("ESX_QA_LUA_MODULE_PATH")
if runtime_path:
    sys.path.insert(0, runtime_path)
try:
    from lupa.lua54 import LuaRuntime
except ImportError as exc:
    raise SystemExit(
        "Lua 5.4 tests require Lupa: python -m pip install lupa. "
        "Alternatively set ESX_QA_LUA_MODULE_PATH to its installation directory."
    ) from exc

tests_root = Path(__file__).resolve().parent
resource_root = Path(
    sys.argv[1] if len(sys.argv) > 1
    else os.environ.get("ESX_QA_RESOURCE_ROOT", tests_root.parent)
).resolve()
required = ("config.lua", "shared/evaluator.lua", "client/main.lua", "client/markers.lua",
            "server/main.lua", "server/theory.lua", "server/vehicles.lua")
for relative in required:
    if not (resource_root / relative).is_file():
        raise SystemExit(f"Resource source not found: {resource_root / relative}")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
GetConvar = function(_, default) return default end
function vector3(x, y, z) return {x = x, y = y, z = z, __vector = 'vector3'} end
function vector4(x, y, z, w) return {x = x, y = y, z = z, w = w, __vector = 'vector4'} end
""")
lua.globals().LocaleSources = lua.table_from({
    file.stem: file.read_text(encoding="utf-8-sig") for file in (resource_root / "locales").glob("*.lua")
})
for relative in required:
    source = (resource_root / relative).read_text(encoding="utf-8-sig")
    lua.execute("assert(load(...))", source)
    print("syntax PASS:", relative)
lua.execute((resource_root / "config.lua").read_text(encoding="utf-8-sig"))
lua.execute((resource_root / "shared/evaluator.lua").read_text(encoding="utf-8-sig"))
geometry_checks = lua.execute((tests_root / "evaluator-mocks.lua").read_text(encoding="utf-8-sig"))
lua.globals().ClientSource = (resource_root / "client/main.lua").read_text(encoding="utf-8-sig")
client_checks = lua.execute((tests_root / "client-mocks.lua").read_text(encoding="utf-8-sig"))
lua.globals().MarkerSource = (resource_root / "client/markers.lua").read_text(encoding="utf-8-sig")
marker_checks = lua.execute((tests_root / "marker-mocks.lua").read_text(encoding="utf-8-sig"))
bay_checks = lua.execute((tests_root / "bay-mocks.lua").read_text(encoding="utf-8-sig"))
truck_checks = lua.execute((tests_root / "truck-bay-mocks.lua").read_text(encoding="utf-8-sig"))
hint_checks = lua.execute((tests_root / "parking-hint-mocks.lua").read_text(encoding="utf-8-sig"))
question_hashes = {
    'de': '45ef4c52fae28bfe6c823705e69950b5d514029b883cbe65b9f4baa9bb8b0658',
    'en': '575f3afe9efbcc320ccfd3fb374e4707dd42f348fbdabeaa2c0c2cb524545ac4',
    'es': 'f4375ac3dce36fee227fa653ab935e44a1a469881f6d4c7743bbe9c2bfa7d193',
    'fi': '49dcdfd9c76f47d699fdd16985cb97ec14ba37e00883c3a75f578ff6b5f7fcda',
    'fr': 'd21df54714eb9f889d553b6e2e5c4db4a7cdbe45c762d6568a50fe16db9f8656',
    'it': '5d33e8ee0f606ddcfa7f45367124fc5c8e0e6351bcaa87a66e97f6b83560ae23',
    'nl': '6c715132747e1728fd83c9cb0171fcdc947bfb5e5fb1a7c29d003894a37e117b',
    'pl': '3ac251b5c144bbe27aa8a8b0d319247a2ab99ad72a49f01a22bc85d8cab85c18',
    'sr': 'a42b962ddb98cc8e16f8970dec59c19d4b050ad2d339b74f70ee183d22ac2668',
    'sv': '78a4edc79193add3516c0d2de052bfba938a019f0ba1dc64610781be75ffb9f4',
}
question_sources = {}
for locale, digest in question_hashes.items():
    source = (resource_root / 'server/questions' / f'{locale}.lua').read_text(encoding='utf-8-sig')
    bank = lua.execute(source)
    parsed = [
        {'id': row.id, 'text': row.text,
         'answers': [row.answers[index] for index in range(1, 5)], 'correct': row.correct}
        for _, row in sorted(bank.items())
    ]
    canonical = json.dumps(parsed, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    assert hashlib.sha256(canonical).hexdigest() == digest, f'{locale}: original question bank changed'
    question_sources[locale] = source
lua.globals().QuestionSources = lua.table_from(question_sources)
lua.globals().TheorySource = (resource_root / 'server/theory.lua').read_text(encoding='utf-8-sig')
theory_checks = lua.execute((tests_root / 'theory-mocks.lua').read_text(encoding='utf-8-sig'))
lua.globals().VehiclesSource = (resource_root / 'server/vehicles.lua').read_text(encoding='utf-8-sig')
vehicle_checks = lua.execute((tests_root / 'vehicles-mocks.lua').read_text(encoding='utf-8-sig'))
print(f"Original question-bank roundtrip: {len(question_sources)} languages / {len(question_sources) * 10} questions passed.")
print(f"Lua regression: {geometry_checks + client_checks + marker_checks + bay_checks + truck_checks + hint_checks + theory_checks + vehicle_checks} assertions passed.")
