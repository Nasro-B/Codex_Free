"""
codex_deepseek_fix — callback LiteLLM proxy.

Probleme : l'app Codex (profil gpt-5.5) envoie, dans l'input Responses, des appels
d'outils PARALLELES suivis d'un message texte assistant AVANT les resultats d'outils :
    function_call, function_call, message(assistant), function_call_output, function_call_output
Le pont Responses->chat traduit ca en  assistant{tool_calls} -> assistant{content} -> tool{...},
ce que DeepSeek (strict) refuse : "An assistant message with 'tool_calls' must be followed
by tool messages...". NVIDIA / HF tolerent, DeepSeek non.

Fix : avant traduction, on reordonne data["input"] pour que chaque bloc de function_call
soit suivi IMMEDIATEMENT de ses function_call_output ; tout item intercale (message /
reasoning) est deplace APRES les resultats. Transformation stable et sans perte :
    ... -> function_call, function_call, function_call_output, function_call_output, message, ...
Inoffensif pour NVIDIA/HF (sequence reste valide), donc applique a tous les backends.
"""
import sys

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
        except Exception as e:
            # ne jamais casser la requete a cause du fix — mais ne plus echouer en silence
            print(f"[codex_deepseek_fix] reorder ignore (requete inchangee): {e!r}", file=sys.stderr)
        return data


handler = CodexDeepseekFix()
