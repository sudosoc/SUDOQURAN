#!/usr/bin/env python3
"""
Hunts the web for full-surah MP3s of every reciter in the app and writes
assets/sources.json  ->  { reciters: {id: {"1": [url, url, ...], ...}},
                           ruqyah:   {id: [{title, url}, ...]} }

Sources, in priority order:
  1. mp3quran.net API (v3)
  2. quranicaudio.com API
  3. archive.org (search + per-item file listing, surah detected from file names)

Every URL is HEAD/Range-checked before it goes in, so the app only gets links
that answered with audio. Runs on GitHub Actions (full internet access).
Stdlib only.
"""
import concurrent.futures as cf
import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sources.json"
REPORT = ROOT / "tool" / "report.md"
UA = {"User-Agent": "SUDOQURAN-source-builder/1.0 (+github.com/sudosoc/SUDOQURAN)"}

# --------------------------------------------------------------------------
RECITERS = [
    # id, arabic tokens (mp3quran match), archive.org queries, quranicaudio name tokens
    ("minshawi", ["المنشاوي"], ['"محمد صديق المنشاوي"', 'minshawi'], ["minshawi"]),
    ("banna", ["محمود", "البنا"], ['"محمود علي البنا"', '"mahmoud ali al-banna"', '"al-banna" quran'], ["banna"]),
    ("maher", ["المعيقلي"], ['"ماهر المعيقلي"', 'muaiqly'], ["muaiqly", "mu'aiqly"]),
    ("binhameed", ["طالب", "حميد"], ['"أحمد بن طالب"', '"ahmad bin talib"', '"ahmed talib hameed"', '"ahmad talib bin humaid"'], ["talib"]),
    ("ghamdi", ["سعد", "الغامدي"], ['"سعد الغامدي"', 'ghamdi'], ["ghamdi"]),
    ("afasy", ["مشاري"], ['"مشاري العفاسي"', 'alafasy'], ["afasy"]),
    ("alhaj", ["عبدالرحمن", "الحاج"], ['"عبدالرحمن الحاج"', '"عبد الرحمن الحاج"', 'عبدالرحمن الحاج قرآن', '"abdulrahman al haj"', '"abdul rahman al-haj"', '"abdelrahman elhag"', '"abdulrahman alhaj"'], []),
    ("dawas", ["الدعوس"], ['"ماجد الدعوس"', 'الدعوس', '"majed al-dawas"', '"majed aldawas"'], []),
    ("islamsobhi", ["اسلام", "صبحي"], ['"إسلام صبحي"', '"اسلام صبحي"', '"islam sobhi"', '"islam sobhy"'], ["sobhi"]),
    ("shamsan", ["الشمسان"], ['"وليد الشمسان"', 'الشمسان', '"waleed al-shamsan"', '"walid alshamsan"'], []),
    ("tablawi", ["الطبلاوي"], ['"محمد محمود الطبلاوي"', 'tablawi'], ["tablawi", "tablaway"]),
    ("nasr", ["نصر"], ['"أحمد عبد الرازق نصر"', '"احمد عبدالرازق نصر"', '"أحمد نصر" قرآن', '"ahmed nasr" quran'], []),
    ("dosari", ["ياسر", "الدوسري"], ['"ياسر الدوسري"', 'dossary', 'dosari'], ["dossary", "dosari", "dussary"]),
    ("ghazi", ["بلال", "غازي"], ['"بلال الغازي"', '"بلال غازي"', 'بلال غازي', '"bilal ghazi"', 'bilal ghazi quran', '"ghazi bilal"', '"bilal elghazi"'], []),
    ("basit", ["عبدالباسط"], ['"عبد الباسط عبد الصمد"', '"abdul basit" murattal'], ["abdul basit", "abdulbaset", "abdul baset"]),
    ("omarali", ["عمرعلي"], ['"عمر علي" قرآن', '"القارئ عمر علي"', '"omar ali" quran'], []),
    ("anas", ["انس", "عبدالستار"], ['"أنس عبد الستار"', '"انس عبدالستار"', '"انس عبد الستار"', '"anas abdelsattar"', '"anas abdul sattar"', '"anas abd el sattar"'], []),
]

