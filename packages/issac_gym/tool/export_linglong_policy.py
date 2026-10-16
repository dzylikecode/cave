"""Export a frozen inference graph for the Isaac Gym PyTorch 1.10 environment.

Run using a Python environment that can load the original policy (e.g. torch 2.3).
The original file is never modified.
"""
import argparse
from pathlib import Path

import torch


def main():
    root = Path(__file__).resolve().parent.parent / "assets" / "models"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=root / "lite_yuhan.pt")
    parser.add_argument("--output", type=Path, default=root / "lite_yuhan_inference.pt")
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error("output must differ from input")
    model = torch.jit.load(str(args.input), map_location="cpu").eval()
    torch.manual_seed(0)
    samples = [torch.zeros(1, 1050), torch.randn(1, 1050), torch.randn(1, 1050) * 10]
    with torch.inference_mode():
        # Remove training-only branches and unused submodules, including newer
        # scripted class definitions that the PyTorch 1.10 importer cannot read.
        frozen = torch.jit.freeze(model)
        for sample in samples:
            expected, actual = model(sample), frozen(sample)
            if actual.shape != (1, 12) or not torch.isfinite(actual).all():
                raise RuntimeError("Expected 12 finite policy actions")
            torch.testing.assert_close(actual, expected, rtol=1e-5, atol=1e-5)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        frozen.save(str(args.output))
    print("Saved {} using torch {}; numerical equivalence passed".format(args.output, torch.__version__))


if __name__ == "__main__":
    main()
