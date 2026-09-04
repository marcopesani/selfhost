#!/usr/bin/env python3
"""Idempotent in-image patches for the stock lmsysorg/sglang:glm-5.3-flash tree.

Container overlay is wiped on stop; boot.sh re-runs this from the volume.

1. CUDA sm_120 TileLang sparse fwd: default tile (block_I=64, stages=2, threads=256)
   requests 151552 B dynamic smem. SM120 SRAM is ~100 KiB (sglang#37105).
   HIP path already retunes; the CUDA factory call did not.
2. tokenizer_config.json on this NVFP4 checkpoint sets tokenizer_class=TokenizersBackend
   (transformers v5). SGLang treated that as a failed mapping and warned.
3. Consumer decode defaults (ADR-023): omitted max_tokens → 65536, not 128 / until-EOS;
   reserve 16384 of that for content via a GLM-5.3 thinking-budget processor
   (token ids 154841/154842, not GLM-4.5's 151350/151351).
"""
from __future__ import annotations

from pathlib import Path

KERNEL = Path(
    "/sgl-workspace/sglang/python/sglang/kernels/ops/attention/dsa/tilelang_kernel.py"
)
TOKENIZER = Path(
    "/sgl-workspace/sglang/python/sglang/srt/utils/hf_transformers/tokenizer.py"
)
PROCESSOR = Path(
    "/sgl-workspace/sglang/python/sglang/srt/utils/hf_transformers/processor.py"
)
SAMPLING = Path("/sgl-workspace/sglang/python/sglang/srt/sampling/sampling_params.py")
PROTOCOL = Path(
    "/sgl-workspace/sglang/python/sglang/srt/entrypoints/openai/protocol.py"
)
CUSTOM_LOGIT = Path(
    "/sgl-workspace/sglang/python/sglang/srt/sampling/custom_logit_processor.py"
)
TOKENIZER_MGR = Path(
    "/sgl-workspace/sglang/python/sglang/srt/managers/tokenizer_manager.py"
)

KERNEL_OLD = """        kernel = kernel_factory(
            num_heads, d_v, tail_dim, topk, sm_scale=sm_scale, return_lse=return_lse
        )
"""
KERNEL_NEW = """        # glm-flash-sm120-tile: sm_120 SRAM ~100KiB; default 64/2/256 needs 151552 B (sglang#37105)
        extra = {}
        if not _is_hip:
            major, _minor = torch.cuda.get_device_capability()
            if major == 12:
                extra["block_I"] = 32
                if kernel_factory is sparse_attention_fwd_kernel_v1:
                    extra["num_stages"] = 1
                    extra["threads"] = 128
        kernel = kernel_factory(
            num_heads, d_v, tail_dim, topk, sm_scale=sm_scale, return_lse=return_lse, **extra
        )
"""

TOKENIZER_OLD = """    if type(tokenizer).__name__ == _TOKENIZERS_BACKEND:
        if common_kwargs.get("trust_remote_code"):
            logger.warning(
                "Tokenizer for %s is still TokenizersBackend after retries "
                "with --trust-remote-code. Model-specific tokenizer attributes "
                "may be missing.",
                tokenizer_name,
            )
        else:
            logger.debug(
                "Tokenizer for %s loaded as generic TokenizersBackend. "
                "Set --trust-remote-code to load the model-specific tokenizer.",
                tokenizer_name,
            )
"""
TOKENIZER_NEW = """    if type(tokenizer).__name__ == _TOKENIZERS_BACKEND:
        declared = None
        try:
            revision = common_kwargs.get("revision") or common_kwargs.get(
                "tokenizer_revision"
            )
            config_file = _resolve_local_or_cached_file(
                tokenizer_name, "tokenizer_config.json", revision
            )
            with open(config_file) as f:
                declared = json.load(f).get("tokenizer_class")
        except (FileNotFoundError, OSError, json.JSONDecodeError):
            declared = None
        # transformers v5: TokenizersBackend is the real class when tokenizer_config says so
        if declared == _TOKENIZERS_BACKEND:
            return tokenizer
        if common_kwargs.get("trust_remote_code"):
            logger.warning(
                "Tokenizer for %s is still TokenizersBackend after retries "
                "with --trust-remote-code. Model-specific tokenizer attributes "
                "may be missing.",
                tokenizer_name,
            )
        else:
            logger.debug(
                "Tokenizer for %s loaded as generic TokenizersBackend. "
                "Set --trust-remote-code to load the model-specific tokenizer.",
                tokenizer_name,
            )
"""

