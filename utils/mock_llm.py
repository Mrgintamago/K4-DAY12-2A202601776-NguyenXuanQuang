"""Mock LLM — CHO SẴN, KHÔNG CẦN SỬA.

Trả lời tất định (cùng câu hỏi → cùng câu trả lời) nên không cần API key,
không tốn tiền, và test luôn cho kết quả ổn định.

Dùng:
    from utils.mock_llm import generate_reply
    result = generate_reply("Docker là gì?", history=[...])
    result["text"], result["prompt_tokens"], result["completion_tokens"], result["usd_cost"]
"""

from __future__ import annotations

import hashlib
import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from app.config import get_settings

# Giá giả lập, tính theo 1.000 token (giống thang giá gpt-4o-mini)
PRICE_PROMPT_PER_1K = 0.00015
PRICE_COMPLETION_PER_1K = 0.00060

_TEMPLATES = [
    "Theo mình hiểu, {q} liên quan tới cách hệ thống được đóng gói và vận hành. "
    "Điểm mấu chốt là tách cấu hình ra khỏi code và giữ service ở trạng thái stateless.",
    "Câu hỏi hay. {q} thường được giải quyết bằng cách chuẩn hóa môi trường chạy: "
    "cùng một image chạy giống nhau ở laptop và trên cloud.",
    "Ngắn gọn: {q} phụ thuộc vào ba yếu tố — cấu hình qua biến môi trường, "
    "health check để orchestrator biết trạng thái, và giới hạn tài nguyên.",
    "Với {q}, cách làm phổ biến trong production là đặt một lớp gateway phía trước "
    "để lo authentication, rate limiting và bảo vệ chi phí.",
]


def _estimate_tokens(text: str) -> int:
    """Ước lượng thô: ~4 ký tự / token, tối thiểu 1."""
    return max(1, len(text) // 4)


def _generate_mock_reply(message: str, history: list[dict] | None = None) -> dict:
    """Giả lập một lượt gọi LLM.

    Args:
        message: tin nhắn của người dùng.
        history: lịch sử hội thoại, list các dict {"role": ..., "content": ...}.

    Returns:
        dict gồm text, prompt_tokens, completion_tokens, usd_cost.
    """
    history = history or []
    digest = hashlib.sha256(message.strip().lower().encode("utf-8")).hexdigest()
    template = _TEMPLATES[int(digest[:8], 16) % len(_TEMPLATES)]
    text = template.format(q=message.strip().rstrip("?") or "vấn đề bạn hỏi")

    if history:
        text += f" (Mình đang nhớ {len(history)} lượt trao đổi trước đó.)"

    prompt_text = message + "".join(turn.get("content", "") for turn in history)
    prompt_tokens = _estimate_tokens(prompt_text)
    completion_tokens = _estimate_tokens(text)
    cost = (
        prompt_tokens / 1000 * PRICE_PROMPT_PER_1K
        + completion_tokens / 1000 * PRICE_COMPLETION_PER_1K
    )

    return {
        "text": text,
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "usd_cost": round(cost, 8),
    }


def _generate_ai_box_reply(message: str, history: list[dict] | None = None) -> dict:
    """Gọi API OpenAI-compatible của AI Box khi được bật bằng environment."""
    settings = get_settings()
    if not settings.ai_box_api_key:
        raise RuntimeError("AI_BOX_API_KEY is required when LLM_PROVIDER=ai_box")

    messages = list(history or [])
    messages.append({"role": "user", "content": message})
    payload = json.dumps(
        {"model": settings.ai_box_model, "messages": messages},
        ensure_ascii=False,
    ).encode("utf-8")
    request = Request(
        f"{settings.ai_box_base_url.rstrip('/')}/chat/completions",
        data=payload,
        headers={
            "Authorization": f"Bearer {settings.ai_box_api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=settings.llm_timeout_seconds) as response:
            body = json.load(response)
    except HTTPError as error:
        raise RuntimeError(f"AI Box request failed with HTTP {error.code}") from error
    except URLError as error:
        raise RuntimeError("AI Box request could not be completed") from error

    try:
        text = body["choices"][0]["message"]["content"]
    except (IndexError, KeyError, TypeError) as error:
        raise RuntimeError("AI Box returned an unexpected response format") from error

    usage = body.get("usage", {})
    prompt_tokens = int(usage.get("prompt_tokens", _estimate_tokens(message)))
    completion_tokens = int(usage.get("completion_tokens", _estimate_tokens(text)))
    cost = (
        prompt_tokens / 1000 * settings.llm_prompt_price_per_1k
        + completion_tokens / 1000 * settings.llm_completion_price_per_1k
    )
    return {
        "text": text,
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "usd_cost": round(cost, 8),
    }


def generate_reply(message: str, history: list[dict] | None = None) -> dict:
    """Tạo phản hồi bằng mock mặc định hoặc DeepSeek qua AI Box khi được bật."""
    provider = get_settings().llm_provider.lower()
    if provider == "mock":
        return _generate_mock_reply(message, history)
    if provider == "ai_box":
        return _generate_ai_box_reply(message, history)
    raise RuntimeError(f"Unsupported LLM_PROVIDER: {provider}")
