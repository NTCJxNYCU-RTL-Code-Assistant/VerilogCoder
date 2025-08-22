import sys, re, pathlib

SUFFIX = {".v"}
KW = re.compile(r'(^|[^A-Za-z0-9_$])(function|task)\b')
END = re.compile(r'\bend(function|task)\b')

def files_from_args(args):
    if not args: args = ["."]
    out = []
    for a in args:
        p = pathlib.Path(a)
        if p.is_file() and p.suffix in SUFFIX:
            out.append(p)
        elif p.is_dir():
            out += [q for q in p.rglob("*") if q.is_file() and q.suffix in SUFFIX]
    return sorted(set(out))

def strip_block_comments(lines):
    res, in_block = [], False
    for s in lines:
        if not in_block:
            if "/*" in s:
                pre, post = s.split("/*", 1)
                s = pre
                in_block = True
                if "*/" in post:
                    in_block = False
                    s = pre + post.split("*/",1)[1]
            res.append(s)
        else:
            if "*/" in s:
                in_block = False
                res.append(s.split("*/",1)[1])
            else:
                res.append("")  # 保留行號
    return res

def main():
    files = files_from_args(sys.argv[1:])
    if not files:
        print("no RTL files", file=sys.stderr); sys.exit(2)

    errs = 0
    for f in files:
        try:
            lines = f.read_text(encoding="utf-8", errors="ignore").splitlines()
        except Exception:
            continue
        lines = strip_block_comments(lines)
        for i, raw in enumerate(lines, 1):
            line = raw.split("//",1)[0]  # 去單行註解
            if not line.strip(): continue
            if END.search(line): continue
            if KW.search(line):
                errs += 1
                print(f"{f}:{i}: forbidden declaration 'function/task'")

    if errs: sys.exit(1)

if __name__ == "__main__":
    main()