PROCESSOR_OLD = """    if type(tokenizer).__name__ == _TOKENIZERS_BACKEND:
        from .tokenizer import get_tokenizer

        logger.warning(
            "Processor tokenizer for %s is TokenizersBackend, "
            "reloading via get_tokenizer",
            tokenizer_name,
        )
        tokenizer = get_tokenizer(
            tokenizer_name,
            tokenizer_mode=tokenizer_mode,
            trust_remote_code=trust_remote_code,
            tokenizer_revision=revision,
            tokenizer_backend=tokenizer_backend,
        )
        if isinstance(processor, PreTrainedTokenizerBase):
            processor = tokenizer
        else:
            processor.tokenizer = tokenizer
"""
PROCESSOR_NEW = """    if type(tokenizer).__name__ == _TOKENIZERS_BACKEND:
        from .tokenizer import get_tokenizer

        declared = None
        try:
            cfg_path = Path(tokenizer_name) / "tokenizer_config.json"
            if cfg_path.is_file():
                declared = json.loads(cfg_path.read_text()).get("tokenizer_class")
        except (OSError, ValueError):
            declared = None
        if declared != _TOKENIZERS_BACKEND:
            logger.warning(
                "Processor tokenizer for %s is TokenizersBackend, "
                "reloading via get_tokenizer",
                tokenizer_name,
            )
            tokenizer = get_tokenizer(
                tokenizer_name,
                tokenizer_mode=tokenizer_mode,
                trust_remote_code=trust_remote_code,
                tokenizer_revision=revision,
                tokenizer_backend=tokenizer_backend,
            )
            if isinstance(processor, PreTrainedTokenizerBase):
                processor = tokenizer
            else:
                processor.tokenizer = tokenizer
"""

SAMPLING_OLD = """    max_new_tokens: Optional[int] = 128
"""
SAMPLING_NEW = """    max_new_tokens: Optional[int] = 65536  # glm-flash-default-max (was 128)
"""

PROTOCOL_CHAT_OLD = """            "max_new_tokens": self.max_completion_tokens or self.max_tokens,
"""
PROTOCOL_CHAT_NEW = """            "max_new_tokens": self.max_completion_tokens or self.max_tokens or 65536,  # glm-flash-default-max
"""

PROTOCOL_RESP_OLD = """        if self.max_output_tokens is not None:
            max_tokens = min(self.max_output_tokens, default_max_tokens)
        else:
            max_tokens = default_max_tokens
"""
PROTOCOL_RESP_NEW = """        if self.max_output_tokens is not None:
            max_tokens = min(self.max_output_tokens, default_max_tokens)
        else:
            # glm-flash-default-max: do not spend the leftover 1M window on one answer
            max_tokens = min(default_max_tokens, 65536)
"""

CUSTOM_LOGIT_OLD = """class Glm4MoeThinkingBudgetLogitProcessor(ThinkingBudgetLogitProcessor):
    \"\"\"A logit processor that controls the length of thinking for GLM-4.5 / GLM-4.6 / GLM-4.5V / GLM-4.6V models.\"\"\"

    THINKING_START_TOKEN_ID: int = 151350
    THINKING_END_TOKEN_ID: int = 151351
    NEW_LINE_TOKEN_ID: int = 198
"""
CUSTOM_LOGIT_NEW = """class Glm4MoeThinkingBudgetLogitProcessor(ThinkingBudgetLogitProcessor):
    \"\"\"A logit processor that controls the length of thinking for GLM-4.5 / GLM-4.6 / GLM-4.5V / GLM-4.6V models.\"\"\"

    THINKING_START_TOKEN_ID: int = 151350
    THINKING_END_TOKEN_ID: int = 151351
    NEW_LINE_TOKEN_ID: int = 198


class Glm53FlashThinkingBudgetLogitProcessor(ThinkingBudgetLogitProcessor):
    \"\"\"GLM-5.3-Flash think tokens. Not the GLM-4.5 151350/151351 ids.\"\"\"

    THINKING_START_TOKEN_ID: int = 154841
    THINKING_END_TOKEN_ID: int = 154842
    NEW_LINE_TOKEN_ID: int = 198
"""

