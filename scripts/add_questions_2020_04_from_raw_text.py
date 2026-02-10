import json
import os
import re


BASE_DIR = os.path.dirname(os.path.dirname(__file__))
RAW_PATH = os.path.join(BASE_DIR, "raw_text.txt")
QUESTIONS_PATH = os.path.join(BASE_DIR, "assets", "json", "questions.json")


def load_raw_text() -> str:
  with open(RAW_PATH, "r", encoding="utf-8") as f:
    return f.read()


def normalize_space(text: str) -> str:
  # 改行をスペースに寄せて、連続スペースを1つに
  text = text.replace("\u3000", " ")
  text = re.sub(r"\s+", " ", text)
  return text.strip()


def parse_questions_from_raw(raw: str):
  """
  raw_text.txt から令和2年4月公表分の50問をパースして Question dict のリストに変換する。
  - 問題文 + 選択肢 + 正答肢のみ抽出
  - 解説全文は summary としてそのまま詰め込む（必要に応じて後で人手で整形）
  """
  # 問題ブロックを切り出し
  block_pattern = r"【\s*問\s*(\d+)\s*】([\s\S]*?)(?=【\s*問\s*\d+\s*】|$)"
  blocks = list(re.finditer(block_pattern, raw))

  questions = []

  for m in blocks:
    q_no = int(m.group(1))
    block = m.group(2)

    # 解説部分の分離
    before_expl, sep, expl_plus = block.partition("▶▶解説◀◀")

    # 正答肢の取得
    ans_match = re.search(r"＊解答＊\s*（([０１２３４５１２３４５0-9]+)）", block)
    if not ans_match:
      # 解答が取れない問題はスキップ
      continue
    raw_num = ans_match.group(1)
    # 全角数字→半角
    trans = str.maketrans("０１２３４５", "012345")
    num_str = raw_num.translate(trans)
    try:
      correct_idx = int(num_str) - 1
    except ValueError:
      continue

    # 問題文 + 選択肢の分離
    opt_start = re.search(r"（１）", before_expl)
    if not opt_start:
      continue

    q_text_raw = before_expl[: opt_start.start()]
    opts_block = before_expl[opt_start.start():]

    q_text = normalize_space(q_text_raw)

    # 選択肢抽出
    opt_pattern = r"（([１-５])）(.*?)(?=（[１-５]）|$)"
    opts = []
    for om in re.finditer(opt_pattern, opts_block, flags=re.DOTALL):
      opt_text = normalize_space(om.group(2))
      if opt_text:
        opts.append(opt_text)

    if len(opts) < 2:
      # 選択肢が取れていない
      continue

    # 解説 summary
    summary = ""
    if sep:
      # 解説ヘッダ以降〜解答の手前まで
      expl_body, _, _ = expl_plus.partition("＊解答＊")
      summary = normalize_space(expl_body)[:500]  # 長すぎる場合は軽く切る

    # カテゴリ判定（問題番号レンジから）
    if 1 <= q_no <= 10:
      category = "関係法令（有害業務）"
      is_hazardous = True
    elif 11 <= q_no <= 20:
      category = "労働衛生（有害業務）"
      is_hazardous = True
    elif 21 <= q_no <= 30:
      category = "関係法令"
      is_hazardous = False
    elif 31 <= q_no <= 40:
      category = "労働衛生"
      is_hazardous = False
    else:
      category = "労働生理"
      is_hazardous = False

    questions.append(
      {
        "year": "2020_04",
        "category": category,
        "question_text": q_text,
        "options": opts,
        "correct_index": correct_idx,
        "explanation_summary": summary
        or "令和2年4月公表問題の公式解説を簡略化した要約です。",
        "mnemonic": "",
        "is_hazardous": is_hazardous,
        # is_premium や id は後で付与
      }
    )

  return questions


def main():
  if not os.path.exists(RAW_PATH):
    print(f"raw_text.txt が見つかりません: {RAW_PATH}")
    return
  if not os.path.exists(QUESTIONS_PATH):
    print(f"questions.json が見つかりません: {QUESTIONS_PATH}")
    return

  raw = load_raw_text()
  new_questions = parse_questions_from_raw(raw)
  print(f"Parsed {len(new_questions)} questions from raw_text.txt")

  with open(QUESTIONS_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

  # 既存IDの最大値を確認
  max_id = max(q.get("id", 0) for q in data) if data else 0

  # IDと is_premium を付与して追加
  next_id = max_id + 1
  for q in new_questions:
    q["id"] = next_id
    # 2020_04は最新2年ではないため、プレミアム扱い（ロック）でよい
    q["is_premium"] = True
    data.append(q)
    next_id += 1

  with open(QUESTIONS_PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

  print(f"Appended {len(new_questions)} questions to questions.json (now {len(data)} total).")


if __name__ == "__main__":
  main()

