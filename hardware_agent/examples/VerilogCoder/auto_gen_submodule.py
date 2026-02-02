import os
from pathlib import Path
import re
from openai import OpenAI
from prompt_templates import Autogen_Submodule_Spec_System_Prompt
import shutil
from dataclasses import dataclass

def max_prob_index(folder_path):
    folder = Path(folder_path)
    max_idx = 0

    pattern = re.compile(r"^prob(\d+)_")

    for file in folder.iterdir():
        match = pattern.match(file.stem)
        if match:
            idx = int(match.group(1))
            max_idx = max(max_idx, idx)

    return max_idx

def file_is_exist(folder_path, target):
    folder = Path(folder_path)

    for file in folder.iterdir():
        
        stem = file.stem
        first = stem.find("_")
        last = stem.rfind("_")

        if first == -1 or first == last:
            continue

        middle = stem[first + 1:last]

        if middle == target:
            return file

    return False

def _mask_comments_and_strings_verilog(text):
    s = list(text)
    n = len(s)
    i = 0

    NORMAL, LINE_COMMENT, BLOCK_COMMENT, STRING = 0, 1, 2, 3
    state = NORMAL

    while i < n:
        c = s[i]

        if state == NORMAL:
            if c == "/" and i + 1 < n and s[i + 1] == "/":
                s[i] = " "; s[i + 1] = " "
                i += 2
                state = LINE_COMMENT
                continue

            if c == "/" and i + 1 < n and s[i + 1] == "*":
                s[i] = " "; s[i + 1] = " "
                i += 2
                state = BLOCK_COMMENT
                continue

            if c == '"':
                s[i] = " "
                i += 1
                state = STRING
                continue

            i += 1
            continue

        if state == LINE_COMMENT:
            if c == "\n":
                state = NORMAL
            else:
                s[i] = " "
            i += 1
            continue

        if state == BLOCK_COMMENT:
            if c == "*" and i + 1 < n and s[i + 1] == "/":
                s[i] = " "; s[i + 1] = " "
                i += 2
                state = NORMAL
            else:
                s[i] = " "
                i += 1
            continue

        if state == STRING:
            # handle \" or other escapes
            if c == "\\" and i + 1 < n:
                s[i] = " "; s[i + 1] = " "
                i += 2
                continue
            if c == '"':
                s[i] = " "
                i += 1
                state = NORMAL
            else:
                s[i] = " "
                i += 1
            continue

    return "".join(s)

def split_module_and_rest(verilog_text, module_name):
    masked = _mask_comments_and_strings_verilog(verilog_text)

    # find "module <name>"
    mod_decl = re.compile(r"\bmodule\b\s+([a-zA-Z_]\w*)", re.MULTILINE)

    start_pos = None
    for m in mod_decl.finditer(masked):
        if m.group(1) == module_name:
            start_pos = m.start()
            break

    if start_pos is None:
        return verilog_text, ""  

    
    token_re = re.compile(r"\bmodule\b|\bendmodule\b", re.MULTILINE)
    depth = 0
    end_pos = None

    for t in token_re.finditer(masked, pos=start_pos):
        if t.group(0) == "module":
            depth += 1
        else:  # endmodule
            depth -= 1
            if depth == 0:
                end_pos = t.end()
                break

    if end_pos is None or depth != 0:
        return verilog_text, ""

    before = verilog_text[:start_pos]
    block = verilog_text[start_pos:end_pos]
    after = verilog_text[end_pos:]
    rest = before + after
    return block, rest


def create_refmodule(folder_path, prob_idx, RefModule, submodule):
    submodule_name = submodule.replace("_ref", "_dut")
    dut_text = RefModule.replace("_ref", "_dut").replace("RefModule", "TopModule")
    dut, rest = split_module_and_rest(dut_text, submodule_name)
    

    filename = f"prob{prob_idx:03d}_{submodule}.sv"
    path = os.path.join(folder_path, filename)
    path = Path(path)
    path.write_text(rest+"\n"+RefModule, encoding="utf-8")
    
    submodule_name = submodule.replace("_ref", "")
    filename = f"prob{prob_idx:03d}_{submodule_name}_top.sv"
    path = os.path.join(folder_path, filename)
    path = Path(path)
    path.write_text(rest, encoding="utf-8")

    return dut

def create_testbench(folder_path, prob_idx, testbench, submodule):
    submodule = submodule.replace("_ref", "_test")
    filename = f"prob{prob_idx:03d}_{submodule}.sv"
    path = os.path.join(folder_path, filename)
    path = Path(path)
    path.write_text(testbench, encoding="utf-8")

