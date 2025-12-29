import polib
import re
import time
import sys
import os
import subprocess
import argparse
from pathlib import Path

try:
    from googletrans import Translator
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "googletrans==4.0.0-rc1"])
    from googletrans import Translator

LOCALE_DIR = "locale"
LANGUAGE = "it"
PO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/django.po"
MO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/django.mo"
JS_PO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/djangojs.po"
JS_MO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/djangojs.mo"

PLACEHOLDER_RE = re.compile(r"%\([^)]+\)[a-zA-Z]|%[sdfr]|{[^}]+}|\$\{[^}]+\}")

def extract_placeholders(text: str) -> list[str]:
    return PLACEHOLDER_RE.findall(text or "")

class TranslationManager:
    def __init__(self, force_retranslate=False):
        self.translator = Translator()
        self.force_retranslate = force_retranslate
        self.stats = {'translated': 0, 'repaired': 0, 'skipped': 0, 'verified': 0, 'failed': 0}
    
    def safe_translate(self, text: str, src="en", dest="it") -> str | None:
        text = text.strip()
        if len(text) <= 2:
            return None
        placeholders = extract_placeholders(text)
        temp = text
        for i, ph in enumerate(placeholders):
            temp = temp.replace(ph, f"__PH_{i}__", 1)
        try:
            result = self.translator.translate(temp, src=src, dest=dest)
            time.sleep(0.15)
        except Exception:
            return None
        if not result or not getattr(result, "text", None):
            return None
        translated = result.text
        for i, ph in enumerate(placeholders):
            translated = translated.replace(f"__PH_{i}__", ph, 1)
        return translated

    def repair_placeholders(self, entry) -> bool:
        msgid_ph = extract_placeholders(entry.msgid)
        msgstr_ph = extract_placeholders(entry.msgstr)
        if msgid_ph != msgstr_ph:
            new_msgstr = entry.msgstr
            for wrong, correct in zip(msgstr_ph, msgid_ph):
                new_msgstr = new_msgstr.replace(wrong, correct)
            missing = set(msgid_ph) - set(msgstr_ph)
            if missing:
                new_msgstr = new_msgstr.rstrip() + " " + " ".join(sorted(missing))
            entry.msgstr = new_msgstr
            self.stats['repaired'] += 1
            return True
        return False

    def translate_entry(self, entry) -> bool:
        if entry.msgstr and not self.force_retranslate:
            self.stats['verified'] += 1
            return False
        translated = self.safe_translate(entry.msgid)
        if not translated:
            self.stats['skipped'] += 1
            return False
        msgid_ph = extract_placeholders(entry.msgid)
        if extract_placeholders(translated) != msgid_ph:
            self.stats['failed'] += 1
            return False
        entry.msgstr = translated
        self.stats['translated'] += 1
        return True

    def process_po_file(self, po_path: str):
        if not os.path.exists(po_path):
            return None
        po = polib.pofile(po_path)
        for entry in po:
            if not entry.msgid:
                continue
            if self.repair_placeholders(entry):
                continue
            self.translate_entry(entry)
        return po

def extract_strings():
    try:
        subprocess.run([sys.executable, "manage.py", "makemessages", "-l", LANGUAGE, "--no-obsolete"], check=True)
        if os.path.exists("static") or os.path.exists("*/static"):
            subprocess.run([sys.executable, "manage.py", "makemessages", "-d", "djangojs", "-l", LANGUAGE, "--no-obsolete"], check=False)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def check_status():
    if not os.path.exists(PO_FILE):
        return None
    po = polib.pofile(PO_FILE)
    untranslated, fuzzy, translated = [], [], []
    for entry in po:
        if not entry.msgid:
            continue
        if 'fuzzy' in entry.flags:
            fuzzy.append(entry)
        elif not entry.msgstr or entry.msgstr.strip() == "":
            untranslated.append(entry)
        else:
            translated.append(entry)
    total = len(translated) + len(fuzzy) + len(untranslated)
    coverage = (len(translated) / total * 100) if total > 0 else 0
    return {'total': total, 'translated': len(translated), 'untranslated': len(untranslated), 'fuzzy': len(fuzzy), 'coverage': coverage}

def translate_missing(force=False):
    manager = TranslationManager(force_retranslate=force)
    po = manager.process_po_file(PO_FILE)
    if po:
        po.save()
    if os.path.exists(JS_PO_FILE):
        js_po = manager.process_po_file(JS_PO_FILE)
        if js_po:
            js_po.save()
    return manager.stats

def compile_messages():
    try:
        subprocess.run([sys.executable, "manage.py", "compilemessages"], check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        try:
            if os.path.exists(PO_FILE):
                po = polib.pofile(PO_FILE)
                po.save_as_mofile(MO_FILE)
            if os.path.exists(JS_PO_FILE):
                js_po = polib.pofile(JS_PO_FILE)
                js_po.save_as_mofile(JS_MO_FILE)
            return True
        except Exception:
            return False

def main():
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--translate', action='store_true')
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--compile', action='store_true')
    parser.add_argument('--full', action='store_true')
    parser.add_argument('--extract', action='store_true')
    args = parser.parse_args()

    if args.full:
        extract_strings()
        check_status()
        translate_missing(force=False)
        compile_messages()
    elif args.extract:
        extract_strings()
    elif args.check:
        check_status()
    elif args.translate:
        translate_missing(force=False)
        compile_messages()
    elif args.force:
        tra
