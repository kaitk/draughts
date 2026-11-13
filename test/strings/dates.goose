// Dates as each language writes them (strings/date.goose): English "13 Nov 2026" with
// the day in one figure when it has one, Estonian "03.11.2026" in two; the pattern's
// pieces on their own; text before a date stays; and a full buffer takes what fits.
import std;
import strings from "../../strings";

fn main() {
    let days = [[2026, 11, 13], [2026, 11, 3], [2027, 1, 1], [2025, 12, 31], [2028, 2, 29]];
    for code, lang in strings::LANGUAGES {
        strings::use(lang);
        for day in days {
            var t: u8[..64] = [];
            strings::date(t, day[0], day[1], day[2]);
            print(code, " ", day[0], "-", day[1], "-", day[2], ": ", t);
        }
        var names: u8[>..] = [];
        for m in 12 {
            if m > 0 { names.append(" "); }
            names.append(strings::get(strings::MONTH_JAN + m));
        }
        print(code, " months: ", names);
    }
    // The pattern's pieces, and what it copies as it is.
    for pattern in ["{d}/{dd}/{mm}/{mon}/{y}", "{y}-{mm}-{dd}", "{x} {d", "{}{d}}", ""] {
        var t: u8[..64] = [];
        strings::date_in(t, pattern, "Mar", 2026, 3, 7);
        print("\"", pattern, "\": \"", t, "\"");
    }
    // Appended after what is there, as the replay's line puts it after the opponent.
    strings::use(strings::EN);
    var line: u8[..64] = [];
    line.append("Easy 500 · ");
    strings::date(line, 2026, 11, 13);
    print(line);
    // A full buffer: nothing past 64 bytes.
    var full: u8[..64] = [];
    for i in 60 { full.push('.'); }
    strings::date(full, 2026, 11, 13);
    print(full.len, ": ", full[60..]);
}