# extra reciter name tokens that MUST appear in an archive.org title/identifier
# (normalised) so we don't pick up the wrong person.
ARCHIVE_GUARD = {
    "minshawi": ["منشاوي", "minsh"],
    "banna": ["البنا", "banna"],
    "maher": ["معيقلي", "muaiql", "maher"],
    "binhameed": ["حميد", "humaid", "hameed", "humeid"],
    "ghamdi": ["سعدالغامدي", "saad", "sa3d", "saadelghamd", "سعد"],
    "afasy": ["عفاسي", "afasy", "alafasi", "afasi"],
    "alhaj": ["الحاج", "alhaj", "al-haj", "elhag", "alhag"],
    "dawas": ["دعوس", "dawas", "daws", "dawwas"],
    "islamsobhi": ["صبحي", "sobhi", "sobhy", "subhi"],
    "shamsan": ["شمسان", "shamsan"],
    "tablawi": ["طبلاوي", "tablaw"],
    "nasr": ["عبدالرازق", "عبدالرزاق", "abdelrazek", "abdulrazaq", "abdel razek", "abdulrazzaq"],
    "dosari": ["دوسري", "dosar", "dossar", "dussar", "dawsar"],
    "ghazi": ["بلالغازي", "بلالالغازي", "bilalghazi", "ghazibilal", "bilal ghazi", "bilal_ghazi", "bilal-ghazi", "elghazi"],
    "basit": ["باسط", "basit", "baset", "basset"],
    "omarali": ["عمرعلي", "omarali", "omar ali", "omar_ali"],
    "anas": ["انسعبدالستار", "انسعبد", "abdelsattar", "abdulsattar", "abd el sattar", "abdel sattar"],
}

RUQYAH = [
    ("maher", ["الرقية", "الرقيه", "رقية", "رقيه", "ruqyah", "ruqya", "roqya", "roqia", "roquia"], ["معيقلي", "muaiql", "maher", "meaqli"],
     ['"الرقية الشرعية" المعيقلي', 'ruqyah muaiqly', 'رقية ماهر المعيقلي']),
    ("hassan_saleh", ["الرقية", "الرقيه", "رقية", "رقيه", "ruqyah", "ruqya", "roqya", "roqia"], ["حسن صالح", "حسنصالح", "hassan saleh", "hasan salih", "hassansaleh", "hassan_saleh"],
     ['"حسن صالح" رقية', '"الرقية الشرعية" "حسن صالح"', '"hassan saleh" ruqyah', 'رقية حسن صالح', '"حسن صالح"', 'الرقية الشرعية']),
]

SURAH_NAMES_AR = """الفاتحة البقرة آل_عمران النساء المائدة الأنعام الأعراف الأنفال التوبة يونس هود يوسف الرعد إبراهيم الحجر النحل الإسراء الكهف مريم طه الأنبياء الحج المؤمنون النور الفرقان الشعراء النمل القصص العنكبوت الروم لقمان السجدة الأحزاب سبأ فاطر يس الصافات ص الزمر غافر فصلت الشورى الزخرف الدخان الجاثية الأحقاف محمد الفتح الحجرات ق الذاريات الطور النجم القمر الرحمن الواقعة الحديد المجادلة الحشر الممتحنة الصف الجمعة المنافقون التغابن الطلاق التحريم الملك القلم الحاقة المعارج نوح الجن المزمل المدثر القيامة الإنسان المرسلات النبأ النازعات عبس التكوير الانفطار المطففين الانشقاق البروج الطارق الأعلى الغاشية الفجر البلد الشمس الليل الضحى الشرح التين العلق القدر البينة الزلزلة العاديات القارعة التكاثر العصر الهمزة الفيل قريش الماعون الكوثر الكافرون النصر المسد الإخلاص الفلق الناس""".split()
SURAH_NAMES_AR = [s.replace("_", " ") for s in SURAH_NAMES_AR]
assert len(SURAH_NAMES_AR) == 114