def create_spec(folder_path, prob_idx, dut, submodule, llm_configs):
    cfg = llm_configs[0]
    client = OpenAI(
        api_key=cfg["api_key"],
        base_url=cfg["base_url"],
    )
    messages = []
    messages.append({"role": "system", "content": Autogen_Submodule_Spec_System_Prompt})
    text = "Question: Explain the high-level functionality of the Verilog module.\n"
    text += dut
    text += "Answer:"
    messages.append({"role": "user", "content": text})
    response = client.chat.completions.create(
        model=cfg["model"],
        messages=messages
    )

    reply = response.choices[0].message.content
    reply += "\n\n ### The following code is incomplete. Please only complete the missing parts and do not modify the existing implementation. \n\n"
    reply += keep_wiring_and_decls_verilog(dut)

    submodule = submodule.replace("_ref", "_prompt")
    filename = f"prob{prob_idx:03d}_{submodule}.txt"
    path = os.path.join(folder_path, filename)
    path = Path(path)
    path.write_text(reply, encoding="utf-8")



@dataclass
class Tok:
    typ: str
    val: str
    s: int
    e: int

_KEYWORDS = {
    "module", "endmodule",
    "begin", "end",
    "generate", "endgenerate",
    "function", "endfunction",
    "task", "endtask",
    "case", "casex", "casez", "endcase",
    "always", "always_ff", "always_comb", "always_latch",
    "initial", "final",
    "if", "else", "for", "while", "repeat", "forever",
    "parameter", "localparam", "input", "output", "inout",
    "wire", "reg", "logic", "genvar",
    "assign",
}

_DECL_KW = {"parameter","localparam","input","output","inout","wire","reg","logic","genvar"}
_PROC_KW = {"always","always_ff","always_comb","always_latch","initial","final"}

def _tokenize_verilog(text):
    toks: list[Tok] = []
    i, n = 0, len(text)

    def is_id_start(c):
        return c.isalpha() or c == "_"

    def is_id_char(c):
        return c.isalnum() or c == "_" or c == "$"

    while i < n:
        c = text[i]

        if c.isspace():
            i += 1
            continue

        if c == "/" and i + 1 < n and text[i + 1] == "/":
            i += 2
            while i < n and text[i] != "\n":
                i += 1
            continue

        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i = min(n, i + 2)
            continue

        if c == '"':
            i += 1
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    i += 2
                    continue
                if text[i] == '"':
                    i += 1
                    break
                i += 1
            continue

        if is_id_start(c):
            s = i
            i += 1
            while i < n and is_id_char(text[i]):
                i += 1
            w = text[s:i]
            wl = w.lower()
            if wl in _KEYWORDS:
                toks.append(Tok("kw", wl, s, i))
            else:
                toks.append(Tok("id", w, s, i))
            continue

        if c.isdigit():
            s = i
            i += 1
            while i < n and (text[i].isdigit() or text[i] in "_'hHbBoOdDxXabcdefABCDEF"):
                i += 1
            toks.append(Tok("num", text[s:i], s, i))
            continue

        toks.append(Tok("sym", c, i, i + 1))
        i += 1

    return toks

def _skip_balanced(toks, i, open_sym, close_sym):
    assert toks[i].typ == "sym" and toks[i].val == open_sym
    depth = 1
    i += 1
    while i < len(toks) and depth > 0:
        t = toks[i]
        if t.typ == "sym" and t.val == open_sym:
            depth += 1
        elif t.typ == "sym" and t.val == close_sym:
            depth -= 1
        i += 1
    return i

def _skip_attribute(toks, i):
    while i + 1 < len(toks) and toks[i].typ == "sym" and toks[i].val == "(" and toks[i+1].typ == "sym" and toks[i+1].val == "*":
        i += 2
        while i + 1 < len(toks):
            if toks[i].typ == "sym" and toks[i].val == "*" and toks[i+1].typ == "sym" and toks[i+1].val == ")":
                i += 2
                break
            i += 1
    return i

