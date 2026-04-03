#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer


DEFAULT_MODEL_ID = "sentence-transformers/paraphrase-MiniLM-L3-v2"
DEFAULT_MAX_LENGTH = 256


class MiniLMWrapper(torch.nn.Module):
    def __init__(self, model: torch.nn.Module) -> None:
        super().__init__()
        self.model = model.eval()

    def forward(
        self,
        input_ids: torch.Tensor,
        attention_mask: torch.Tensor,
        token_type_ids: torch.Tensor,
    ) -> torch.Tensor:
        outputs = self.model(
            input_ids=input_ids,
            attention_mask=attention_mask,
            token_type_ids=token_type_ids,
        )
        return outputs.last_hidden_state


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-id", default=DEFAULT_MODEL_ID)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--max-length", type=int, default=DEFAULT_MAX_LENGTH)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    tokenizer = AutoTokenizer.from_pretrained(args.model_id)
    model = AutoModel.from_pretrained(args.model_id).eval()
    wrapper = MiniLMWrapper(model).eval()

    tokenizer_dir = output_dir / "tokenizer"
    tokenizer.save_pretrained(tokenizer_dir)

    dummy_shape = (1, args.max_length)
    dummy_input_ids = torch.zeros(dummy_shape, dtype=torch.int32)
    dummy_attention_mask = torch.ones(dummy_shape, dtype=torch.int32)
    dummy_token_type_ids = torch.zeros(dummy_shape, dtype=torch.int32)

    exported = torch.export.export(
        wrapper,
        (dummy_input_ids, dummy_attention_mask, dummy_token_type_ids),
    )
    exported = exported.run_decompositions({})

    mlpackage_path = output_dir / "MiniLMEmbedding.mlpackage"
    mlmodel = ct.convert(
        exported,
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS16,
        inputs=[
            ct.TensorType(name="input_ids", shape=dummy_shape, dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=dummy_shape, dtype=np.int32),
            ct.TensorType(name="token_type_ids", shape=dummy_shape, dtype=np.int32),
        ],
        outputs=[
            ct.TensorType(name="last_hidden_state")
        ],
    )
    mlmodel.save(str(mlpackage_path))

    metadata = {
        "model_id": args.model_id,
        "max_length": args.max_length,
        "vocab_path": str(tokenizer_dir / "vocab.txt"),
        "model_path": str(mlpackage_path),
        "input_names": ["input_ids", "attention_mask", "token_type_ids"],
        "output_name": mlmodel.get_spec().description.output[0].name,
        "expected_output_shape": [1, args.max_length, 384],
    }
    (output_dir / "conversion_metadata.json").write_text(
        json.dumps(metadata, indent=2),
        encoding="utf-8",
    )

    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
