"""平成30年4月を raw_text_2018_04.txt から取り込み"""
import json
import os
import re

BASE = os.path.dirname(os.path.dirname(__file__))
RAW = os.path.join(BASE, "raw_text_2018_04.txt")
QUESTIONS = os.path.join(BASE, "assets", "json", "questions.json")

def norm(s):
    s = s.replace("\u3000", " ").strip()
    return re.sub(r"\s+", " ", s)

def parse(raw):
    blocks = list(re.finditer(r"【\s*問\s*(\d+)\s*】([\s\S]*?)(?=【\s*問\s*\d+\s*】|$)", raw))
    out = []
    for m in blocks:
        q_no = int(m.group(1))
        block = m.group(2)
        before_expl, sep, expl_plus = block.partition("▶▶解説◀◀")
        ans = re.search(r"＊解答＊\s*（([０１２３４５0-9]+)）", block)
        if not ans:
            continue
        trans = str.maketrans("０１２３４５", "012345")
        try:
            correct_idx = int(ans.group(1).translate(trans)) - 1
        except ValueError:
            continue
        opt_start = re.search(r"（１）", before_expl)
        if not opt_start:
            continue
        q_text = norm(before_expl[:opt_start.start()])
        opts_block = before_expl[opt_start.start():]
        opts = []
        for om in re.finditer(r"（([１-５])）(.*?)(?=（[１-５]）|$)", opts_block, re.DOTALL):
            t = norm(om.group(2))
            if t:
                opts.append(t)
        if len(opts) < 2:
            continue
        summary = ""
        if sep:
            expl_body, _, _ = expl_plus.partition("＊解答＊")
            summary = norm(expl_body)[:500]
        if 1 <= q_no <= 10:
            cat, haz = "関係法令（有害業務）", True
        elif 11 <= q_no <= 20:
            cat, haz = "労働衛生（有害業務）", True
        elif 21 <= q_no <= 30:
            cat, haz = "関係法令（有害業務以外）", False
        elif 31 <= q_no <= 40:
            cat, haz = "労働衛生（有害業務以外）", False
        else:
            cat, haz = "労働生理", False
        out.append({
            "year": "2018_04",
            "category": cat,
            "question_text": q_text,
            "options": opts,
            "correct_index": correct_idx,
            "explanation_summary": summary or "平成30年4月公表問題の公式解説を簡略化した要約です。",
            "mnemonic": "",
            "is_hazardous": haz,
        })
    return out

def main():
    if not os.path.exists(RAW):
        print(f"{RAW} がありません。先に python scripts/extract_2018_04.py を実行してください。")
        return
    with open(RAW, "r", encoding="utf-8") as f:
        raw = f.read()
    qs = parse(raw)
    print(f"Parsed {len(qs)} questions")
    with open(QUESTIONS, "r", encoding="utf-8") as f:
        data = json.load(f)
    max_id = max(q.get("id", 0) for q in data) if data else 0
    for i, q in enumerate(qs):
        q["id"] = max_id + i + 1
        q["is_premium"] = True
        data.append(q)
    with open(QUESTIONS, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"Appended {len(qs)} questions. Total: {len(data)}")

if __name__ == "__main__":
    main()
