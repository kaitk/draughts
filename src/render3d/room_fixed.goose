// Made by scripts/room_fixed.py from the light tuner's --dump-room-block: don't edit.
// The room's Surfaces block as constants (shaders::ROOM_HEAD's), after ROOM_HEAD.
namespace room_fixed;

let ROOM_FIXED = """
    const vec4 fixed_plank = vec4(2.13400006, 6, 0.0160000008, 0.0120000001);
    #define plank fixed_plank
    const vec4 fixed_planks = vec4(0.200000003, 0.0299999993, 0.00999999978, 0.600000024);
    #define planks fixed_planks
    const vec4 fixed_worn = vec4(0.699999988, 0.5, 34, 0.5);
    #define worn fixed_worn
    const vec4 fixed_paper = vec4(0.259000003, 0.219999999, 0.192000002, 0.660000026);
    #define paper fixed_paper
    const vec4 fixed_gold = vec4(0.344999999, 0.31400001, 0.231000006, 0.519999981);
    #define gold fixed_gold
    const vec4 fixed_axes = vec4(0.2079117, -0.978147626, 0.978147626, 0.2079117);
    #define axes fixed_axes
    const vec4 fixed_place = vec4(36.5759926, 176.783997, 42.6800003, 80);
    #define place fixed_place
    const vec4 fixed_shade = vec4(0.138414249, 0.114096321, 0.0895976871, 1.79999995);
    #define shade fixed_shade
    const vec4 fixed_tile = vec4(27.4319992, 121.919998, 17.0688, 0);
    #define tile fixed_tile
    const vec4 fixed_plaster_shade = vec4(0.745000005, 0.70599997, 0.638999999, 0.920000017);
    #define plaster_shade fixed_plaster_shade
    const vec4 fixed_plaster_light = vec4(0.815999985, 0.783999979, 0.722000003, 0.860000014);
    #define plaster_light fixed_plaster_light
    const vec4 fixed_ceiling_shade = vec4(0.66839999, 0.617699981, 0.526199996, 0.920000017);
    #define ceiling_shade fixed_ceiling_shade
    const vec4 fixed_ceiling_light = vec4(0.728399992, 0.686699986, 0.602699995, 0.860000014);
    #define ceiling_light fixed_ceiling_light
    const vec4 fixed_paint = vec4(0.776000023, 0.745000005, 0.681999981, 0.379999995);
    #define paint fixed_paint
    const vec4 fixed_lace_thread = vec4(0.866999984, 0.827000022, 0.749000013, 0.899999976);
    #define lace_thread fixed_lace_thread
    const vec4 fixed_shell = vec4(3, 36.5759926, -23.5599995, 30.4799995);
    #define shell fixed_shell
    const vec4 fixed_shell_mids = vec4(88.3919983, -3.047997, -94.487999, 0.150000006);
    #define shell_mids fixed_shell_mids
    const vec4 fixed_shell_niche = vec4(0.649999976, 0.800000012, 2.5, 0.25);
    #define shell_niche fixed_shell_niche
    const vec4 fixed_shell_glass = vec4(12.1920004, 18.2880001, 3.65759993, 0.449999988);
    #define shell_glass fixed_shell_glass
    const vec4 fixed_stone = vec4(0.713999987, 0.698000014, 0.658999979, 0.550000012);
    #define stone fixed_stone
    const vec4 fixed_shell_ends = vec4(134.112, -140.207993, 1, 0);
    #define shell_ends fixed_shell_ends
    const vec4 fixed_brass = vec4(0.958999991, 0.894999981, 0.681999981, 0.280000001);
    #define brass fixed_brass
    const vec4 fixed_lace_light = vec4(1.27901995, 1.21294713, 1.02686679, 0.5);
    #define lace_light fixed_lace_light
    const vec4 fixed_table = vec4(14.4799995, -23.5599995, 0, 0);
    #define table fixed_table
    const vec4 fixed_shell_sun = vec4(0.00549999997, 4.4000001, 0, 0);
    #define shell_sun fixed_shell_sun
    const vec4 fixed_room_baked = vec4(1, 0.200000003, 0.200000003, 0.300000012);
    #define room_baked fixed_room_baked
    const vec4 fixed_light_box = vec4(-135.636002, -18.987999, -50.2919884, 9.14400005);
    #define light_box fixed_light_box
    const vec4 fixed_light_grid = vec4(30, 26, 13, 0);
    #define light_grid fixed_light_grid
    const vec4 fixed_room_box = vec4(-140.207993, 134.112, -36.5759926, 176.783997);
    #define room_box fixed_room_box
    const vec4 fixed_room_doors = vec4(-3.047997, 25.603199, 106.680008, 24.0791988);
    #define room_doors fixed_room_doors
    const vec4 fixed_room_heights = vec4(98.3600006, 2.84000015, 1.20000005, 0.140000001);
    #define room_heights fixed_room_heights
    const vec4 fixed_books = vec4(1, 0.0857142881, 2304, 0);
    #define books fixed_books
    const vec4 fixed_book_cases = vec4(46.3295975, 18.2880001, 2.83999991, 0);
    #define book_cases fixed_book_cases
    const vec4 fixed_corners = vec4(1, 12.1920004, 0, 0);
    #define corners fixed_corners
    const vec4 fixed_ssao = vec4(0, 0, 0, 0);
    #define ssao fixed_ssao
    const vec4 fixed_planar = vec4(0, 0, 0, 0);
    #define planar fixed_planar
    const vec4 fixed_planar_look = vec4(0, 0, 0, 0);
    #define planar_look fixed_planar_look
    const vec4 fixed_contact = vec4(0, 0, 0, 0);
    #define contact fixed_contact
    const vec4 fixed_sheen = vec4(2, 0.800000012, 1, 0);
    #define sheen fixed_sheen
    const vec4 fixed_room_sun = vec4(0.600000024, 0.5, 1, 0);
    #define room_sun fixed_room_sun
    const vec4 fixed_paint_quiet = vec4(0.360000014, 0.419999987, 0.00300000003, 2);
    #define paint_quiet fixed_paint_quiet
    const vec4 fixed_paint_steps = vec4(1, 1, 1, 0);
    #define paint_steps fixed_paint_steps
    const vec4 fixed_sill = vec4(0.00400000019, 0.0700000003, 0.129999995, 0.0199999996);
    #define sill fixed_sill
    const vec4 fixed_sill_steps[2] = vec4[2](vec4(1, 1, 1, 1), vec4(1, 0, 0, 0));
    #define sill_steps fixed_sill_steps
    const vec4 fixed_window_view = vec4(1, 1, 1, 1);
    #define window_view fixed_window_view
    const vec4 fixed_lace_shade = vec4(0.5, 1.5, 0, 0);
    #define lace_shade fixed_lace_shade
    const vec4 fixed_table_map[4] = vec4[4](vec4(0.0170556083, 0.0636523962, -0, 0.772198915), vec4(-0, 0, -0.0625782236, -0.281602025), vec4(0.00321975304, -0.00086273026, -0, 0.479674071), vec4(1, 0, 0, 0));
    #define table_map fixed_table_map
    const vec4 fixed_book_cover[32] = vec4[32](vec4(0.368999988, 0.226999998, 0.133000001, 1), vec4(0.423999995, 0.263000011, 0.157000005, 1), vec4(0.298000008, 0.172999993, 0.101999998, 1), vec4(0.416000009, 0.270999998, 0.160999998, 1), vec4(0.243000001, 0.149000004, 0.0860000029, 1), vec4(0.463, 0.321999997, 0.211999997, 1), vec4(0.289999992, 0.172999993, 0.101999998, 1), vec4(0.352999985, 0.195999995, 0.118000001, 1), vec4(0.226999998, 0.149000004, 0.0939999968, 1), vec4(0.180000007, 0.141000003, 0.125, 1), vec4(0.352999985, 0.226999998, 0.149000004, 1), vec4(0.321999997, 0.187999994, 0.133000001, 1), vec4(0.211999997, 0.195999995, 0.149000004, 1), vec4(0.289999992, 0.172999993, 0.101999998, 1), vec4(0.219999999, 0.219999999, 0.165000007, 1), vec4(0.289999992, 0.157000005, 0.141000003, 1), vec4(0.180000007, 0.187999994, 0.219999999, 1), vec4(0.289999992, 0.211999997, 0.149000004, 1), vec4(0.226999998, 0.180000007, 0.172999993, 1), vec4(0.328999996, 0.26699999, 0.180000007, 1), vec4(0.172999993, 0.195999995, 0.172999993, 1), vec4(0.689999998, 0.603999972, 0.455000013, 1), vec4(0.643000007, 0.556999981, 0.416000009, 1), vec4(0.722000003, 0.643000007, 0.493999988, 1), vec4(0.368999988, 0.31400001, 0.250999987, 1), vec4(0.305999994, 0.289999992, 0.282000005, 1), vec4(0.416000009, 0.352999985, 0.26699999, 1), vec4(0.337000012, 0.243000001, 0.180000007, 1), vec4(0.275000006, 0.275000006, 0.250999987, 1), vec4(0.524999976, 0.477999985, 0.39199999, 1), vec4(0.430999994, 0.423999995, 0.39199999, 1), vec4(0.486000001, 0.430999994, 0.344999999, 1));
    #define book_cover fixed_book_cover
    const vec4 fixed_book_label[8] = vec4[8](vec4(0.352999985, 0.118000001, 0.0780000016, 1), vec4(0.118000001, 0.101999998, 0.0860000029, 1), vec4(0.149000004, 0.180000007, 0.125, 1), vec4(0.80400002, 0.749000013, 0.620000005, 1), vec4(0.753000021, 0.603999972, 0.305999994, 1), vec4(0.165000007, 0.125, 0.0939999968, 1), vec4(0.541000009, 0.477999985, 0.361000001, 1), vec4(0.368999988, 0.211999997, 0.157000005, 1));
    #define book_label fixed_book_label
""";
