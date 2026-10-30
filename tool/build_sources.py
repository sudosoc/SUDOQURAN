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
    ("alhaj", ["عبدالرحمن", "الحاج"], ['"عبدالرحمن الحاج"', '"عبد الرحمن الحاج"', '"abdulrahman al haj"', '"abdul rahman al-haj"'], []),
    ("dawas", ["الدعوس"], ['"ماجد الدعوس"', 'الدعوس', '"majed al-dawas"', '"majed aldawas"'], []),
    ("islamsobhi", ["اسلام", "صبحي"], ['"إسلام صبحي"', '"اسلام صبحي"', '"islam sobhi"', '"islam sobhy"'], ["sobhi"]),
    ("shamsan", ["الشمسان"], ['"وليد الشمسان"', 'الشمسان', '"waleed al-shamsan"', '"walid alshamsan"'], []),
    ("tablawi", ["الطبلاوي"], ['"محمد محمود الطبلاوي"', 'tablawi'], ["tablawi", "tablaway"]),
    ("nasr", ["نصر"], ['"أحمد عبد الرازق نصر"', '"احمد عبدالرازق نصر"', '"أحمد نصر" قرآن', '"ahmed nasr" quran'], []),
    ("dosari", ["ياسر", "الدوسري"], ['"ياسر الدوسري"', 'dossary', 'dosari'], ["dossary", "dosari", "dussary"]),
    ("ghazi", ["بلال", "الغازي"], ['"بلال الغازي"', '"bilal al-ghazi"', '"bilal alghazi"', '"bilal ghazi"'], []),
    ("basit", ["عبدالباسط"], ['"عبد الباسط عبد الصمد"', '"abdul basit" murattal'], ["abdul basit", "abdulbaset", "abdul baset"]),
    ("omarali", ["عمرعلي"], ['"عمر علي" قرآن', '"القارئ عمر علي"', '"omar ali" quran'], []),
]

# extra reciter name tokens that MUST appear in an archive.org title/identifier
# (normalised) so we don't pick up the wrong person.
ARCHIVE_GUARD = {
    "minshawi": ["منشاوي", "minsh"],
    "banna": ["البنا", "banna"],
    "maher": ["معيقلي", "muaiql", "maher"],
    "binhameed": ["حميد", "humaid", "hameed", "humeid"],
    "ghamdi": ["غامدي", "ghamd"],
    "afasy": ["عفاسي", "afasy", "alafasi", "afasi"],
    "alhaj": ["الحاج", "alhaj", "al-haj", "elhag", "alhag"],
    "dawas": ["دعوس", "dawas", "daws", "dawwas"],
    "islamsobhi": ["صبحي", "sobhi", "sobhy", "subhi"],
    "shamsan": ["شمسان", "shamsan"],
    "tablawi": ["طبلاوي", "tablaw"],
    "nasr": ["نصر", "nasr"],
    "dosari": ["دوسري", "dosar", "dossar", "dussar", "dawsar"],
    "ghazi": ["غازي", "ghazi"],
    "basit": ["باسط", "basit", "baset", "basset"],
    "omarali": ["عمرعلي", "omarali", "omar ali", "omar_ali"],
}

RUQYAH = [
    ("maher", ["الرقية", "رقية", "ruqyah", "ruqya", "roqya"], ["معيقلي", "muaiql", "maher"],
     ['"الرقية الشرعية" المعيقلي', 'ruqyah muaiqly', 'رقية ماهر المعيقلي']),
    ("hassan_saleh", ["الرقية", "رقية", "ruqyah", "ruqya", "roqya"], ["حسن صالح", "حسنصالح", "hassan saleh", "hasan salih", "hassansaleh", "hassan_saleh"],
     ['"حسن صالح" رقية', '"الرقية الشرعية" "حسن صالح"', '"hassan saleh" ruqyah', 'رقية حسن صالح']),
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


def detect_surah(filename: str):
    base = urllib.parse.unquote(filename).rsplit("/", 1)[-1]
    stem = base.rsplit(".", 1)[0]
    # leading number is the strongest signal: "001", "18 - الكهف", "Surah_018"
    for m in re.finditer(r"(?<!\d)(\d{1,3})(?!\d)", stem):
        n = int(m.group(1))
        if 1 <= n <= 114:
            return n
    n_ar = norm(stem)
    best = None
    for i, sn in enumerate(SURAH_NORM_AR):
        if len(sn) < 3:
            continue
        if sn in n_ar and (best is None or len(sn) > len(SURAH_NORM_AR[best])):
            best = i
    if best is not None:
        return best + 1
    low = re.sub(r"[^a-z]", "", stem.lower())
    best = None
    for i, en in enumerate(SURAH_NAMES_EN):
        if len(en) < 4:
            continue
        if en in low and (best is None or len(en) > len(SURAH_NAMES_EN[best])):
            best = i
    return best + 1 if best is not None else None


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
        if not guard_ok(rid, f"{identifier} {title}"):
            return None
        mapping = {}
        for name, size in files:
            if size and size < 50_000:
                continue
            n = detect_surah(name)
            if n and (n not in mapping or size > mapping[n][1]):
                mapping[n] = (name, size)
        if not mapping:
            return None
        return identifier, title, {n: f"https://archive.org/download/{urllib.parse.quote(identifier)}/{urllib.parse.quote(nm)}" for n, (nm, _) in mapping.items()}

    with cf.ThreadPoolExecutor(8) as ex:
        for res in ex.map(inspect, list(ids)[:60]):
            if res:
                items.append(res)
    items.sort(key=lambda x: -len(x[2]))
    return items


# ---------------------------------------------------------------- ruqyah
def ruqyah_from_archive(rid, must_any, guard, queries):
    ids = {}
    for q in queries:
        for d in archive_search(q, rows=30):
            ids.setdefault(d["identifier"], d)
    tracks = []

    def inspect(identifier):
        files, title = archive_files(identifier)
        found = []
        for name, size in files:
            full = f"{identifier} {title} {name}"
            n = norm(full)
            low = full.lower()
            if not any(norm(m) in n or m in low for m in must_any):
                continue
            if not any(norm(g) in n or g in low for g in guard):
                continue
            if size and size < 300_000:
                continue
            found.append({
                "title": urllib.parse.unquote(name.rsplit("/", 1)[-1].rsplit(".", 1)[0]).replace("_", " "),
                "url": f"https://archive.org/download/{urllib.parse.quote(identifier)}/{urllib.parse.quote(name)}",
                "size": size,
            })
        return found

    with cf.ThreadPoolExecutor(8) as ex:
        for res in ex.map(inspect, list(ids)[:40]):
            tracks.extend(res)
    # dedupe by size+title, keep reasonable count
    seen, out = set(), []
    for t in sorted(tracks, key=lambda t: -t["size"]):
        key = (t["title"], t["size"] // 100_000)
        if key in seen:
            continue
        seen.add(key)
        out.append(t)
    return out[:12]


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
        for identifier, title, mapping in arch[:4]:
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

    for rid, must_any, guard, queries in RUQYAH:
        tr = ruqyah_from_archive(rid, must_any, guard, queries)
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

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    REPORT.write_text("\n".join(report), encoding="utf-8")
    print("\n".join(report))


if __name__ == "__main__":
    main()
