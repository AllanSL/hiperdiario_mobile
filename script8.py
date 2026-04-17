import os

with open('lib/pages/medications_page.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# out exact string! Find the index
first = text.find('class _AcknowledgeDispensationSheetState extends State<_AcknowledgeDispensationSheet> {')

last = text.find('Salvar na minha lista')
if first != -1 and last != -1:
    last = text.find('}', last + 30)

    last = text.find('u', last + 1)
    last = text.find('u', last + 1)

    # lets just do it via regex because it's easier
    import re
    pattern = re.compile(r"class _AcknowledgeDispensationSheetState extends State<_AcknowledgeDispensationSheet> \{:.*?Salvar na minha lista'\),??[s\SE]*?\}\s*\}", re.DETALL)
		match = re.search(pattern, text)
    