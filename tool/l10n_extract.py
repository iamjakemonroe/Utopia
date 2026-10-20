"""Moves the words in Dart files into lib/l10n/app_en.arb, ready for
translation, replacing each with `strings.<key>` (or `strings.<key>(...)`
when it has values in it, like `$name`), from lib/l10n/strings.dart.

  python3 tool/l10n_extract.py lib/features/settings/presentation/settings_screen.dart [...]
  python3 tool/l10n_extract.py --dry <files>   (lists what it would move)

Only words people read are moved: text with a space or a capital letter
in it, not ids, keys, routes or paths, and never what's compared or used
as a map key. The English stays exactly as it was.

Afterwards the analyzer's word is taken: `const` comes off what now holds
a word from the file (a widget, a list), and a word that has to stay
constant (a default value, a case) is put back as it was. Run from the
repo root; runs flutter gen-l10n and dart analyze itself.
"""
import json
import os
import re
import subprocess
import sys

ARB = 'lib/l10n/app_en.arb'
STRINGS = 'lib/l10n/strings.dart'
KEYWORDS = set('''abstract as assert async await base break case catch class const continue
covariant default deferred do dynamic else enum export extends extension external factory
false final finally for function get hide if implements import in interface is late library
mixin new null of on operator part required rethrow return sealed set show static super switch
sync this throw true try type typedef var void when while with yield'''.split())


# ── scanning Dart ──────────────────────────────────────────────────────────

class Lit:
    """One string literal: [start, end) in the source, its text parts and
    interpolations, and whether it's raw or triple-quoted."""

    def __init__(self, start, end, parts, raw, triple):
        self.start, self.end, self.parts, self.raw, self.triple = start, end, parts, raw, triple


def scan(src):
    """Every string literal outside comments, in order (nested ones inside
    interpolations aren't returned on their own)."""
    lits = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            i = src.find('\n', i)
            i = n if i < 0 else i
            continue
        if src.startswith('/*', i):
            depth, i = 1, i + 2
            while i < n and depth:
                if src.startswith('/*', i):
                    depth, i = depth + 1, i + 2
                elif src.startswith('*/', i):
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
            continue
        if c in '\'"' or (c in 'rR' and i + 1 < n and src[i + 1] in '\'"' and not (src[i - 1:i].isalnum() or src[i - 1:i] == '_')):
            lit, i = read_string(src, i)
            lits.append(lit)
            continue
        i += 1
    return lits


def read_string(src, i):
    start = i
    raw = src[i] in 'rR'
    if raw:
        i += 1
    q = src[i]
    triple = src.startswith(q * 3, i)
    close = q * 3 if triple else q
    i += len(close)
    parts = []  # ('text', str) | ('expr', source, is_braced)
    buf = []
    while True:
        if i >= len(src):
            raise ValueError('unterminated string at %d' % start)
        if src.startswith(close, i):
            i += len(close)
            break
        c = src[i]
        if not raw and c == '\\':
            buf.append(src[i:i + 2] if src[i + 1] != 'u' else src[i:src.index('}', i) + 1] if src[i + 2] == '{' else src[i:i + 6])
            i += len(buf[-1])
            continue
        if not raw and c == '$':
            if buf:
                parts.append(('text', ''.join(buf)))
                buf = []
            if src[i + 1] == '{':
                j, depth = i + 2, 1
                while depth:
                    if src[j] in '\'"':
                        _, j = read_string(src, j)
                        continue
                    if src[j] == '{':
                        depth += 1
                    elif src[j] == '}':
                        depth -= 1
                    j += 1
                parts.append(('expr', src[i + 2:j - 1], True))
                i = j
            else:
                m = re.match(r'[A-Za-z_]\w*', src[i + 1:])
                parts.append(('expr', m.group(0), False))
                i += 1 + len(m.group(0))
            continue
        buf.append(c)
        i += 1
    if buf:
        parts.append(('text', ''.join(buf)))
    return Lit(start, i, parts, raw, triple), i


def unescape(s):
    out, i = [], 0
    simple = {'n': '\n', 't': '\t', 'r': '\r', 'b': '\b', 'f': '\f', 'v': '\v'}
    while i < len(s):
        if s[i] == '\\':
            c = s[i + 1]
            if c == 'u':
                if s[i + 2] == '{':
                    j = s.index('}', i)
                    out.append(chr(int(s[i + 3:j], 16)))
                    i = j + 1
                else:
                    out.append(chr(int(s[i + 2:i + 6], 16)))
                    i += 6
                continue
            out.append(simple.get(c, c))
            i += 2
            continue
        out.append(s[i])
        i += 1
    return ''.join(out)


# ── choosing ───────────────────────────────────────────────────────────────