def _skip_statement(toks, i):
    """Skip ONE Verilog statement starting at token i. Return index after it."""
    i = _skip_attribute(toks, i)
    if i >= len(toks):
        return i

    t = toks[i]
    if t.typ == "kw" and t.val == "begin":
        depth = 1
        i += 1
        while i < len(toks) and depth > 0:
            if toks[i].typ == "kw" and toks[i].val == "begin":
                depth += 1
            elif toks[i].typ == "kw" and toks[i].val == "end":
                depth -= 1
            i += 1
        return i

    if t.typ == "kw" and t.val == "if":
        i += 1
        if i < len(toks) and toks[i].typ == "sym" and toks[i].val == "(":
            i = _skip_balanced(toks, i, "(", ")")
        i = _skip_statement(toks, i)
        if i < len(toks) and toks[i].typ == "kw" and toks[i].val == "else":
            i += 1
            i = _skip_statement(toks, i)
        return i

    if t.typ == "kw" and t.val in {"case","casex","casez"}:
        i += 1
        if i < len(toks) and toks[i].typ == "sym" and toks[i].val == "(":
            i = _skip_balanced(toks, i, "(", ")")
        depth = 1
        while i < len(toks) and depth > 0:
            if toks[i].typ == "kw" and toks[i].val in {"case","casex","casez"}:
                depth += 1
            elif toks[i].typ == "kw" and toks[i].val == "endcase":
                depth -= 1
            i += 1
        return i

    if t.typ == "kw" and t.val in {"for","while","repeat","forever"}:
        i += 1
        if i < len(toks) and toks[i].typ == "sym" and toks[i].val == "(":
            i = _skip_balanced(toks, i, "(", ")")
        return _skip_statement(toks, i)

    if t.typ == "kw" and t.val in {"function","task"}:
        endkw = "endfunction" if t.val == "function" else "endtask"
        i += 1
        while i < len(toks):
            if toks[i].typ == "kw" and toks[i].val == endkw:
                return i + 1
            i += 1
        return i

    while i < len(toks):
        if toks[i].typ == "sym" and toks[i].val == ";":
            return i + 1
        i += 1
    return i

def keep_wiring_and_decls_verilog(verilog_text):
    toks = _tokenize_verilog(verilog_text)
    if not toks:
        return verilog_text

    kept_spans: list[tuple[int,int]] = []

    i = 0
    while i < len(toks) and not (toks[i].typ == "kw" and toks[i].val == "module"):
        i += 1
    if i >= len(toks):
        return verilog_text

    mod_start = toks[i].s
    i += 1

    par = 0
    header_end = None
    while i < len(toks):
        t = toks[i]
        if t.typ == "sym" and t.val == "(":
            par += 1
        elif t.typ == "sym" and t.val == ")":
            if par > 0:
                par -= 1
            if par == 0:
                j = i + 1
                while j < len(toks) and toks[j].typ == "sym" and toks[j].val in {",",}:
                    j += 1
                if j < len(toks) and toks[j].typ == "sym" and toks[j].val == ";":
                    header_end = toks[j].e
                    break
        i += 1

    if header_end is None:
        while i < len(toks) and not (toks[i].typ == "sym" and toks[i].val == ";"):
            i += 1
        header_end = toks[i].e if i < len(toks) else len(verilog_text)

    kept_spans.append((mod_start, header_end))

    i = 0
    while i < len(toks) and toks[i].s < header_end:
        i += 1

    def stmt_start(i):
        return _skip_attribute(toks, i)

    while i < len(toks):
        i = stmt_start(i)
        if i >= len(toks):
            break

        if toks[i].typ == "kw" and toks[i].val == "endmodule":
            kept_spans.append((toks[i].s, toks[i].e))
            break

        if toks[i].typ == "kw" and toks[i].val == "generate":
            depth = 1
            i += 1
            while i < len(toks) and depth > 0:
                if toks[i].typ == "kw" and toks[i].val == "generate":
                    depth += 1
                elif toks[i].typ == "kw" and toks[i].val == "endgenerate":
                    depth -= 1
                i += 1
            continue

        if toks[i].typ == "kw" and toks[i].val in _PROC_KW:
            i += 1
            if i < len(toks) and toks[i].typ == "sym" and toks[i].val == "@":
                i += 1
                if i < len(toks) and toks[i].typ == "sym" and toks[i].val == "(":
                    i = _skip_balanced(toks, i, "(", ")")
            if i < len(toks) and toks[i].typ == "sym" and toks[i].val == "#":
                i += 1
                if i < len(toks) and toks[i].typ == "sym" and toks[i].val == "(":
                    i = _skip_balanced(toks, i, "(", ")")
            i = _skip_statement(toks, i)
            continue

        if toks[i].typ == "kw" and toks[i].val in _DECL_KW:
            s0 = toks[i].s
            j = i
            while j < len(toks) and not (toks[j].typ == "sym" and toks[j].val == ";"):
                j += 1
            if j < len(toks):
                kept_spans.append((s0, toks[j].e))
                i = j + 1
            else:
                kept_spans.append((s0, len(verilog_text)))
                break
            continue

        
        if toks[i].typ == "kw" and toks[i].val == "assign":
            i = _skip_statement(toks, i)
            continue

        
        def try_match_instance(ii):
            ii = stmt_start(ii)
            if ii >= len(toks): return None

            if toks[ii].typ not in {"id"}:
                return None
            ii += 1

            if ii < len(toks) and toks[ii].typ == "sym" and toks[ii].val == "#":
                ii += 1
                if ii >= len(toks) or not (toks[ii].typ == "sym" and toks[ii].val == "("):
                    return None
                ii = _skip_balanced(toks, ii, "(", ")")

            if ii >= len(toks) or toks[ii].typ != "id":
                return None
            ii += 1

            if ii >= len(toks) or not (toks[ii].typ == "sym" and toks[ii].val == "("):
                return None
            ii = _skip_balanced(toks, ii, "(", ")")
            if ii >= len(toks) or not (toks[ii].typ == "sym" and toks[ii].val == ";"):
                return None
            return ii + 1

        nxt = try_match_instance(i)
        if nxt is not None:
            kept_spans.append((toks[i].s, toks[nxt - 1].e))
            i = nxt
            continue

        i = _skip_statement(toks, i)

    kept_spans.sort()
    merged = []
    for s,e in kept_spans:
        if not merged or s > merged[-1][1]:
            merged.append([s,e])
        else:
            merged[-1][1] = max(merged[-1][1], e)

    out = []
    last_end = None

    for s, e in merged:
        if last_end is not None:
            gap = verilog_text[last_end:s]
            if "\n" in gap:
                out.append("\n")
        out.append(verilog_text[s:e])
        last_end = e

    return "".join(out).rstrip() + "\n"




