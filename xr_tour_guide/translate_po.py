#!/usr/bin/env python3
"""
translate_po.py - All-in-One Translation Script for Django
===========================================================

This script handles everything for Django translations:
1. Extract all translatable strings from code
2. Check current translation status
3. Automatically translate missing strings
4. Repair broken placeholders
5. Compile .po to .mo files
6. Generate detailed reports

Usage:
    python translate_po.py --check           # Only check status
    python translate_po.py --translate       # Translate missing strings
    python translate_po.py --force           # Force retranslate everything
    python translate_po.py --compile         # Only compile .mo files
    python translate_po.py --full            # Do everything (recommended)
"""

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
    print("⚠️  googletrans not found. Installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "googletrans==4.0.0-rc1"])
    from googletrans import Translator

# =============================================================================
# CONFIGURATION
# =============================================================================

LOCALE_DIR = "locale"
LANGUAGE = "it"
PO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/django.po"
MO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/django.mo"
JS_PO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/djangojs.po"
JS_MO_FILE = f"{LOCALE_DIR}/{LANGUAGE}/LC_MESSAGES/djangojs.mo"

PLACEHOLDER_RE = re.compile(
    r"%\([^)]+\)[a-zA-Z]|%[sdfr]|{[^}]+}|\$\{[^}]+\}"
)

# =============================================================================
# UTILITIES
# =============================================================================

def colored(text, color):
    """Add color to terminal output"""
    colors = {
        'red': '\033[91m',
        'green': '\033[92m',
        'yellow': '\033[93m',
        'blue': '\033[94m',
        'magenta': '\033[95m',
        'cyan': '\033[96m',
        'white': '\033[97m',
        'reset': '\033[0m'
    }
    return f"{colors.get(color, '')}{text}{colors['reset']}"

def print_header(text):
    """Print a formatted header"""
    print("\n" + "=" * 70)
    print(colored(text, 'cyan'))
    print("=" * 70)

def extract_placeholders(text: str) -> list[str]:
    """Extract all placeholders from text"""
    return PLACEHOLDER_RE.findall(text or "")

# =============================================================================
# TRANSLATION FUNCTIONS
# =============================================================================

class TranslationManager:
    def __init__(self, force_retranslate=False):
        self.translator = Translator()
        self.force_retranslate = force_retranslate
        self.stats = {
            'translated': 0,
            'repaired': 0,
            'skipped': 0,
            'verified': 0,
            'failed': 0
        }
    
    def safe_translate(self, text: str, src="en", dest="it") -> str | None:
        """Safely translate text preserving placeholders"""
        text = text.strip()

        # Skip very short strings
        if len(text) <= 2:
            return None

        placeholders = extract_placeholders(text)
        temp = text

        # Replace placeholders with markers
        for i, ph in enumerate(placeholders):
            temp = temp.replace(ph, f"__PH_{i}__", 1)

        try:
            result = self.translator.translate(temp, src=src, dest=dest)
            time.sleep(0.15)  # Avoid rate limiting
        except Exception as e:
            print(colored(f"   ❌ Translation failed: {text[:40]}... ({e})", 'red'))
            return None

        if not result or not getattr(result, "text", None):
            return None

        translated = result.text

        # Restore placeholders
        for i, ph in enumerate(placeholders):
            translated = translated.replace(f"__PH_{i}__", ph, 1)

        return translated

    def repair_placeholders(self, entry) -> bool:
        """Repair broken placeholders in existing translations"""
        msgid_ph = extract_placeholders(entry.msgid)
        msgstr_ph = extract_placeholders(entry.msgstr)

        if msgid_ph != msgstr_ph:
            new_msgstr = entry.msgstr

            # Replace wrong placeholders
            for wrong, correct in zip(msgstr_ph, msgid_ph):
                new_msgstr = new_msgstr.replace(wrong, correct)

            # Add missing placeholders
            missing = set(msgid_ph) - set(msgstr_ph)
            if missing:
                new_msgstr = new_msgstr.rstrip() + " " + " ".join(sorted(missing))

            entry.msgstr = new_msgstr
            self.stats['repaired'] += 1
            print(colored(f"   🔧 Repaired: {entry.msgid[:50]}", 'yellow'))
            return True
        
        return False

    def translate_entry(self, entry) -> bool:
        """Translate a single entry"""
        # Skip if already translated (unless force mode)
        if entry.msgstr and not self.force_retranslate:
            self.stats['verified'] += 1
            return False

        # Translate
        translated = self.safe_translate(entry.msgid)

        if not translated:
            self.stats['skipped'] += 1
            print(colored(f"   ⏭️  Skipped: {entry.msgid[:50]}", 'yellow'))
            return False

        # Verify placeholders
        msgid_ph = extract_placeholders(entry.msgid)
        if extract_placeholders(translated) != msgid_ph:
            self.stats['failed'] += 1
            print(colored(f"   ⚠️  Placeholder mismatch: {entry.msgid[:40]}", 'red'))
            return False

        entry.msgstr = translated
        self.stats['translated'] += 1
        print(colored(f"   ✅ Translated: {entry.msgid[:50]}", 'green'))
        return True

    def process_po_file(self, po_path: str):
        """Process a .po file"""
        if not os.path.exists(po_path):
            print(colored(f"⚠️  File not found: {po_path}", 'red'))
            return None

        print(f"\n📂 Processing: {po_path}")
        po = polib.pofile(po_path)

        for entry in po:
            if not entry.msgid:
                continue

            # First, try to repair placeholders
            if self.repair_placeholders(entry):
                continue

            # Then translate if needed
            self.translate_entry(entry)

        return po

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

def extract_strings():
    """Extract all translatable strings from code"""
    print_header("📝 STEP 1: EXTRACTING STRINGS FROM CODE")
    
    try:
        # Extract from Python/templates
        print("Extracting from Python and templates...")
        subprocess.run([
            sys.executable, "manage.py", "makemessages",
            "-l", LANGUAGE, "--no-obsolete"
        ], check=True)
        print(colored("✅ Successfully extracted strings", 'green'))
        
        # Extract from JavaScript (if exists)
        if os.path.exists("static") or os.path.exists("*/static"):
            print("\nExtracting from JavaScript...")
            subprocess.run([
                sys.executable, "manage.py", "makemessages",
                "-d", "djangojs", "-l", LANGUAGE, "--no-obsolete"
            ], check=False)  # Don't fail if no JS strings
        
        return True
    except subprocess.CalledProcessError as e:
        print(colored(f"❌ Extraction failed: {e}", 'red'))
        return False
    except FileNotFoundError:
        print(colored("❌ manage.py not found. Are you in the Django project root?", 'red'))
        return False

def check_status():
    """Check current translation status"""
    print_header("📊 STEP 2: CHECKING TRANSLATION STATUS")
    
    if not os.path.exists(PO_FILE):
        print(colored(f"❌ {PO_FILE} not found. Run extraction first.", 'red'))
        return None

    po = polib.pofile(PO_FILE)
    
    untranslated = []
    fuzzy = []
    translated = []

    for entry in po:
        if not entry.msgid:
            continue
        
        if 'fuzzy' in entry.flags:
            fuzzy.append(entry)
        elif not entry.msgstr or entry.msgstr.strip() == "":
            untranslated.append(entry)
        else:
            translated.append(entry)

    # Print statistics
    total = len(translated) + len(fuzzy) + len(untranslated)
    coverage = (len(translated) / total * 100) if total > 0 else 0

    print(f"\n{colored('✅ Translated:', 'green')}     {len(translated)} entries")
    print(f"{colored('⚠️  Fuzzy:', 'yellow')}          {len(fuzzy)} entries")
    print(f"{colored('❌ Untranslated:', 'red')}   {len(untranslated)} entries")
    print(f"{colored('📝 Total:', 'white')}          {total} entries")
    print(f"\n{colored('📈 Coverage:', 'cyan')}       {coverage:.1f}%")

    # Show some untranslated strings
    if untranslated:
        print(f"\n{colored('First 10 untranslated strings:', 'yellow')}")
        for i, entry in enumerate(untranslated[:10], 1):
            print(f"   {i}. \"{entry.msgid[:60]}...\"" if len(entry.msgid) > 60 else f"   {i}. \"{entry.msgid}\"")

    # Show fuzzy strings
    if fuzzy:
        print(f"\n{colored('Fuzzy strings (need review):', 'yellow')}")
        for i, entry in enumerate(fuzzy[:5], 1):
            print(f"   {i}. \"{entry.msgid[:60]}...\"" if len(entry.msgid) > 60 else f"   {i}. \"{entry.msgid}\"")

    return {
        'total': total,
        'translated': len(translated),
        'untranslated': len(untranslated),
        'fuzzy': len(fuzzy),
        'coverage': coverage
    }

def translate_missing(force=False):
    """Translate missing strings"""
    print_header("🌐 STEP 3: TRANSLATING STRINGS")
    
    if force:
        print(colored("⚠️  FORCE MODE: Retranslating ALL strings", 'yellow'))
    
    manager = TranslationManager(force_retranslate=force)
    
    # Process main .po file
    po = manager.process_po_file(PO_FILE)
    if po:
        po.save()
        print(colored(f"\n✅ Saved: {PO_FILE}", 'green'))
    
    # Process JS .po file if exists
    if os.path.exists(JS_PO_FILE):
        js_po = manager.process_po_file(JS_PO_FILE)
        if js_po:
            js_po.save()
            print(colored(f"✅ Saved: {JS_PO_FILE}", 'green'))
    
    # Print statistics
    print("\n" + "=" * 70)
    print(colored("📊 TRANSLATION SUMMARY", 'cyan'))
    print("=" * 70)
    print(f"   ✅ Translated:     {manager.stats['translated']}")
    print(f"   🔧 Repaired:       {manager.stats['repaired']}")
    print(f"   ✓  Verified:       {manager.stats['verified']}")
    print(f"   ⏭️  Skipped:        {manager.stats['skipped']}")
    print(f"   ❌ Failed:         {manager.stats['failed']}")
    print("=" * 70)

def compile_messages():
    """Compile .po files to .mo files"""
    print_header("📦 STEP 4: COMPILING MESSAGE FILES")
    
    try:
        # Try using Django's command
        subprocess.run([
            sys.executable, "manage.py", "compilemessages"
        ], check=True)
        print(colored("✅ Successfully compiled messages using Django", 'green'))
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Fallback to polib
        print("Falling back to polib compilation...")
        try:
            if os.path.exists(PO_FILE):
                po = polib.pofile(PO_FILE)
                po.save_as_mofile(MO_FILE)
                print(colored(f"✅ Compiled: {MO_FILE}", 'green'))
            
            if os.path.exists(JS_PO_FILE):
                js_po = polib.pofile(JS_PO_FILE)
                js_po.save_as_mofile(JS_MO_FILE)
                print(colored(f"✅ Compiled: {JS_MO_FILE}", 'green'))
        except Exception as e:
            print(colored(f"❌ Compilation failed: {e}", 'red'))
            return False
    
    return True

def print_final_report():
    """Print final report and next steps"""
    print_header("✅ ALL DONE!")
    
    status = check_status()
    
    if status and status['coverage'] >= 95:
        print(colored("\n🎉 Excellent! Translation coverage is great!", 'green'))
    elif status and status['coverage'] >= 80:
        print(colored("\n✓ Good! Most strings are translated.", 'green'))
    else:
        print(colored("\n⚠️  Some strings are still missing translations.", 'yellow'))
    
    print("\n" + colored("📋 NEXT STEPS:", 'cyan'))
    print("   1. Restart your Django server: python manage.py runserver")
    print("   2. Clear browser cache (Ctrl+Shift+R)")
    print("   3. Check the website in Italian")
    
    if status and status['untranslated'] > 0:
        print(f"\n{colored('💡 TIP:', 'yellow')} Run with --force to retranslate all strings")
    
    print("\n" + colored("🐛 IF SOMETHING IS NOT TRANSLATED:", 'yellow'))
    print("   1. Make sure the text has {% trans %} tag in template")
    print("   2. Run: python translate_po.py --full")
    print("   3. Restart Django server")

# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="All-in-one Django translation script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python translate_po.py --full          # Do everything (recommended)
  python translate_po.py --check         # Only check status
  python translate_po.py --translate     # Only translate missing
  python translate_po.py --force         # Force retranslate everything
        """
    )
    
    parser.add_argument('--check', action='store_true', 
                       help='Only check translation status')
    parser.add_argument('--translate', action='store_true',
                       help='Translate missing strings')
    parser.add_argument('--force', action='store_true',
                       help='Force retranslate all strings')
    parser.add_argument('--compile', action='store_true',
                       help='Only compile .po to .mo files')
    parser.add_argument('--full', action='store_true',
                       help='Do everything: extract, translate, compile')
    parser.add_argument('--extract', action='store_true',
                       help='Only extract strings from code')
    
    args = parser.parse_args()
    
    # If no arguments, show help
    if not any(vars(args).values()):
        parser.print_help()
        print("\n" + colored("💡 TIP: Use --full for a complete workflow", 'cyan'))
        return
    
    # Execute based on arguments
    if args.full:
        print_header("🚀 FULL TRANSLATION WORKFLOW")
        extract_strings()
        check_status()
        translate_missing(force=False)
        compile_messages()
        print_final_report()
    
    elif args.extract:
        extract_strings()
    
    elif args.check:
        check_status()
    
    elif args.translate:
        translate_missing(force=False)
        compile_messages()
    
    elif args.force:
        print(colored("\n⚠️  WARNING: This will retranslate ALL strings!", 'yellow'))
        response = input("Are you sure? (yes/no): ")
        if response.lower() == 'yes':
            translate_missing(force=True)
            compile_messages()
        else:
            print("Cancelled.")
    
    elif args.compile:
        compile_messages()

if __name__ == "__main__":
    main()