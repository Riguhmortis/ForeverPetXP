"""Run with Python and lupa installed: python tests/run.py."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / "tests" / "wow_mock.lua").read_text(encoding="utf-8"))
lua.globals().addonSource = (root / "ForeverPetXP.lua").read_text(encoding="utf-8")
lua.execute((root / "tests" / "test_addon.lua").read_text(encoding="utf-8"))
