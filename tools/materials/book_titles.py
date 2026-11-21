# The library's titles: what a Baltic-German manor (Estland, Livland, Kurland) plausibly
# held in the 19th century. Each entry: language, spine text (lines, long s written out),
# format, binding, volumes,
# and a note. German, Estonian and Latvian set in Fraktur; French and Latin in roman.
#
# format: F folio, Q quarto, O octavo, D duodecimo, S sextodecimo
# binding: calf (full calf, raised bands), half (half leather, false bands), cloth
# (publisher's cloth, after ~1840 in Germany), vellum, boards (paper boards, paper
# label), wraps (paper wrappers, unbound), house (the house's own half calf with the
# family's monogram at the tail)

TITLES = [
    # German classics, the house's uniform sets
    ("de", ["Goethe's", "Werke"], "O", "house", 12, "Cotta's Ausgabe letzter Hand, re-bound by the house"),
    ("de", ["Schiller's", "Werke"], "O", "house", 10, "Cotta 1838, the house's binding"),
    ("de", ["Fauſt", "Goethe"], "O", "half", 1, "Faust I and II, Cotta 1834; the hero copy"),
    ("de", ["Leſſing's", "Schriften"], "D", "boards", 6, "Biedermeier paper boards"),
    ("de", ["Herder", "Volkslieder"], "O", "calf", 2, "Herder, in Riga 1764-69; Stimmen der Völker, Latvian and Estonian songs"),
    ("de", ["Wieland's", "Werke"], "D", "calf", 8, "Göschen; small calf"),
    ("de", ["Klopſtock", "Meſſias"], "O", "calf", 2, ""),
    ("de", ["Jean Paul", "Werke"], "D", "boards", 5, ""),
    ("de", ["Kant", "Kritik der", "reinen Vernunft"], "O", "half", 1, "Riga, Hartknoch 1781"),
    ("de", ["Hupel", "Topogr.", "Nachrichten"], "O", "calf", 3, "Riga, Hartknoch 1774-82: Livland and Estland"),
    ("de", ["Conver-", "ſations-", "Lexikon"], "O", "half", 15, "Brockhaus, 10th ed. 1851-55, uniform half leather"),
    ("de", ["Humboldt", "Koſmos"], "O", "cloth", 5, "Cotta 1845-62"),
    ("de", ["Thaer", "Landwirth-", "ſchaft"], "O", "boards", 4, "Grundsätze der rationellen Landwirthschaft, 1809-12"),
    ("de", ["Ranke", "Päpſte"], "O", "cloth", 3, ""),
    ("de", ["Mommſen", "Römiſche", "Geſchichte"], "O", "cloth", 3, "1854-56"),
    ("de", ["Kohl", "Oſtſee-", "provinzen"], "O", "cloth", 2, "Die deutsch-russischen Ostseeprovinzen, 1841"),
    ("de", ["Merkel", "Die Letten"], "O", "boards", 1, "1796"),
    ("de", ["Gadebuſch", "Livländ.", "Jahrbücher"], "O", "calf", 4, "1780-83"),
    ("de", ["Das Inland", "1847"], "Q", "half", 6, "Dorpat weekly 1836-63, bound by the year"),
    ("de", ["Baltiſche", "Monats-ſchrift"], "O", "half", 8, "Riga, from 1859"),
    ("de", ["Verhandl.", "d. Gel. Eſtn.", "Geſellſch."], "O", "half", 4, "Dorpat; vol. IV-V hold Kalewipoeg with the German, 1857-61"),
    ("de", ["Urkunden-", "buch"], "Q", "half", 4, "Bunge, Liv-, Esth- und Curländisches Urkundenbuch, from 1853"),
    ("de", ["Provinzial-", "recht"], "O", "half", 3, "Provinzialrecht der Ostseegouvernements, 1845"),
    ("de", ["Die Bibel"], "Q", "calf", 1, "Luther's"),
    ("de", ["Geſang-", "buch"], "D", "calf", 1, ""),
    ("de", ["Gothaiſcher", "Hof-", "kalender"], "S", "cloth", 9, "the yearly Gotha, small"),
    ("de", ["Rigaſche", "Zeitung"], "F", "half", 3, "bound newspaper years"),
    ("de", ["Hartig", "Jäger"], "O", "boards", 1, "Lehrbuch für Jäger"),
    ("de", ["Walter Scott's", "Romane"], "D", "boards", 7, "in German, 1820s-30s"),
    ("de", ["Heine", "Buch der", "Lieder"], "D", "cloth", 1, "1827, a later printing"),
    ("de", ["Uhland", "Gedichte"], "D", "cloth", 1, ""),
    ("de", ["Brehm", "Thierleben"], "Q", "cloth", 6, "1864-69, gilt pictorial cloth"),
    # Estonian and Latvian, a few, in the old orthography and in Fraktur
    ("et", ["Kalewi-", "poeg"], "O", "boards", 1, "Kreutzwald, Kuopio 1862, the popular edition"),
    ("et", ["Piibli", "Ramat"], "Q", "calf", 1, "the Estonian Bible, 1739"),
    ("de", ["Wiedemann", "Ehſtn.-deutſch.", "Wörterbuch"], "Q", "half", 1, "St Petersburg 1869"),
    ("lv", ["Ta Swehta", "Grahmata"], "F", "vellum", 1, "Glück's Latvian Bible, 1689"),
    ("de", ["Stender", "Lettiſche", "Grammatik"], "O", "calf", 1, "1783"),
    # French
    ("fr", ["ŒUVRES", "DE", "VOLTAIRE"], "O", "calf", 12, "Kehl edition (1784-89), a run of it"),
    ("fr", ["ROUSSEAU", "ŒUVRES"], "D", "calf", 6, ""),
    ("fr", ["MONTESQUIEU", "ESPRIT", "DES LOIS"], "O", "calf", 2, ""),
    ("fr", ["BUFFON", "HIST.", "NATURELLE"], "Q", "calf", 6, ""),
    ("fr", ["DE", "L'ALLEMAGNE"], "O", "half", 3, "Madame de Staël, 1813"),
    ("fr", ["RACINE", "THÉÂTRE"], "D", "calf", 3, ""),
    ("fr", ["DICTION.", "DE", "L'ACADÉMIE"], "Q", "calf", 2, ""),
    # Latin
    ("la", ["HORATII", "OPERA"], "D", "vellum", 1, ""),
    ("la", ["VIRGILII", "OPERA"], "O", "vellum", 1, ""),
    ("la", ["CICERONIS", "OPERA"], "O", "calf", 4, ""),
    ("la", ["TACITI", "OPERA"], "D", "calf", 2, ""),
    ("la", ["CORPUS", "JURIS", "CIVILIS"], "F", "vellum", 2, "law, as the sons studied at Dorpat"),
    ("la", ["LINNÆI", "SYSTEMA", "NATURÆ"], "O", "calf", 2, ""),
    ("la", ["BIBLIA", "SACRA"], "F", "calf", 1, ""),
]