def groups(src, lits):
    """Adjacent literals (implicitly joined) as one: lists of Lit."""
    out = []
    for lit in lits:
        if out and re.fullmatch(r'\s*', src[out[-1][-1].end:lit.start]):
            out[-1].append(lit)
        else:
            out.append([lit])
    return out


def wordy(text):
    return bool(re.search(r'[A-Za-z]', text)) and (' ' in text.strip() or re.match(r"\s*[A-Z]", text) is not None)


def skip_reason(src, group):
    first, last = group[0], group[-1]
    if any(l.raw or l.triple for l in group):
        return 'raw'
    text = ''.join(unescape(p[1]) for l in group for p in l.parts if p[0] == 'text')
    if not wordy(text):
        return 'not words'
    if '{' in text or '}' in text or '​' in text:
        return 'braces'
    if re.fullmatch(r"[a-z0-9_.\-/:@#]+", text.strip()):
        return 'id'
    if re.fullmatch(r"[A-Z0-9_.]+", text.strip()) or ('_' in text and ' ' not in text.strip()):
        return 'constant name'
    if re.fullmatch(r"\s*[a-z_]+(,\s*[a-z_]+)+,?\s*", text):
        return 'column list'
    if re.fullmatch(r"[A-Z][a-z]+/[A-Za-z_]+", text.strip()):
        return 'time zone'
    if re.search(r'^(assets/|https?:|package:|/)', text) or re.search(r'\.(png|jpg|wav|m4a|json|dart|svg)$', text):
        return 'path'
    line_start = src.rfind('\n', 0, first.start) + 1
    line = src[line_start:src.find('\n', first.start)]
    before = src[max(0, first.start - 40):first.start]
    after = src[last.end:last.end + 20]
    if re.match(r'\s*(import|export|part)\b', line) or line.lstrip().startswith('@'):
        return 'directive'
    if re.search(r'(==|!=|\bcase|\[)\s*$', before) or re.match(r'\s*(\]|==|!=)', after):
        return 'compared or indexed'
    if re.match(r'\s*:(?!:)', after) and not re.search(r'\?\s*$', before):
        return 'map key'
    if re.search(r'\b(Key|ValueKey|debugPrint|print|log|RegExp|Uri\.parse|rpc|from|select|eq|channel|Exception|StateError|ArgumentError|UnimplementedError|assert|contains|startsWith|endsWith|indexOf|lastIndexOf|replaceAll|replaceFirst|split|DateFormat|NumberFormat|invoke|getString|setString|getBool|setBool|getInt|setInt|remove)\s*\(\s*$', before):
        return 'not shown'
    if re.search(r'\bthrow\s+$', before):
        return 'thrown'
    if '[' in text and ']' in text:
        return 'markup'
    return None


# ── keys and the ARB ───────────────────────────────────────────────────────

def camel(words):
    words = [w for w in words if w]
    if not words:
        return ''
    return words[0].lower() + ''.join(w[:1].upper() + w[1:].lower() for w in words[1:])


def prefix_for(path):
    stem = os.path.splitext(os.path.basename(path))[0]
    stem = re.sub(r'_(screen|sheet|sheets|widgets?|controller|dialog|page|popup|card|view|presentation|repository|providers?)$', '', stem)
    return camel(stem.split('_'))


def placeholder_name(expr, used):
    m = re.fullmatch(r'(?:[A-Za-z_]\w*\??\.)*([A-Za-z_]\w*)(?:\(\))?', expr.strip())
    base = m.group(1).lstrip('_') if m else 'value'
    base = base or 'value'
    if base in KEYWORDS:
        base += 'Value'
    name, k = base, 2
    while name in used:
        name, k = f'{base}{k}', k + 1
    used.add(name)
    return name


def load_arb():
    return json.load(open(ARB)) if os.path.exists(ARB) else {'@@locale': 'en'}


def save_arb(arb):
    open(ARB, 'w').write(json.dumps(arb, indent=2, ensure_ascii=False) + '\n')


def key_for(arb, prefix, text, placeholders):
    words = re.findall(r'[A-Za-z0-9]+', re.sub(r'\{\w+\}', ' ', text))
    base = prefix + ''.join(w[:1].upper() + w[1:].lower() for w in words[:5])
    if not re.match(r'[a-z]', base):
        base = 'text' + base[:1].upper() + base[1:]
    if base in KEYWORDS:
        base += 'Text'
    key, k = base, 2
    while key in arb and (arb[key] != text or sorted(arb.get('@' + key, {}).get('placeholders', {})) != sorted(placeholders)):
        key, k = f'{base}{k}', k + 1
    return key


# ── one file ───────────────────────────────────────────────────────────────

