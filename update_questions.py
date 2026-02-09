import json

file_path = '/Users/appleuser/Library/CloudStorage/Box-Box/アプリ開発/eisei_kanrisha_app/assets/json/questions.json'

with open(file_path, 'r', encoding='utf-8') as f:
    questions = json.load(f)

updated_questions = []
for q in questions:
    year = q.get('year', '')
    # Strict Premium Logic (User Request: "Too few locked questions")
    # Free: 2023 (approx 87 questions)
    # Locked: 2025, 2024 (Newest) AND 2022, 2021, 2020... (Oldest)
    
    is_premium = True # Default to locked
    
    if year.startswith('2023'):
        is_premium = False
    
    # All others (2025, 2024, 2022, 2021, 2020...) are True by default
    
    q['is_premium'] = is_premium
    updated_questions.append(q)

with open(file_path, 'w', encoding='utf-8') as f:
    json.dump(updated_questions, f, indent=2, ensure_ascii=False)

print(f"Updated {len(updated_questions)} questions.")
