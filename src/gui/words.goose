// Words built in a fixed buffer, for a label made of numbers and text (a rating, a move's
// number, a date) with nothing allocated in a frame. Part of the gui's namespace.
namespace gui;
import std;

type Text = u8[..64];

// n in figures, a minus before a negative one.
fn push_number(t: Text&, n: i64) {
    if n < 0 { push(t, "-"); }
    var digits: u8[..20] = [];
    var k = abs(n);
    loop {
        digits.push(('0' + k % 10) as u8);
        k /= 10;
        guard k > 0 else { break; }
    }
    var i = digits.len - 1;
    while i >= 0 && t.len < 64 {
        t.push(digits[i]);
        i -= 1;
    }
}

// n in two figures at least: a month's or a day's.
fn push_two(t: Text&, n: i64) {
    if n >= 0 && n < 10 { push(t, "0"); }
    push_number(t, n);
}

// s, as much of it as fits.
fn push(t: Text&, s: const u8[:]) { for c in s { if t.len < 64 { t.push(c); } } }
