"""令和元年10月・平成31年4月・平成30年10月を raw_text_*.txt から取り込み"""
import json
import os
import re

BASE = os.path.dirname(os.path.dirname(__file__))
QUESTIONS = os.path.join(BASE, "assets", "json", "questions.json")

CONFIGS = [
    ("raw_text_2019_10.txt", "2019_2"),   # 令和元年10月
    ("raw_text_2019_04.txt", "2019_1"),   # 平成31年4月
    ("raw_text_2018_10.txt", "2018_2"),   # 平成30年10月
]

FULL_TO_HALF = str.maketrans("０１２３４５６７８９", "0123456789")


def norm(s):
    s = s.replace("\u3000", " ").strip()
    return re.sub(r"\s+", " ", s)


def parse(raw, year):
    raw = raw.translate(FULL_TO_HALF)  # 全角数字→半角で正規表現にマッチさせる
    blocks = list(re.finditer(r"【\s*問\s*(\d+)\s*】([\s\S]*?)(?=【\s*問\s*\d+\s*】|$)", raw))
    out = []
    for m in blocks:
        q_no = int(m.group(1))
        block = m.group(2)
        before_expl, sep, expl_plus = block.partition("▶▶解説◀◀")
        ans = re.search(r"＊解答＊\s*[（(]([０１２３４５0-9]+)[）)]", block)
        if not ans:
            continue
        trans = str.maketrans("０１２３４５", "012345")
        try:
            correct_idx = int(ans.group(1).translate(trans)) - 1
        except ValueError:
            continue
        opt_start = re.search(r"[（(][１1][）)]", before_expl)
        if not opt_start:
            continue
        q_text = norm(before_expl[: opt_start.start()])
        opts_block = before_expl[opt_start.start() :]
        opts = []
        for om in re.finditer(r"[（(]([１-５1-5])[）)](.*?)(?=[（(][１-５1-5][）)]|$)", opts_block, re.DOTALL):
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
        label = {"2019_2": "令和元年10月", "2019_1": "平成31年4月", "2018_2": "平成30年10月"}.get(year, year)
        out.append({
            "year": year,
            "category": cat,
            "question_text": q_text,
            "options": opts,
            "correct_index": correct_idx,
            "explanation_summary": summary or f"{label}公表問題の公式解説を簡略化した要約です。",
            "mnemonic": "",
            "is_hazardous": haz,
        })
    return out


def main():
    if not os.path.exists(QUESTIONS):
        print(f"{QUESTIONS} がありません。")
        return
    with open(QUESTIONS, "r", encoding="utf-8") as f:
        data = json.load(f)
    max_id = max(q.get("id", 0) for q in data) if data else 0
    total_added = 0
    for raw_file, year in CONFIGS:
        path = os.path.join(BASE, raw_file)
        if not os.path.exists(path):
            print(f"スキップ: {path} がありません")
            continue
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read()
        qs = parse(raw, year)
        print(f"{raw_file} → {year}: {len(qs)} 問")
        for i, q in enumerate(qs):
            q["id"] = max_id + 1
            q["is_premium"] = True
            data.append(q)
            max_id += 1
            total_added += 1
    with open(QUESTIONS, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"合計 {total_added} 問を追加。総数: {len(data)}")


if __name__ == "__main__":
    main()
