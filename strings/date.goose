// A date as the language writes it: its file's date.format, a pattern, with the day,
// the month, and the year put into it ("13 Nov 2026" in English, "13.11.2026" in
// Estonian). Appended to a fixed buffer, so a label is built with nothing allocated.
// Only what is shown: dates are kept as they are wherever they are stored.
namespace strings;
import std;

// The date y-m-d appended to out by pattern, as much of it as fits: {d} is the day,
// {dd} the day in two figures, {mm} the month in two figures, {mon} the month's name
// (month), {y} the year; anything else, an unknown {..} too, is copied as it is.
fn date_in(out: u8[..64]&, pattern: const u8[:], month: const u8[:], y: i64, m: i64, d: i64) {
    var rest = pattern;
    while rest.len > 0 {
        var close = -1;
        if rest[0] == '{' {
            for i in 1..rest.len {
                if rest[i] == '}' {
                    close = i;
                    break;
                }
            }
        }
        guard close > 0 else {
            if out.len < 64 { out.push(rest[0]); }
            rest = rest[1..];
            continue;
        }
        let name = rest[1..close];
        if name == "d" {
            figures(out, d, 1);
        } else if name == "dd" {
            figures(out, d, 2);
        } else if name == "mm" {
            figures(out, m, 2);
        } else if name == "mon" {
            for c in month { if out.len < 64 { out.push(c); } }
        } else if name == "y" {
            figures(out, y, 1);
        } else {
            for c in rest[..close + 1] { if out.len < 64 { out.push(c); } }
        }
        rest = rest[close + 1..];
    }
}

// The date y-m-d appended to out in the current language.
fn date(out: u8[..64]&, y: i64, m: i64, d: i64) {
    let month = if m >= 1 && m <= 12 { table[MONTH_JAN + m - 1] } else { "" };
    date_in(out, table[DATE_FORMAT], month, y, m, d);
}

// n in figures, at least `least` of them, zeros before; n is never negative here.
fn figures(out: u8[..64]&, n: i64, least: i64) {
    var digits: u8[..20] = [];
    var x = max(n, 0);
    while x > 0 || digits.len < least {
        digits.push(('0' + x % 10) as u8);
        x /= 10;
    }
    for i in digits.len { if out.len < 64 { out.push(digits[digits.len - 1 - i]); } }
}
