import sys, re, pathlib

SUFFIX = {".v"}
KW = re.compile(r'(^|[^A-Za-z0-9_$])(function|task)\b')
END = re.compile(r'\bend(function|task)\b')


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
                res.append("")  
    return res

def lint(file_path):
    lint_output = []
    if not file_path:
        return["Error:no RTL files"];
    p = pathlib.Path(file_path)
    try:
        lines = p.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception as e:
        return [f"Error: could not read file {file_path}: {e}"]
      
    lines = strip_block_comments(lines)

    for i, raw in enumerate(lines, 1):
        line = raw.split("//",1)[0]  
        if not line.strip(): continue
        if END.search(line): continue
        if KW.search(line):
            lint_output.append(f"{file_path}:{i}: forbidden declaration 'function/task'")
    return lint_output

