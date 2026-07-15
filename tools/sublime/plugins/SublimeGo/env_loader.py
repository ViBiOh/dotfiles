import os
import subprocess
from os.path import exists, join

# Minimal .env tokenizer with shell-like quoting. Values are parsed, never
# executed: command substitution ($(...)) and backticks are kept literal.
#   - keys: optional "export ", [A-Za-z_][A-Za-z0-9_]*, optional spaces around "="
#   - single quotes: literal, may span multiple lines
#   - double quotes: may span multiple lines, backslash escapes \$ \` \" \\ and
#     line continuation; any other backslash is kept literal
#   - unquoted: rest of the line, trailing whitespace trimmed, an inline "#"
#     comment (preceded by whitespace) removed

_DOUBLE_QUOTE_ESCAPES = {
    "$": "$",
    "`": "`",
    '"': '"',
    "\\": "\\",
}


def _is_key_start(char):
    return char.isalpha() or char == "_"


def _is_key_char(char):
    return char.isalnum() or char == "_"


def _skip_line(text, pos, size):
    while pos < size and text[pos] != "\n":
        pos += 1
    return pos


def _skip_blanks(text, pos, size):
    while pos < size and text[pos] in " \t":
        pos += 1
    return pos


def _skip_export(text, pos, size):
    if text.startswith("export", pos):
        after = pos + len("export")
        if after < size and text[after] in " \t":
            return _skip_blanks(text, after, size)
    return pos


def _read_single_quoted(text, pos, size):
    start = pos
    while pos < size and text[pos] != "'":
        pos += 1
    value = text[start:pos]
    if pos < size:
        pos += 1
    return value, pos


def _read_double_quoted(text, pos, size):
    chars = []
    while pos < size:
        char = text[pos]
        if char == '"':
            pos += 1
            break
        if char == "\\" and pos + 1 < size:
            nxt = text[pos + 1]
            if nxt == "\n":
                pos += 2
                continue
            if nxt in _DOUBLE_QUOTE_ESCAPES:
                chars.append(_DOUBLE_QUOTE_ESCAPES[nxt])
                pos += 2
                continue
        chars.append(char)
        pos += 1
    return "".join(chars), pos


def _read_unquoted(text, pos, size):
    chars = []
    while pos < size and text[pos] != "\n":
        char = text[pos]
        if char == "#" and chars and chars[-1] in " \t":
            break
        chars.append(char)
        pos += 1
    return "".join(chars).rstrip(" \t\r"), pos


def _read_value(text, pos, size):
    pos = _skip_blanks(text, pos, size)
    if pos >= size or text[pos] == "\n":
        return "", pos

    char = text[pos]
    if char == "'":
        return _read_single_quoted(text, pos + 1, size)
    if char == '"':
        return _read_double_quoted(text, pos + 1, size)

    return _read_unquoted(text, pos, size)


def parse_env(text):
    env = {}
    pos = 0
    size = len(text)

    while pos < size:
        char = text[pos]

        if char in " \t\r\n":
            pos += 1
            continue

        if char == "#":
            pos = _skip_line(text, pos, size)
            continue

        pos = _skip_export(text, pos, size)
        if pos >= size or not _is_key_start(text[pos]):
            pos = _skip_line(text, pos, size)
            continue

        key_end = pos
        while key_end < size and _is_key_char(text[key_end]):
            key_end += 1

        key = text[pos:key_end]

        pos = _skip_blanks(text, key_end, size)
        if pos >= size or text[pos] != "=":
            pos = _skip_line(text, pos, size)
            continue

        value, pos = _read_value(text, pos + 1, size)
        env[key] = value

    return env


def load_env_file(cwd, name):
    env_file = join(cwd, name)

    if not exists(env_file):
        return {}

    try:
        with open(env_file, encoding="utf-8") as handle:
            return parse_env(handle.read())
    except OSError as err:
        print("unable to read {}: {}".format(name, err))
        return {}


def load_git_root_env(cwd):
    env = dict(os.environ)

    try:
        is_git = subprocess.call(
            ["git", "rev-parse", "--is-inside-work-tree"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            cwd=cwd,
            timeout=5,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as err:
        print("unable to check git: {}".format(err))
        return env

    if is_git != 0:
        return env

    try:
        git_root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.STDOUT,
            cwd=cwd,
            timeout=5,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as err:
        print("unable to get root path: {}".format(err))
        return env
    except subprocess.CalledProcessError as e:
        print("unable to get root path: {}".format(e.output.decode("utf8")))
        return env

    root = git_root.decode("utf8").rstrip()

    dot_env = load_env_file(root, ".env")
    if dot_env:
        env.update(dot_env)

    return env
