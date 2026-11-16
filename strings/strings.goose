// The user-facing text, looked up by key: each language is a file here, `key = text`
// per line, built into the program. Code names a string by its constant (HOME_CONTINUE)
// and reads it with get(); nothing is copied, the text stays in the embedded file. English
// is the default and fills in any key a translation lacks; the language comes from the
// system's preferred locales (pick()).
namespace strings;
import std;
import .date;
import .keys;

// The languages, by their codes as locales name them.
let EN = 0;
let ET = 1;
let LANGUAGES = ["en", "et"];

// The keys and their constants come from en.txt (keys.goose). Code that steps from a
// key by offset names the run's first by the name it had before.
let HOW_STEP = HOW_MOVE;             // three a step: the name, _line, _well
let REPLAY_TAKE = REPLAY_TAKE_WHITE;
let REPLAY_ONE = REPLAY_ONE_WHITE;

// The current language's strings, as views into its file.
var table: const u8[:][COUNT];
var current = EN;

// A language's file, as built into the program.
fn file(lang: i64) -> const u8[:] {
    return if lang == ET { embed_file("et.txt") } else { embed_file("en.txt") };
}

// The index of a key in KEYS, or -1.
fn key(name: const u8[:]) -> i64 {
    for k, i in KEYS { if k == name { return i; } }
    return -1;
}

// The next line of text and what follows it.
fn next_line(text: const u8[:]) -> const u8[:], const u8[:] {
    let line, rest, found = split_once(text, '\n');
    return line, rest;
}

// A line's key and text, or false for a blank line or a comment.
fn entry(line: const u8[:]) -> const u8[:], const u8[:], bool {
    let l = trim(line);
    if l.len == 0 || l[0] == '#' { return l, l, false; }
    let name, text, found = split_once(l, '=');
    return trim(name), trim(text), true;
}

// Makes lang the current language: its strings, and English for any it lacks.
fn use(lang: i64) {
    current = if lang >= 0 && lang < LANGUAGES.len { lang } else { EN };
    for l in [EN, current] {
        var text = file(l);
        while text.len > 0 {
            let line, rest = next_line(text);
            text = rest;
            let name, value, ok = entry(line);
            guard ok else { continue; }
            let k = key(name);
            if k >= 0 { table[k] = value; }
        }
    }
}

// The current language's string for a key (one of the constants above).
fn get(k: i64) -> const u8[:] { return table[k]; }

// The string for a key into out, each {} in it replaced by the next of `numbers`.
fn fill_in(out: u8[..64]&, k: i64, numbers: const i64[:]) {
    out.clear();
    var rest = table[k];
    var n = 0;
    while rest.len > 0 {
        if rest.len >= 2 && rest[0] == '{' && rest[1] == '}' && n < numbers.len {
            var digits: u8[..20] = [];
            var x = max(numbers[n], 0);
            if x == 0 { digits.push('0'); }
            while x > 0 {
                digits.push(('0' + x % 10) as u8);
                x /= 10;
            }
            for i in digits.len { if out.len < 64 { out.push(digits[digits.len - 1 - i]); } }
            n++;
            rest = rest[2..];
            continue;
        }
        if out.len < 64 { out.push(rest[0]); }
        rest = rest[1..];
    }
}

// The string for a key into out, its first {} replaced by `word`.
fn fill_in_word(out: u8[..64]&, k: i64, word: const u8[:]) {
    out.clear();
    var rest = table[k];
    var done = false;
    while rest.len > 0 {
        if !done && rest.len >= 2 && rest[0] == '{' && rest[1] == '}' {
            for c in word { if out.len < 64 { out.push(c); } }
            done = true;
            rest = rest[2..];
            continue;
        }
        if out.len < 64 { out.push(rest[0]); }
        rest = rest[1..];
    }
}

// A key's text in a language, as its file gives it, whichever language is current; ""
// when the file lacks the key.
fn text_of(lang: i64, k: i64) -> const u8[:] {
    var text = file(lang);
    while text.len > 0 {
        let line, rest = next_line(text);
        text = rest;
        let name, value, ok = entry(line);
        if ok && name == KEYS[k] { return value; }
    }
    return "";
}

// A language's own name, as its file gives it, whichever language is current.
fn name_of(lang: i64) -> const u8[:] {
    let name = text_of(lang, LANGUAGE_NAME);
    return if name.len > 0 { name } else { LANGUAGES[lang] };
}

// The language to use, from the system's preferred locales in order, separated by
// commas ("et-EE,en-US"): the first whose language has a file, else English.
fn pick(locales: const u8[:]) -> i64 {
    var text = locales;
    while text.len > 0 {
        let one, rest, found = split_once(text, ',');
        text = rest;
        var code: u8[..8] = [];
        for c in trim(one) {
            if c == '-' || c == '_' || code.len == 8 { break; }
            code.push(c);
        }
        to_lower(code);
        for name, i in LANGUAGES { if name == code { return i; } }
    }
    return EN;
}

// What is wrong with a language file, appended to out: lines that aren't `key = text`,
// unknown keys, keys given twice, and keys it lacks. Returns how many problems.
fn problems(text: const u8[:], out: u8[>..]&) -> i64 {
    var seen: bool[COUNT] = [false; COUNT];
    var n = 0;
    var rest = text;
    while rest.len > 0 {
        let line, after = next_line(rest);
        rest = after;
        let l = trim(line);
        if l.len == 0 || l[0] == '#' { continue; }
        let name, value, found = split_once(l, '=');
        let k = key(trim(name));
        if !found || trim(value).len == 0 {
            format(out, "  not key = text: ", l, "\n");
            n++;
        } else if k < 0 {
            format(out, "  unknown key: ", trim(name), "\n");
            n++;
        } else if seen[k] {
            format(out, "  given twice: ", trim(name), "\n");
            n++;
        } else {
            seen[k] = true;
        }
    }
    for k in COUNT {
        if !seen[k] {
            format(out, "  missing: ", KEYS[k], "\n");
            n++;
        }
    }
    return n;
}