def copy_file_to_dir(src_file, dst_dir, idx):
    src = src_file
    src_file = str(src_file.name.split("_", 1)[1])
    filename = f"prob{idx:03d}_{src_file}"
    dst = os.path.join(dst_dir, filename)
    dst = Path(dst)
    shutil.copy(src, dst)

def gen_submodule_spec(task_case, path, llm_configs):
    folder_path = os.path.join(path, task_case['task_id'])
    temp_path = os.path.join(path, "tmp")
    os.makedirs(folder_path, exist_ok=True)
    os.makedirs(temp_path, exist_ok=True)
    task_set = set()
    for task in task_case['submodule'].split('\n'):
        if task == "":
            break
        taskname = task.replace("_ref", "")
        if file_is_exist(folder_path, taskname) != False:
            temp_idx = max_prob_index(temp_path)+1
            p = file_is_exist(folder_path, taskname)

            prompt_src = p.with_name(p.name.replace("_test.sv", "_prompt.txt").replace("_ref.sv", "_prompt.txt").replace("_top.sv", "_prompt.txt"))
            test_src   = p.with_name(p.name.replace("_prompt.txt", "_test.sv").replace("_ref.sv", "_test.sv").replace("_top.sv", "_test.sv"))
            ref_src    = p.with_name(p.name.replace("_prompt.txt", "_ref.sv").replace("_test.sv", "_ref.sv").replace("_top.sv", "_ref.sv"))
            top_src    = p.with_name(p.name.replace("_prompt.txt", "_top.sv").replace("_test.sv", "_top.sv").replace("_ref.sv", "_top.sv"))

            copy_file_to_dir(prompt_src, temp_path, temp_idx)
            copy_file_to_dir(test_src,   temp_path, temp_idx)
            copy_file_to_dir(ref_src,    temp_path, temp_idx)
            copy_file_to_dir(top_src,    temp_path, temp_idx)
            task_set.add(str(p.name.split("_",1)[1]).replace("_test.sv", "").replace("_ref.sv", "").replace("_ref.sv", "").replace("_top.sv", ""))
            continue
        print("generate ",taskname)
        idx = max_prob_index(folder_path)+1
        dut = create_refmodule(folder_path, idx, task_case['ref'], task)
        create_testbench(folder_path, idx, task_case['test'].replace(task_case['ref'], ""), task)
        create_spec(folder_path, idx, dut, task, llm_configs)
        
        temp_idx = max_prob_index(temp_path)+1
        p = file_is_exist(folder_path, taskname)

        prompt_src = p.with_name(p.name.replace("_test.sv", "_prompt.txt").replace("_ref.sv", "_prompt.txt").replace("_top.sv", "_prompt.txt"))
        test_src   = p.with_name(p.name.replace("_prompt.txt", "_test.sv").replace("_ref.sv", "_test.sv").replace("_top.sv", "_test.sv"))
        ref_src    = p.with_name(p.name.replace("_prompt.txt", "_ref.sv").replace("_test.sv", "_ref.sv").replace("_top.sv", "_ref.sv"))
        top_src    = p.with_name(p.name.replace("_prompt.txt", "_top.sv").replace("_test.sv", "_top.sv").replace("_ref.sv", "_top.sv"))
        copy_file_to_dir(prompt_src, temp_path, temp_idx)
        copy_file_to_dir(test_src,   temp_path, temp_idx)
        copy_file_to_dir(ref_src,    temp_path, temp_idx)
        copy_file_to_dir(top_src,    temp_path, temp_idx)
        task_set.add(str(p.name.split("_",1)[1]).replace("_test.sv", "").replace("_ref.sv", "").replace("_ref.sv", "").replace("_top.sv", ""))
    return task_set