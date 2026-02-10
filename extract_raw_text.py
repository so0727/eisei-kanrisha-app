
import pypdf
import os

pdf_path = "./過去問/衛生管理者試験　過去問の解答と解説　令和2年4月.pdf"
output_path = "raw_text.txt"

def extract_text(pdf_path, output_path):
    try:
        reader = pypdf.PdfReader(pdf_path)
        with open(output_path, "w", encoding="utf-8") as f:
            for i, page in enumerate(reader.pages):
                text = page.extract_text()
                f.write(f"--- Page {i+1} ---\n")
                f.write(text)
                f.write("\n\n")
        print(f"Successfully extracted text to {output_path}")
    except Exception as e:
        print(f"Error extracting text: {e}")

if __name__ == "__main__":
    if os.path.exists(pdf_path):
        extract_text(pdf_path, output_path)
    else:
        print(f"File not found: {pdf_path}")