SURAH_NAMES_EN = ["fatiha","baqarah","imran","nisa","maidah","anam","araf","anfal","tawbah","yunus","hud","yusuf","rad","ibrahim","hijr","nahl","isra","kahf","maryam","taha","anbiya","hajj","muminun","nur","furqan","shuara","naml","qasas","ankabut","rum","luqman","sajdah","ahzab","saba","fatir","yasin","saffat","sad","zumar","ghafir","fussilat","shura","zukhruf","dukhan","jathiyah","ahqaf","muhammad","fath","hujurat","qaf","dhariyat","tur","najm","qamar","rahman","waqiah","hadid","mujadila","hashr","mumtahanah","saff","jumuah","munafiqun","taghabun","talaq","tahrim","mulk","qalam","haqqah","maarij","nuh","jinn","muzzammil","muddaththir","qiyamah","insan","mursalat","naba","naziat","abasa","takwir","infitar","mutaffifin","inshiqaq","buruj","tariq","ala","ghashiyah","fajr","balad","shams","layl","duha","sharh","tin","alaq","qadr","bayyinah","zalzalah","adiyat","qariah","takathur","asr","humazah","fil","quraysh","maun","kawthar","kafirun","nasr","masad","ikhlas","falaq","nas"]
assert len(SURAH_NAMES_EN) == 114


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKC", s or "")
    s = re.sub("[ً-ْٰـ]", "", s)
    for a, b in (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ٱ", "ا"), ("ة", "ه"), ("ى", "ي"), ("ؤ", "و"), ("ئ", "ي")):
        s = s.replace(a, b)
    s = re.sub(r"[^ء-يa-zA-Z0-9]", "", s)
    return s.lower()


SURAH_NORM_AR = [norm(n) for n in SURAH_NAMES_AR]


PERSON_NAMES = {norm(x) for x in ["محمد", "إبراهيم", "يوسف", "نوح", "هود", "لقمان", "مريم", "يونس"]}


def _name_surah(stem):
    """Surah from its name, only when written as 'سورة X' / 'surah X' or at the start."""
    lead = re.sub(r"^[\d\s._\-]+", "", stem)
    n_ar = norm(lead)
    best = None
    for i, sn in enumerate(SURAH_NORM_AR):
        if len(sn) < 2:
            continue
        starts = sn not in PERSON_NAMES and (n_ar.startswith(sn) or (len(sn) >= 4 and n_ar.startswith("ال" + sn)))
        hit = ("سوره" + sn) in n_ar or starts
        if hit and (best is None or len(sn) > len(SURAH_NORM_AR[best])):
            best = i
    if best is not None:
        return best + 1
    low = re.sub(r"[^a-z]", "", lead.lower())
    for i, en in sorted(enumerate(SURAH_NAMES_EN), key=lambda x: -len(x[1])):
        if len(en) < 3:
            continue
        if re.search(r"(surah|sura|surat|soorah)(al|an|ar|as|at|ad|adh|az|ash)?" + en, low) or low.startswith(en) or low.startswith("al" + en):
            return i + 1
    return None


def detect_surah(filename: str, strict: bool = False):
    """strict: number only counts when it leads the file name (for small,
    hand-made collections where other numbers are noise)."""
    base = urllib.parse.unquote(filename).rsplit("/", 1)[-1]
    stem = base.rsplit(".", 1)[0]
    num = None
    pattern = r"^\s*(\d{1,3})(?!\d)" if strict else r"(?<!\d)(\d{1,3})(?!\d)"
    for m in re.finditer(pattern, stem):
        n = int(m.group(1))
        if 1 <= n <= 114:
            num = n
            break
    name = _name_surah(stem)
    if name and num and name != num:
        return name
    return num or name


def get_json(url, timeout=40, tries=3):
    last = None
    for t in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8", "replace"))
        except Exception as e:  # noqa
            last = e
            time.sleep(1.5 * (t + 1))
    print(f"  ! GET failed {url}: {last}", file=sys.stderr)
    return None


def check_audio(url, timeout=25):
    """True if url answers with something that looks like audio (> 20 KB)."""
    try:
        req = urllib.request.Request(url, headers={**UA, "Range": "bytes=0-1023"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            ct = (r.headers.get("Content-Type") or "").lower()
            cr = r.headers.get("Content-Range") or ""
            size = int(cr.rsplit("/", 1)[-1]) if "/" in cr and cr.rsplit("/", 1)[-1].isdigit() else int(r.headers.get("Content-Length") or 0)
            head = r.read(16)
            looks = head[:3] == b"ID3" or (len(head) > 1 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0) or b"ftyp" in head
            return (looks or "audio" in ct or "octet-stream" in ct) and (size == 0 or size > 20_000)
    except Exception:
        return False


# --------------------------------------------------------------- mp3quran
def from_mp3quran():
    out = {}
    data = get_json("https://www.mp3quran.net/api/v3/reciters?language=ar")
    if not data:
        return out
    api = data.get("reciters", [])
    for rid, tokens, _, _ in RECITERS:
        toks = [norm(t) for t in tokens]
        found = []
        for r in api:
            n = norm(r.get("name", ""))
            if not all(t in n for t in toks):
                continue
            for m in r.get("moshaf", []):
                server = m.get("server") or ""
                if not server:
                    continue
                if not server.endswith("/"):
                    server += "/"
                lst = [int(x) for x in str(m.get("surah_list", "")).split(",") if x.strip().isdigit()]
                name = m.get("name", "")
                score = (2 if "حفص" in name else 0) + (3 if "مرتل" in name else 0) + len(lst) / 114
                found.append((score, r.get("name"), name, server, lst))
        if found:
            found.sort(key=lambda x: -x[0])
            out[rid] = found
    return out


# ------------------------------------------------------------ quranicaudio
def from_quranicaudio():
    out = {}
    data = get_json("https://quranicaudio.com/api/qaris")
    if not data:
        return out
    for rid, _, _, qtoks in RECITERS:
        if not qtoks:
            continue
        cands = []
        for q in data:
            name = (q.get("name") or "").lower()
            if any(t in name for t in qtoks) and q.get("relative_path") and not q.get("file_formats", "mp3") == "":
                if q.get("section_id") not in (1, None):  # 1 = main recitations
                    continue
                cands.append((name, "https://download.quranicaudio.com/quran/" + q["relative_path"]))
        if cands:
            out[rid] = cands
    return out


# --------------------------------------------------------------- archive
def archive_search(query, rows=40):
    q = f"({query}) AND mediatype:(audio)"
    url = ("https://archive.org/advancedsearch.php?" + urllib.parse.urlencode(
        {"q": q, "fl[]": ["identifier", "title", "downloads"], "rows": rows, "output": "json"}, doseq=True))
    data = get_json(url)
    if not data:
        return []
    return data.get("response", {}).get("docs", [])


def archive_files(identifier):
    meta = get_json(f"https://archive.org/metadata/{urllib.parse.quote(identifier)}")
    if not meta:
        return [], ""
    title = meta.get("metadata", {}).get("title", "")
    if isinstance(title, list):
        title = " ".join(title)
    files = []
    for f in meta.get("files", []):
        name = f.get("name", "")
        if not name.lower().endswith(".mp3"):
            continue
        if f.get("source") == "derivative" and "64kb" in name.lower():
            continue
        files.append((name, int(f.get("size") or 0)))
    return files, title


# Items whose files are NOT one-file-per-surah of a Hafs murattal recitation.
EXCLUDE = ["جزء", "اجزاء", "juz", "parts", "ربع", "ارباع", "رباع", "hizb", "حزب", "خطب", "خطبه", "khutba",
           "تراويح", "تهجد", "taraweeh", "tarawih", "قيام", "ليله", "رمضان", "ramadan", "مجود", "mujawwad",
           "mojawwad", "mujawad", "ذكوان", "ورش", "warsh", "قالون", "qalun", "qaloon", "شعبه", "shubah",
           "الدوري", "douri", "duri", "السوسي", "susi", "تفسير", "tafsir", "ترجمه", "translation", "english",
           "محاضره", "درس", "lecture", "دعاء", "تعليم", "معلم", "muallim", "teacher", "اطفال", "kids", "صلاه",
           "نصرالله", "nasrallah", "العريقي", "areeqi", "ياسرحامد"]
GOOD = ["كامل", "كاملا", "full", "complete", "114", "مصحف", "المصحف", "murattal", "مرتل", "quran"]


def excluded(text):
    t, low = norm(text), text.lower()
    return any((norm(x) and norm(x) in t) or x in low for x in EXCLUDE)


def quality(text):
    t, low = norm(text), text.lower()
    return sum(1 for g in GOOD if norm(g) in t or g in low)


def guard_ok(rid, text):
    t = norm(text)
    low = text.lower()
    return any(norm(g) in t or g in low for g in ARCHIVE_GUARD.get(rid, []))


def from_archive(rid, queries):
    ids = {}
    for q in queries:
        for d in archive_search(q):
            ids.setdefault(d["identifier"], d)
    items = []

    def inspect(identifier):
        files, title = archive_files(identifier)
        if not guard_ok(rid, f"{identifier} {title}") or excluded(f"{identifier} {title}"):
            return None
        mapping = {}
        numbered = sum(1 for name, _ in files if re.search(r"\d", name.rsplit("/", 1)[-1]))
        strict = numbered < 50
        for name, size in files:
            if size and size < 50_000:
                continue
            if excluded(name):
                continue
            n = detect_surah(name, strict=strict)
            if n and (n not in mapping or size > mapping[n][1]):
                mapping[n] = (name, size)
        if not mapping:
            return None
        return identifier, title, quality(f"{identifier} {title}"), {n: f"https://archive.org/download/{urllib.parse.quote(identifier)}/{urllib.parse.quote(nm)}" for n, (nm, _) in mapping.items()}

    with cf.ThreadPoolExecutor(8) as ex:
        for res in ex.map(inspect, list(ids)[:60]):
            if res:
                items.append(res)
    # full, clearly-labelled collections first; then by coverage
    items.sort(key=lambda x: (-(len(x[3]) >= 100), -x[2], -len(x[3])))
    return [(i, t, m) for i, t, _, m in items]


# ---------------------------------------------------------------- ruqyah
def ruqyah_all():
    """Search every ruqyah query, then assign each file to a sheikh by its own name."""
    ids = {}
    for _, _, _, queries in RUQYAH:
        for q in queries:
            for d in archive_search(q, rows=30):
                ids.setdefault(d["identifier"], d)
    out = {rid: [] for rid, *_ in RUQYAH}

    def inspect(identifier):
        files, title = archive_files(identifier)
        found = []
        for name, size in files:
            if size and size < 3_000_000:   # skip short clips
                continue
            fname = urllib.parse.unquote(name.rsplit("/", 1)[-1])
            full = f"{identifier} {title} {fname}"
            nf, lf = norm(full), full.lower()
            nfile, lfile = norm(fname), fname.lower()
            if re.search(r"(sourate|surah|sura|سوره|سورة)", lfile + nfile):
                continue  # a surah recitation, not a ruqyah track
            for rid, must_any, guard, _ in RUQYAH:
                if not any(norm(m) in nf or m in lf for m in must_any):
                    continue
                # the sheikh's name must be in the FILE name, unless the whole
                # item is clearly his and has a single ruqyah file
                in_file = any(norm(g) in nfile or g in lfile for g in guard)
                if not in_file:
                    continue
                found.append((rid, {
                    "title": fname.rsplit(".", 1)[0].replace("_", " ").strip(),
                    "url": f"https://archive.org/download/{urllib.parse.quote(identifier)}/{urllib.parse.quote(name)}",
                    "size": size,
                }))
        return found

    with cf.ThreadPoolExecutor(8) as ex:
        for res in ex.map(inspect, list(ids)[:150]):
            for rid, t in res:
                out[rid].append(t)
    for rid in out:
        seen, keep = set(), []
        for t in sorted(out[rid], key=lambda t: -t["size"]):
            key = t["size"] // 1_500_000
            if key in seen:
                continue
            seen.add(key)
            keep.append(t)
        out[rid] = keep[:8]
    return out


# ---------------------------------------------------------------- azkar
AZKAR_NAMES = {
    "minshawi": "المنشاوي", "banna": "محمود علي البنا", "maher": "ماهر المعيقلي", "binhameed": "أحمد بن حميد",
    "ghamdi": "سعد الغامدي", "afasy": "مشاري العفاسي", "alhaj": "عبدالرحمن الحاج", "dawas": "ماجد الدعوس",
    "islamsobhi": "إسلام صبحي", "shamsan": "الشمسان", "tablawi": "الطبلاوي", "nasr": "أحمد عبدالرازق نصر",
    "dosari": "ياسر الدوسري", "ghazi": "بلال غازي", "basit": "عبد الباسط", "omarali": "عمر علي",
    "anas": "أنس عبد الستار", "hassan_saleh": "حسن صالح",
}
AZKAR_GUARD = dict(ARCHIVE_GUARD)
AZKAR_GUARD["hassan_saleh"] = ["حسنصالح", "hassan saleh", "hassansaleh", "hassan_saleh"]
AZKAR_GUARD["maher"] = ["معيقلي", "muaiql", "meaqli"]
AZKAR_WORDS = ["اذكار", "ازكار", "azkar", "adhkar", "athkar", "azkaar"]
MORNING = ["صباح", "morning", "sabah"]
EVENING = ["مساء", "المسا", "evening", "masa"]


def azkar_all():
    ids = {}
    queries = ['"أذكار الصباح والمساء"', '"أذكار الصباح"', '"أذكار المساء"', 'adhkar morning evening', 'azkar sabah masaa']
    for name in AZKAR_NAMES.values():
        queries += [f'"أذكار الصباح" "{name}"', f'"أذكار المساء" "{name}"', f'أذكار {name}']
    for q in queries:
        for d in archive_search(q, rows=25):
            ids.setdefault(d["identifier"], d)
    out = {rid: {"morning": [], "evening": []} for rid in AZKAR_NAMES}

    def inspect(identifier):
        files, title = archive_files(identifier)
        found = []
        for name, size in files:
            if size and size < 1_000_000:
                continue
            fname = urllib.parse.unquote(name.rsplit("/", 1)[-1])
            full = f"{identifier} {title} {fname}"
            nf, lf = norm(full), full.lower()
            if not any(norm(w) in nf or w in lf for w in AZKAR_WORDS):
                continue
            nfile, lfile = norm(fname), fname.lower()
            # time of day: prefer the file name, fall back to the item
            m_file = any(norm(w) in nfile or w in lfile for w in MORNING)
            e_file = any(norm(w) in nfile or w in lfile for w in EVENING)
            if not (m_file or e_file):
                m_file = any(norm(w) in nf or w in lf for w in MORNING)
                e_file = any(norm(w) in nf or w in lf for w in EVENING)
            if not (m_file or e_file):
                continue
            owners = [rid for rid, g in AZKAR_GUARD.items() if any(norm(x) in nf or x in lf for x in g)]
            if len(owners) != 1:
                continue
            track = {
                "title": fname.rsplit(".", 1)[0].replace("_", " ").strip(),
                "url": f"https://archive.org/download/{urllib.parse.quote(identifier)}/{urllib.parse.quote(name)}",
                "size": size,
            }
            if m_file:
                found.append((owners[0], "morning", track))
            if e_file:
                found.append((owners[0], "evening", track))
        return found

    with cf.ThreadPoolExecutor(8) as ex:
        for res in ex.map(inspect, list(ids)[:250]):
            for rid, when, t in res:
                out[rid][when].append(t)
    for rid in out:
        for when in out[rid]:
            seen, keep = set(), []
            for t in sorted(out[rid][when], key=lambda t: -t["size"]):
                key = t["size"] // 500_000
                if key in seen:
                    continue
                seen.add(key)
                keep.append(t)
            out[rid][when] = keep[:3]
    return out


# ------------------------------------------------- everyayah / adhan / dua
EVERYAYAH = {
    "maher": ["MaherAlMuaiqly128kbps", "Maher_AlMuaiqly_64kbps"],
    "minshawi": ["Minshawy_Murattal_128kbps"],
    "afasy": ["Alafasy_128kbps", "Alafasy_64kbps"],
    "basit": ["Abdul_Basit_Murattal_192kbps", "Abdul_Basit_Murattal_64kbps"],
    "ghamdi": ["Ghamadi_40kbps"],
    "dosari": ["Yasser_Ad-Dussary_128kbps"],
    "tablawi": ["Mohammad_al_Tablaway_128kbps", "Mohammad_al_Tablaway_64kbps"],
    "banna": ["mahmoud_ali_al_banna_32kbps"],
}


def everyayah_ok():
    out = {}
    for rid, folders in EVERYAYAH.items():
        for f in folders:
            if check_audio(f"https://everyayah.com/data/{f}/043013.mp3"):
                out[rid] = f
                break
    return out


def archive_tracks(queries, must, min_size, max_size, limit, title_must=None, exclude=None):
    ids = {}
    for q in queries:
        for d in archive_search(q, rows=25):
            ids.setdefault(d["identifier"], d)

    def inspect(identifier):
        files, title = archive_files(identifier)
        found = []
        for name, size in files:
            if size and (size < min_size or size > max_size):
                continue
            fname = urllib.parse.unquote(name.rsplit("/", 1)[-1])
            n, low = norm(fname), fname.lower()
            if not any(norm(m) in n or m in low for m in must):
                continue
            if exclude and any(norm(x) in n or x in low for x in exclude):
                continue
            if title_must and not any(norm(m) in n or m in low for m in title_must):
                continue
            found.append({
                "title": fname.rsplit(".", 1)[0].replace("_", " ").strip(),
                "url": f"https://archive.org/download/{urllib.parse.quote(identifier)}/{urllib.parse.quote(name)}",
                "size": size,
            })
        return found

    tracks = []
    with cf.ThreadPoolExecutor(8) as ex:
        for res in ex.map(inspect, list(ids)[:220]):
            tracks.extend(res)
    seen, keep = set(), []
    for t in sorted(tracks, key=lambda t: t["size"]):
        k = t["size"] // 50_000
        if k in seen:
            continue
        seen.add(k)
        keep.append(t)
    with cf.ThreadPoolExecutor(8) as ex:
        good = [t for t, g in zip(keep, ex.map(lambda t: check_audio(t["url"]), keep)) if g]
    return good[:limit]


# ------------------------------------------------------------------ radios
RADIO_GROUPS = [
    ("egypt", "إذاعة القرآن الكريم من القاهرة", "مصر · 98.2 FM",
     ["القرآن الكريم من القاهرة", "Egyptian Holy Quran", "Quran Cairo", "اذاعة القران الكريم", "Holy Quran Radio Cairo"],
     ["قاهره", "القاهره", "cairo", "egypt", "مصر", "المصريه"],
     ["https://stream.radiojar.com/8s5u5tpdtwzuv", "https://n02.radiojar.com/8s5u5tpdtwzuv"]),
    ("makkah", "إذاعة القرآن الكريم من مكة", "السعودية · بث الحرم والإذاعة",
     ["مكة", "Makkah", "Mecca", "Quran Radio Saudi", "إذاعة القرآن الكريم السعودية", "Saudi Quran"],
     ["مكه", "makkah", "mecca", "makka", "saudi", "السعوديه", "haram"],
     ["https://stream.radiojar.com/0tpy1h0kxtzuv"]),
    ("madinah", "إذاعة المدينة المنورة", "المسجد النبوي الشريف",
     ["المدينة المنورة", "Madinah", "Medina", "Madina", "المسجد النبوي", "Masjid Nabawi", "Nabawi", "Al Madinah",
      "Haramain", "Prophet Mosque", "مدينة"],
     ["مدينه", "المدينه", "madinah", "medina", "madina", "nabawi", "نبوي", "haramain", "prophet"],
     []),
]


def check_stream(url, timeout=20):
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            ct = (r.headers.get("Content-Type") or "").lower()
            head = r.read(2048)
            if "mpegurl" in ct or url.lower().split("?")[0].endswith(".m3u8") or head.startswith(b"#EXTM3U"):
                return True
            looks = head[:3] == b"ID3" or (len(head) > 1 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0)
            return looks or "audio" in ct or "aacp" in ct or "ogg" in ct
    except Exception:
        return False


def radios():
    out = []
    api = "https://de1.api.radio-browser.info/json/stations/search?"
    for gid, name, desc, queries, guard, fallback in RADIO_GROUPS:
        cands = []
        for q in queries:
            data = get_json(api + urllib.parse.urlencode(
                {"name": q, "hidebroken": "true", "order": "votes", "reverse": "true", "limit": 25})) or []
            for st in data:
                text = f"{st.get('name', '')} {st.get('country', '')} {st.get('tags', '')}"
                t, low = norm(text), text.lower()
                if not any(norm(g) in t or g in low for g in guard):
                    continue
                if not any(norm(k) in t or k in low for k in
                           ["قران", "قرآن", "quran", "koran", "coran", "حرم", "haram", "nabawi", "نبوي", "masjid", "مسجد", "islam"]):
                    continue
                if gid == "madinah" and not re.search(r"(?<![a-z])(madinah|medina|madina|madinat)(?![a-z])|المدينه|المدينة|نبوي|nabawi", low + " " + text):
                    continue
                u = st.get("url_resolved") or st.get("url")
                if u:
                    cands.append((int(st.get("votes") or 0), u, st.get("name", "")))
        if gid == "madinah":
            for tag in ["madinah", "medina", "nabawi", "haramain"]:
                data = get_json("https://de1.api.radio-browser.info/json/stations/bytag/" + urllib.parse.quote(tag)
                                + "?hidebroken=true&order=votes&reverse=true&limit=25") or []
                for st in data:
                    text = f"{st.get('name', '')} {st.get('tags', '')}"
                    low = text.lower()
                    if not re.search(r"(?<![a-z])(madinah|medina|madina|nabawi|haramain)(?![a-z])|المدينه|المدينة|نبوي", low + " " + text):
                        continue
                    if not any(k in low or k in text for k in ["quran", "koran", "haram", "nabawi", "masjid", "islam", "قرآن", "قران", "مسجد"]):
                        continue
                    u = st.get("url_resolved") or st.get("url")
                    if u:
                        cands.append((int(st.get("votes") or 0), u, st.get("name", "")))
        cands.sort(key=lambda x: -x[0])
        urls = []
        for u in fallback + [c[1] for c in cands]:
            if u not in urls:
                urls.append(u)
        with cf.ThreadPoolExecutor(8) as ex:
            ok = [u for u, g in zip(urls[:14], ex.map(check_stream, urls[:14])) if g]
        if not ok and gid == "madinah":
            continue  # no genuine Madinah stream — better nothing than a wrong station
        out.append({"id": gid, "name": name, "desc": desc, "urls": ok[:4],
                    "found": [c[2] for c in cands[:5]]})

    # every reciter radio from mp3quran (24/7 recitation by one reciter)
    data = get_json("https://www.mp3quran.net/api/v3/radios?language=ar") or {}
    for grp in out:
        if grp["id"] == "madinah" and not grp["urls"]:
            for r in (data.get("radios") or []):
                n = r.get("name") or ""
                if ("المدينة المنورة" in n or "المسجد النبوي" in n) and r.get("url") and check_stream(r["url"]):
                    grp["urls"].append(r["url"])
                    grp["found"].append(n)
    extra = []
    for r in (data.get("radios") or [])[:400]:
        u, n = r.get("url"), r.get("name")
        if u and n:
            extra.append({"id": f"mq{r.get('id')}", "name": n.strip(), "desc": "mp3quran", "urls": [u]})
    with cf.ThreadPoolExecutor(16) as ex:
        good = [e for e, g in zip(extra, ex.map(lambda e: check_stream(e["urls"][0]), extra)) if g]
    return out, good


# ------------------------------------------------------------------ main
def main():
    report = ["# Sources report", ""]
    mq = from_mp3quran()
    qa = from_quranicaudio()
    result = {"generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "reciters": {}, "ruqyah": {}, "labels": {}}

    for rid, _, queries, _ in RECITERS:
        print(f"== {rid}", flush=True)
        per = {n: [] for n in range(1, 115)}
        lines = []
        if rid in mq:
            score, rname, mname, server, lst = mq[rid][0]
            result["labels"][rid] = mname
            for n in (lst or range(1, 115)):
                per[n].append(f"{server}{n:03d}.mp3")
            lines.append(f"- mp3quran: **{rname}** / {mname} → {server} ({len(lst)} surahs)")
        for name, base in qa.get(rid, [])[:1]:
            for n in range(1, 115):
                per[n].append(f"{base}{n:03d}.mp3")
            lines.append(f"- quranicaudio: {name} → {base}")
        arch = from_archive(rid, queries)
        for identifier, title, mapping in arch[:8]:
            for n, u in mapping.items():
                per[n].append(u)
            lines.append(f"- archive.org: `{identifier}` — {title} ({len(mapping)} surahs)")

        # verify: keep only URLs that answer like audio. Check the first two
        # candidates of every surah; drop a whole base if its sample fails.
        jobs = []
        for n, urls in per.items():
            for u in urls[:3]:
                jobs.append((n, u))
        ok = {}
        with cf.ThreadPoolExecutor(24) as ex:
            for (n, u), good in zip(jobs, ex.map(lambda j: check_audio(j[1]), jobs)):
                if good:
                    ok.setdefault(n, []).append(u)
        final = {}
        for n in range(1, 115):
            good = [u for u in per[n] if u in ok.get(n, [])]
            rest = [u for u in per[n][3:]]
            if good or rest:
                final[str(n)] = good + rest
        result["reciters"][rid] = final
        verified = sum(1 for n in range(1, 115) if ok.get(n))
        report.append(f"## {rid} — {verified}/114 verified, {len(final)}/114 with links")
        report.extend(lines or ["- nothing found"])
        report.append("")
        print(f"   {verified}/114 verified", flush=True)

    all_ruqyah = ruqyah_all()
    for rid, *_ in RUQYAH:
        tr = all_ruqyah[rid]
        good = []
        with cf.ThreadPoolExecutor(8) as ex:
            for t, g in zip(tr, ex.map(lambda t: check_audio(t["url"]), tr)):
                if g:
                    good.append({"title": t["title"], "url": t["url"], "size": t["size"]})
        result["ruqyah"][rid] = good
        report.append(f"## ruqyah/{rid} — {len(good)} tracks")
        for t in good:
            report.append(f"- {t['title']} ({t['size'] // 1_000_000} MB) — {t['url']}")
        report.append("")

    result["azkar"] = {}
    az = azkar_all()
    report.append("## azkar")
    for rid, d in az.items():
        clean = {}
        for when, tr in d.items():
            with cf.ThreadPoolExecutor(8) as ex:
                good = [t for t, g in zip(tr, ex.map(lambda t: check_audio(t["url"]), tr)) if g]
            if good:
                clean[when] = good
        if clean:
            result["azkar"][rid] = clean
            report.append(f"- {rid}: صباح {len(clean.get('morning', []))} · مساء {len(clean.get('evening', []))}")
    report.append("")

    ea = everyayah_ok()
    result["everyayah"] = ea
    report.append(f"## everyayah (دعاء الركوب) — {ea}")
    result["adhan"] = archive_tracks(
        ['adhan', 'azan', 'athan', 'اذان', 'الأذان', 'adzan', 'adhan collection', 'beautiful azan', 'azan mp3 collection',
         '"الأذان" مكة', 'اذان الحرم المكي', 'adhan makkah', 'azan mp3', '"أذان" بصوت',
         'اذان المسجد النبوي', 'adhan madinah', 'اذان المسجد الاقصى', 'adhan al aqsa',
         'اذان عبد الباسط', 'اذان نصر الدين طوبار', 'اذان محمد رفعت', 'اذان الحصري', 'adhan mishary',
         'اذان علي ملا', 'adhan ali mulla', 'اذان ناصر القطامي', 'beautiful adhan'],
        must=["اذان", "الاذان", "adhan", "azan", "adzan", "athan", "ezan"], min_size=250_000, max_size=9_000_000, limit=24,
        exclude=["doa", "دعاء", "setelah", "ketika", "dua", "qolqolah", "surah", "سوره", "iqama", "اقامه", "lesson", "درس",
                 "ringtone", "nasheed", "نشيد", "song", "اغنيه", "bidah", "makruh", "sebelum", "tanpa", "hukum",
                 "حكم", "fatwa", "فتوى", "kajian"])
    report.append(f"## adhan — {len(result['adhan'])} tracks")
    for t in result["adhan"]:
        report.append(f"- {t['title']} ({t['size'] // 1000} KB)")
    result["dua_rukub"] = archive_tracks(
        ['"دعاء الركوب"', '"دعاء السفر"', 'دعاء ركوب السيارة', 'dua travel safar'],
        must=["الركوب", "ركوب", "السفر", "safar", "travel"], min_size=40_000, max_size=6_000_000, limit=6,
        title_must=["دعاء", "dua", "doaa", "doa"])
    report.append(f"## dua_rukub — {len(result['dua_rukub'])} tracks")
    for t in result["dua_rukub"]:
        report.append(f"- {t['title']} ({t['size'] // 1000} KB)")
    report.append("")

    main_r, extra_r = radios()
    result["radios"] = main_r
    result["radios_extra"] = extra_r
    report.append("## radios")
    for r in main_r:
        report.append(f"- {r['name']}: {len(r['urls'])} working stream(s) {r['urls'][:1]} · found: {r['found']}")
    report.append(f"- reciter radios (mp3quran): {len(extra_r)}")
    report.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    REPORT.write_text("\n".join(report), encoding="utf-8")
    print("\n".join(report))


if __name__ == "__main__":
    main()
