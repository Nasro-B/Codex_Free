"""
codex_deepseek_fix — LiteLLM proxy callback.

Problem: the Codex app (gpt-5.5 profile) sends, in the Responses input, PARALLEL tool
calls followed by an assistant text message BEFORE the tool results:
    function_call, function_call, message(assistant), function_call_output, function_call_output
The Responses->chat bridge translates this to  assistant{tool_calls} -> assistant{content} -> tool{...},
which DeepSeek (strict) rejects: "An assistant message with 'tool_calls' must be followed
by tool messages...". NVIDIA / HF tolerate this, DeepSeek does not.

Fix: before translation, we reorder data["input"] so that each function_call block
is followed IMMEDIATELY by its function_call_output; any interleaved items (message /
reasoning) are moved AFTER the results. Stable, lossless transformation:
    ... -> function_call, function_call, function_call_output, function_call_output, message, ...
Harmless for NVIDIA/HF (sequence remains valid), so applied to all backends.
"""
from litellm.integrations.custom_logger import CustomLogger


def _item_type(it):
    if isinstance(it, dict):
        return it.get("type")
    return getattr(it, "type", None)


def _call_id(it):
    if isinstance(it, dict):
        return it.get("call_id")
    return getattr(it, "call_id", None)


def reorder_tool_calls(items):
    """Pull each function_call_output run up to immediately follow its function_call run.
    Items interleaved between calls and their outputs are emitted after the outputs."""
    result = []
    i = 0
    n = len(items)
    while i < n:
        if _item_type(items[i]) == "function_call":
            calls = []
            while i < n and _item_type(items[i]) == "function_call":
                calls.append(items[i])
                i += 1
            expected = set(c for c in (_call_id(x) for x in calls) if c)
            outputs, deferred, got = [], [], set()
            while i < n and (not expected or got != expected):
                t = _item_type(items[i])
                if t == "function_call_output":
                    outputs.append(items[i])
                    cid = _call_id(items[i])
                    if cid:
                        got.add(cid)
                    i += 1
                elif t == "function_call":
                    break  # next call block handled by outer loop
                else:
                    deferred.append(items[i])
                    i += 1
            result.extend(calls)
            result.extend(outputs)
            result.extend(deferred)
        else:
            result.append(items[i])
            i += 1
    return result


class CodexDeepseekFix(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        try:
            items = data.get("input")
            if isinstance(items, list) and any(
                _item_type(x) == "function_call" for x in items
            ):
                data["input"] = reorder_tool_calls(items)
        except Exception:
            pass  # never break the request because of the fix
        return data


handler = CodexDeepseekFix()
