import polib
import re
import time
import sys
import os
import subprocess
import argparse
from pathlib import Path
from googletrans import Translator

LOCALE_DIR = "locale"
LANGUAGE = "it"
PO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/django.po"
MO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/django.mo"
JS_PO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/djangojs.po"
JS_MO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/djangojs.mo"

PLACEHOLDER_RE = re.compile(r'%\([^)]+\)[a-zA-Z]|%[sdfr]|{\w+}|\$\{[^}]+\}|{{\s*\w+\s*}}')

def extract_placeholders(text: str) -> list[str]:
    return PLACEHOLDER_RE.findall(text or "")

class TranslationManager:
    def __init__(self, force_retranslate=False, verbose=False):
        self.translator = Translator()
        self.force_retranslate = force_retranslate
        self.verbose = verbose
        self.stats = {
            'translated': 0, 
            'repaired': 0, 
            'skipped': 0, 
            'verified': 0, 
            'failed': 0,
            'already_translated': 0
        }
    
    def safe_translate(self, text: str, src="en", dest="it", retries=3):
        text = text.strip()
        
        if len(text) <= 2:
            return None
        
        placeholders = extract_placeholders(text)
        temp = text
        
        for i, ph in enumerate(placeholders):
            temp = temp.replace(ph, f"__PLACEHOLDER_{i}__", 1)
        
        for attempt in range(retries):
            try:
                result = self.translator.translate(temp, src=src, dest=dest)
                time.sleep(0.2)
                
                if not result or not getattr(result, "text", None):
                    if attempt < retries - 1:
                        time.sleep(1)
                        continue
                    return None
                
                translated = result.text
                
                for i, ph in enumerate(placeholders):
                    translated = re.sub(
                        f"__PLACEHOLDER_{i}__", 
                        ph, 
                        translated, 
                        count=1,
                        flags=re.IGNORECASE
                    )
                
                return translated
                
            except Exception as e:
                if attempt < retries - 1:
                    time.sleep(2 ** attempt)
                else:
                    return None
        
        return None

    def repair_placeholders(self, entry) -> bool:
        msgid_ph = extract_placeholders(entry.msgid)
        msgstr_ph = extract_placeholders(entry.msgstr)
        
        if set(msgid_ph) != set(msgstr_ph):
            new_msgstr = entry.msgstr
            
            for i, correct in enumerate(msgid_ph):
                if i < len(msgstr_ph):
                    new_msgstr = new_msgstr.replace(msgstr_ph[i], correct, 1)
            
            missing = [ph for ph in msgid_ph if ph not in extract_placeholders(new_msgstr)]
            if missing:
                new_msgstr = new_msgstr.rstrip() + " " + " ".join(missing)
            
            entry.msgstr = new_msgstr
            self.stats['repaired'] += 1
            return True
        
        return False

    def translate_entry(self, entry) -> bool:
        if entry.msgstr and entry.msgstr.strip() and not self.force_retranslate:
            self.stats['already_translated'] += 1
            return False
        
        if 'fuzzy' in entry.flags:
            entry.flags.remove('fuzzy')
        
        translated = self.safe_translate(entry.msgid)
        
        if not translated:
            self.stats['skipped'] += 1
            return False
        
        msgid_ph = extract_placeholders(entry.msgid)
        trans_ph = extract_placeholders(translated)
        
        if set(msgid_ph) != set(trans_ph):
            self.stats['failed'] += 1
            return False
        
        entry.msgstr = translated
        self.stats['translated'] += 1
        return True

    def process_po_file(self, po_path: str):
        if not os.path.exists(po_path):
            return None
        
        po = polib.pofile(po_path)
        
        total_entries = 0
        for entry in po:
            if not entry.msgid or not entry.msgid.strip():
                continue
            
            total_entries += 1
            
            if entry.msgstr and entry.msgstr.strip():
                if self.repair_placeholders(entry):
                    continue
                self.stats['verified'] += 1
                if not self.force_retranslate:
                    continue
            
            self.translate_entry(entry)
        
        return po