def extract(path, arb, originals):
    src = open(path).read()
    lits = scan(src)
    prefix = prefix_for(path)
    edits = []
    for group in groups(src, lits):
        if skip_reason(src, group):
            continue
        message, args, used = [], [], set()
        for lit in group:
            for part in lit.parts:
                if part[0] == 'text':
                    message.append(unescape(part[1]))
                else:
                    name = placeholder_name(part[1], used)
                    message.append('{%s}' % name)
                    args.append((name, part[1]))
        text = ''.join(message)
        key = key_for(arb, prefix, text, [a[0] for a in args])
        arb[key] = text
        meta = {'description': f'{os.path.relpath(path, "lib")}'}
        if args:
            meta['placeholders'] = {name: {'type': 'Object'} for name, _ in args}
        arb['@' + key] = meta
        call = f'strings.{key}' + (f'({", ".join(expr for _, expr in args)})' if args else '')
        edits.append((group[0].start, group[-1].end, call, src[group[0].start:group[-1].end]))
    for start, end, call, original in reversed(edits):
        src = src[:start] + call + src[end:]
        originals[call] = original
    open(path, 'w').write(src)
    if edits:
        add_import(path)
    return len(edits)


def add_import(path):
    """Imports strings.dart into [path], or into its library if it's a part."""
    src = open(path).read()
    part_of = re.search(r"^part of '([^']+)';", src, re.M)
    if part_of:
        add_import(os.path.normpath(os.path.join(os.path.dirname(path), part_of.group(1))))
        return
    rel = os.path.relpath(STRINGS, os.path.dirname(path))
    line = f"import '{rel}';\n"
    if line in src:
        return
    imports = list(re.finditer(r"^import [^\n]*\n", src, re.M))
    if imports:
        at = imports[-1].end()
    else:
        library = re.search(r"^library[^\n]*\n", src, re.M)
        at = library.end() if library else 0
        line += '\n'
    open(path, 'w').write(src[:at] + line + src[at:])


# ── what the analyzer says ─────────────────────────────────────────────────

CONST_CODES = {
    'CONST_WITH_NON_CONSTANT_ARGUMENT', 'INVALID_CONSTANT', 'NON_CONSTANT_LIST_ELEMENT',
    'NON_CONSTANT_MAP_VALUE', 'NON_CONSTANT_MAP_KEY', 'NON_CONSTANT_SET_ELEMENT',
    'CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE', 'CONST_CONSTRUCTOR_WITH_NON_CONST_SUPER',
    'CONST_EVAL_METHOD_INVOCATION', 'CONST_EVAL_PROPERTY_ACCESS', 'CONST_EVAL_TYPE_BOOL_NUM_STRING',
    'NON_CONSTANT_RECORD_FIELD', 'CONST_WITH_NON_CONST', 'CONST_EVAL_EXTENSION_METHOD',
}
REVERT_CODES = {
    'NON_CONSTANT_DEFAULT_VALUE', 'NON_CONSTANT_CASE_EXPRESSION', 'INVALID_ANNOTATION_CONSTANT_VALUE',
    'CONSTANT_PATTERN_WITH_NON_CONSTANT_EXPRESSION', 'NON_CONSTANT_ANNOTATION_CONSTRUCTOR',
    'ARGUMENT_TYPE_NOT_ASSIGNABLE', 'CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE_FROM_DEFERRED_LIBRARY',
}


def analyze(paths):
    subprocess.run(['flutter', 'gen-l10n'], check=True, capture_output=True)
    # All of lib: taking const off one file's catalog can matter elsewhere.
    r = subprocess.run(['dart', 'analyze', '--format=machine', 'lib'], capture_output=True, text=True)
    errors = []
    for line in (r.stdout + r.stderr).splitlines():
        f = line.split('|')
        if len(f) >= 8 and f[0] == 'ERROR':
            errors.append((f[2], f[3], int(f[4]), int(f[5]), int(f[6]), f[7]))
    return errors


def offset(src, line, col):
    lines = src.split('\n')
    return sum(len(l) + 1 for l in lines[:line - 1]) + col - 1


def code_spans(src):
    """Where strings and comments are, so `const` inside them is ignored."""
    spans = []
    for lit in scan(src):
        spans.append((lit.start, lit.end))
    for m in re.finditer(r'//[^\n]*|/\*.*?\*/', src, re.S):
        spans.append((m.start(), m.end()))
    return spans


def matching(src, i):
    pairs = {'(': ')', '[': ']', '{': '}', '<': '>'}
    stack = [pairs[src[i]]]
    j = i + 1
    while j < len(src) and stack:
        c = src[j]
        if c in '\'"':
            _, j = read_string(src, j)
            continue
        if c in '([{':
            stack.append(pairs[c])
        elif c in ')]}':
            if c != stack[-1] and stack[-1] == '>':
                stack.pop()
                continue
            stack.pop()
        j += 1
    return j


