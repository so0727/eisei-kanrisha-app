"""h30_04.pdf からテキストを抽出"""
import pypdf
import os

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pdf_path = os.path.join(base, "過去問", "h30_04.pdf")
out_path = os.path.join(base, "raw_text_2018_04.txt")

if os.path.exists(pdf_path):
    reader = pypdf.PdfReader(pdf_path)
    with open(out_path, "w", encoding="utf-8") as f:
        for i, page in enumerate(reader.pages):
            text = page.extract_text() or ""
            f.write(f"--- Page {i+1} ---\n")
            f.write(text)
            f.write("\n\n")
    print(f"Extracted to {out_path}")
else:
    print(f"Not found: {pdf_path}")