TOKENIZER_MGR_OLD = """        if isinstance(obj, GenerateReqInput) and obj.max_thinking_tokens is not None:
            sampling_kwargs = dict(sampling_kwargs)
            custom_params = dict(sampling_kwargs.get("custom_params") or {})
            custom_params["thinking_budget"] = obj.max_thinking_tokens
            sampling_kwargs["custom_params"] = custom_params
        sampling_params = self.sampling_params_class(**sampling_kwargs)
"""
TOKENIZER_MGR_NEW = """        if isinstance(obj, GenerateReqInput) and obj.max_thinking_tokens is not None:
            sampling_kwargs = dict(sampling_kwargs)
            custom_params = dict(sampling_kwargs.get("custom_params") or {})
            custom_params["thinking_budget"] = obj.max_thinking_tokens
            sampling_kwargs["custom_params"] = custom_params
        # glm-flash-consumer-ux: reserve 16k of the decode cap for content
        if isinstance(obj, GenerateReqInput):
            sampling_kwargs = dict(sampling_kwargs)
            custom_params = dict(sampling_kwargs.get("custom_params") or {})
            if "thinking_budget" not in custom_params:
                mx = sampling_kwargs.get("max_new_tokens")
                if mx is None:
                    mx = 65536
                custom_params["thinking_budget"] = max(0, int(mx) - 16384)
            sampling_kwargs["custom_params"] = custom_params
            budget = custom_params.get("thinking_budget")
            logit = obj.custom_logit_processor
            logit_unset = logit is None or (
                isinstance(logit, list) and all(x is None for x in logit)
            )
            if logit_unset and isinstance(budget, int) and budget >= 0:
                from sglang.srt.sampling.custom_logit_processor import (
                    Glm53FlashThinkingBudgetLogitProcessor,
                )

                obj.custom_logit_processor = (
                    Glm53FlashThinkingBudgetLogitProcessor.to_str()
                )
        sampling_params = self.sampling_params_class(**sampling_kwargs)
"""


def _replace(path: Path, old: str, new: str, already: str) -> str:
    text = path.read_text()
    if already in text:
        return f"skip {path.name} (already patched)"
    if old not in text:
        raise SystemExit(f"patch failed: marker missing in {path}")
    path.write_text(text.replace(old, new, 1))
    return f"patched {path.name}"


def main() -> None:
    print(_replace(KERNEL, KERNEL_OLD, KERNEL_NEW, "glm-flash-sm120-tile"))
    print(
        _replace(
            TOKENIZER,
            TOKENIZER_OLD,
            TOKENIZER_NEW,
            "TokenizersBackend is the real class",
        )
    )
    print(
        _replace(
            PROCESSOR,
            PROCESSOR_OLD,
            PROCESSOR_NEW,
            "if declared != _TOKENIZERS_BACKEND:",
        )
    )
    print(
        _replace(
            SAMPLING, SAMPLING_OLD, SAMPLING_NEW, "glm-flash-default-max (was 128)"
        )
    )
    print(
        _replace(
            PROTOCOL,
            PROTOCOL_CHAT_OLD,
            PROTOCOL_CHAT_NEW,
            "or self.max_tokens or 65536",
        )
    )
    print(
        _replace(
            PROTOCOL,
            PROTOCOL_RESP_OLD,
            PROTOCOL_RESP_NEW,
            "min(default_max_tokens, 65536)",
        )
    )
    print(
        _replace(
            CUSTOM_LOGIT,
            CUSTOM_LOGIT_OLD,
            CUSTOM_LOGIT_NEW,
            "Glm53FlashThinkingBudgetLogitProcessor",
        )
    )
    print(
        _replace(
            TOKENIZER_MGR,
            TOKENIZER_MGR_OLD,
            TOKENIZER_MGR_NEW,
            "glm-flash-consumer-ux",
        )
    )


if __name__ == "__main__":
    main()