def extract_strings(verbose=False):
    try:
        result = subprocess.run(
            [sys.executable, "manage.py", "makemessages", "-l", LANGUAGE, "--no-obsolete", "--ignore=env/*", "--ignore=venv/*"],
            check=True,
            capture_output=True,
            text=True
        )

        if os.path.exists("static") or any(Path(".").glob("*/static")):
            result = subprocess.run(
                [sys.executable, "manage.py", "makemessages", "-d", "djangojs", "-l", LANGUAGE, "--no-obsolete", "--ignore=env/*", "--ignore=venv/*"],
                check=False,
                capture_output=True,
                text=True
            )
        return True
        
    except subprocess.CalledProcessError as e:
        if e.stderr:
            print(e.stderr)
        return False
    except FileNotFoundError:
        return False

def check_status(verbose=False):
    if not os.path.exists(PO_FILE):
        return None
    
    po = polib.pofile(PO_FILE)
    untranslated, fuzzy, translated = [], [], []
    
    for entry in po:
        if not entry.msgid or not entry.msgid.strip():
            continue
        
        if 'fuzzy' in entry.flags:
            fuzzy.append(entry)
        elif not entry.msgstr or entry.msgstr.strip() == "":
            untranslated.append(entry)
        else:
            translated.append(entry)
    
    total = len(translated) + len(fuzzy) + len(untranslated)
    coverage = (len(translated) / total * 100) if total > 0 else 0
    
    status = {
        'total': total,
        'translated': len(translated),
        'untranslated': len(untranslated),
        'fuzzy': len(fuzzy),
        'coverage': coverage
    }
    
    return status

def translate_missing(force=False, verbose=False):
    manager = TranslationManager(force_retranslate=force, verbose=verbose)
    
    po = manager.process_po_file(PO_FILE)
    if po:
        po.save()
    
    if os.path.exists(JS_PO_FILE):
        js_po = manager.process_po_file(JS_PO_FILE)
        if js_po:
            js_po.save()
    
    return manager.stats

def compile_messages(verbose=False):
    try:
        result = subprocess.run(
            [sys.executable, "manage.py", "compilemessages"],
            check=True,
            capture_output=True,
            text=True
        )
        return True
        
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        try:
            compiled_any = False
            
            if os.path.exists(PO_FILE):
                po = polib.pofile(PO_FILE)
                po.save_as_mofile(MO_FILE)
                compiled_any = True
            
            if os.path.exists(JS_PO_FILE):
                js_po = polib.pofile(JS_PO_FILE)
                js_po.save_as_mofile(JS_MO_FILE)
                compiled_any = True
            
            if compiled_any:
                return True
            else:
                return False
                
        except Exception as e:
            return False

def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    
    parser.add_argument('--check', action='store_true', help='Check translation status')
    parser.add_argument('--translate', action='store_true', help='Translate missing strings')
    parser.add_argument('--force', action='store_true', help='Force re-translate all strings')
    parser.add_argument('--compile', action='store_true', help='Compile PO files to MO files')
    parser.add_argument('--full', action='store_true', help='Run complete workflow')
    parser.add_argument('--extract', action='store_true', help='Extract translatable strings')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    
    args = parser.parse_args()
    
    if not any([args.full, args.extract, args.check, args.translate, args.force, args.compile]):
        parser.print_help()
        return
    
    os.makedirs(os.path.dirname(PO_FILE), exist_ok=True)
    
    if args.full:
        extract_strings(verbose=args.verbose)
        check_status(verbose=args.verbose)
        translate_missing(force=False, verbose=args.verbose)
        compile_messages(verbose=args.verbose)
        
    elif args.extract:
        extract_strings(verbose=args.verbose)
        
    elif args.check:
        check_status(verbose=args.verbose)
        
    elif args.translate:
        translate_missing(force=False, verbose=args.verbose)
        compile_messages(verbose=args.verbose)
        
    elif args.force:
        translate_missing(force=True, verbose=args.verbose)
        compile_messages(verbose=args.verbose)
        
    elif args.compile:
        compile_messages(verbose=args.verbose)

if __name__ == "__main__":
    main()