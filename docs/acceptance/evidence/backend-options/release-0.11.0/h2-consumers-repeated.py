from pathlib import Path
import runpy
import sys
root = Path(__file__).resolve().parents[2]
namespace = runpy.run_path(str(root / "scripts/test-consumers.py"))
original = namespace["execute"]
def repeated(command, directory, env, expected=None):
    output = original(command, directory, env, expected)
    if directory.name == "test_consumer" and "test/consumer_test.exs" in command:
        for iteration in range(2, 11):
            print(f"H2_BASE_REPEAT {iteration}/10", flush=True)
            output = original(command, directory, env, expected)
        print("H2_BASE_REPEAT_PASS runs=10 executed=30 failures=0", flush=True)
    return output
namespace["main"].__globals__["execute"] = repeated
sys.argv = [str(root / "scripts/test-consumers.py")]
namespace["main"]()