def drop_const(src, at):
    """Takes `const` off the innermost constant expression around [at];
    a `const` declaration becomes `final`. Returns the new source, or None."""
    spans = code_spans(src)
    best = None
    for m in re.finditer(r'\bconst\b', src[:at]):
        if any(a <= m.start() < b for a, b in spans):
            continue
        j = m.end()
        while j < len(src) and src[j].isspace():
            j += 1
        decl = re.match(r'(?:[A-Za-z_][\w<>?, ]*\s+)?[A-Za-z_]\w*\s*=(?!=)', src[j:])
        k = j
        while k < len(src) and (src[k].isalnum() or src[k] in '_.<>, ?'):
            if src[k] == '<':
                k = matching(src, k)
                continue
            k += 1
        if k < len(src) and src[k] in '([{':
            end = matching(src, k)
            if j <= at < end:
                best = (m.start(), m.end(), 'expr')
        elif decl:
            end = src.find(';', j)
            if j <= at <= end:
                best = (m.start(), m.end(), 'decl')
    if not best:
        return None
    s, e, kind = best
    if kind == 'decl':
        return src[:s] + 'final' + src[e:]
    tail = e
    while tail < len(src) and src[tail] == ' ':
        tail += 1
    return src[:s] + src[tail:]


def revert(src, at, originals):
    for call, original in sorted(originals.items(), key=lambda kv: -len(kv[0])):
        start = src.rfind(call, 0, at + len(call))
        if start != -1 and start <= at < start + len(call) + 1:
            return src[:start] + original + src[start + len(call):]
    return None


def settle(paths, originals):
    for round_ in range(60):
        errors = analyze(paths)
        if not errors:
            return True
        changed = False
        by_file = {}
        for e in errors:
            by_file.setdefault(e[1], []).append(e)
        for f, errs in by_file.items():
            src = open(f).read()
            # From the end, so earlier offsets stay right.
            for code, _, line, col, length, msg in sorted(errs, key=lambda e: (-e[2], -e[3])):
                at = offset(src, line, col)
                new = None
                if code in REVERT_CODES:
                    new = revert(src, at, originals)
                elif code in CONST_CODES or 'const' in msg.lower() or 'constant' in msg.lower():
                    new = drop_const(src, at)
                    if new is None:
                        new = revert(src, at, originals)
                if new is not None and new != src:
                    src, changed = new, True
                    break  # one fix per file per round: offsets move
            open(f, 'w').write(src)
        if not changed:
            for e in errors[:20]:
                print('  unresolved:', e)
            return False
    return False


def tidy(arb):
    """Keys no Dart file uses any more (put back) leave the ARB."""
    used = set()
    for root, _, files in os.walk('lib'):
        for name in files:
            if name.endswith('.dart') and not name.startswith('app_localizations'):
                used |= set(re.findall(r'\bstrings\.(\w+)', open(os.path.join(root, name)).read()))
    for key in [k for k in arb if not k.startswith('@') and k not in used and k != 'appTitle']:
        del arb[key]
        arb.pop('@' + key, None)


def dry(paths):
    for p in paths:
        src = open(p).read()
        for group in groups(src, scan(src)):
            if skip_reason(src, group):
                continue
            line = src.count('\n', 0, group[0].start) + 1
            before = src[max(0, group[0].start - 30):group[0].start].replace('\n', ' ')
            print(f'{p}:{line}: [{before.strip()[-24:]}] {src[group[0].start:group[-1].end][:110]!s}'.replace('\n', ' '))


def main():
    if sys.argv[1] == '--dry':
        dry(sys.argv[2:])
        return
    paths = sys.argv[1:]
    arb = load_arb()
    originals = {}
    total = 0
    for p in paths:
        n = extract(p, arb, originals)
        total += n
        print(f'{p}: {n}')
    save_arb(arb)
    ok = settle(paths, originals)
    arb = load_arb()
    tidy(arb)
    save_arb(arb)
    subprocess.run(['flutter', 'gen-l10n'], check=True, capture_output=True)
    # A one-line if that now wraps wants braces; a file whose words all
    # went back doesn't need the import.
    for p in paths:
        subprocess.run(['dart', 'fix', '--apply',
                        '--code=curly_braces_in_flow_control_structures',
                        '--code=unused_import', p], capture_output=True)
    subprocess.run(['dart', 'format', *paths], capture_output=True)
    print('moved', total, 'strings;', 'clean' if ok else 'NOT clean')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
