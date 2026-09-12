from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SERVER = ROOT / "server" / "app"
CLIENT = ROOT / "flutter_client" / "lib"


def server_routes() -> list[tuple[str, str]]:
    routes: list[tuple[str, str]] = []
    for path in SERVER.glob("*.py"):
        text = path.read_text(encoding="utf-8")
        router_match = re.search(r"router\s*=\s*APIRouter\((.*?)\)", text, re.S)
        prefix = ""
        if router_match:
            prefix_match = re.search(
                r"prefix\s*=\s*['\"]([^'\"]+)['\"]",
                router_match.group(1),
            )
            if prefix_match:
                prefix = prefix_match.group(1)

        for match in re.finditer(
            r"@(app|router)\.(get|post|put|patch|delete)\(\s*['\"]([^'\"]*)['\"]",
            text,
        ):
            owner, method, route = match.groups()
            routes.append(
                (method.upper(), (prefix + route) if owner == "router" else route)
            )
    return routes


def extract_dart_string(text: str, start: int) -> tuple[str, int] | None:
    while start < len(text) and text[start].isspace():
        start += 1
    if start >= len(text) or text[start] not in ("'", '"'):
        return None

    quote = text[start]
    i = start + 1
    out: list[str] = []
    while i < len(text):
        ch = text[i]
        if ch == "\\" and i + 1 < len(text):
            out.extend([ch, text[i + 1]])
            i += 2
            continue
        if ch == "$" and i + 1 < len(text) and text[i + 1] == "{":
            depth = 1
            j = i + 2
            while j < len(text) and depth:
                if text[j] == "{":
                    depth += 1
                elif text[j] == "}":
                    depth -= 1
                j += 1
            out.append(text[i:j])
            i = j
            continue
        if ch == quote:
            return "".join(out), i + 1
        out.append(ch)
        i += 1
    return None


def all_dart_strings(text: str):
    i = 0
    while i < len(text):
        if text[i] in ("'", '"'):
            parsed = extract_dart_string(text, i)
            if parsed:
                value, end = parsed
                yield i, value
                i = end
                continue
        i += 1


def api_calls() -> list[tuple[str, str, str]]:
    calls: list[tuple[str, str, str]] = []
    method_map = {
        "getJson": "GET",
        "getBytes": "GET",
        "postJson": "POST",
        "patchJson": "PATCH",
    }
    for path in CLIENT.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        for name, method in method_map.items():
            for match in re.finditer(rf"\.{name}\s*\(", text):
                parsed = extract_dart_string(text, match.end())
                if parsed:
                    value, _ = parsed
                    if value.startswith("/"):
                        calls.append((method, value, str(path.relative_to(ROOT))))

        for _, value in all_dart_strings(text):
            marker = "${ApiConfig.baseUrl}"
            if marker in value:
                route = value.split(marker, 1)[1]
                if route.startswith("/"):
                    calls.append(("ANY", route, str(path.relative_to(ROOT))))
    return calls


def route_regex(client_path: str) -> re.Pattern[str]:
    path = client_path.split("?", 1)[0]
    path = re.sub(r"\$suffix$", "", path)
    token = "__DYNAMIC__"
    path = re.sub(r"\$\{[^}]+\}", token, path)
    path = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", token, path)
    escaped = re.escape(path).replace(re.escape(token), r"[^/]+")
    return re.compile(rf"^{escaped}$")


def main() -> int:
    routes = server_routes()
    failures: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str, str]] = set()

    for method, client_path, source in api_calls():
        key = (method, client_path, source)
        if key in seen:
            continue
        seen.add(key)
        pattern = route_regex(client_path)
        matched = any(
            (method == "ANY" or method == server_method)
            and pattern.fullmatch(server_path)
            for server_method, server_path in routes
        )
        if not matched:
            failures.append(key)

    if failures:
        print("API sözleşme kontrolü başarısız:")
        for method, client_path, source in failures:
            print(f"  MISS {method:5} {client_path}  [{source}]")
        return 1

    print(
        "API sözleşme kontrolü başarılı. "
        f"Sunucu route sayısı={len(routes)}, istemci çağrısı={len(seen)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
