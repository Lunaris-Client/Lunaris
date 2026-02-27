import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmojiCategory {
  final String name;
  final IconData icon;
  final List<String> shortcodes;

  const EmojiCategory({
    required this.name,
    required this.icon,
    required this.shortcodes,
  });
}

const emojiCategories = <EmojiCategory>[
  EmojiCategory(
    name: 'Smileys & People',
    icon: Icons.emoji_emotions_outlined,
    shortcodes: [
      'grinning', 'smiley', 'smile', 'grin', 'laughing', 'sweat_smile',
      'rofl', 'joy', 'slightly_smiling_face', 'upside_down_face', 'wink',
      'blush', 'innocent', 'smiling_face_with_three_hearts', 'heart_eyes',
      'star_struck', 'kissing_heart', 'kissing', 'kissing_closed_eyes',
      'kissing_smiling_eyes', 'yum', 'stuck_out_tongue',
      'stuck_out_tongue_winking_eye', 'stuck_out_tongue_closed_eyes', 'zany_face',
      'money_mouth_face', 'hugs', 'hand_over_mouth', 'shushing_face',
      'thinking', 'zipper_mouth_face', 'raised_eyebrow', 'neutral_face',
      'expressionless', 'no_mouth', 'smirk', 'unamused', 'roll_eyes',
      'grimacing', 'lying_face', 'relieved', 'pensive', 'sleepy',
      'drooling_face', 'sleeping', 'mask', 'face_with_thermometer',
      'face_with_head_bandage', 'nauseated_face', 'sneezing_face',
      'hot_face', 'cold_face', 'woozy_face', 'dizzy_face',
      'exploding_head', 'cowboy_hat_face', 'partying_face', 'disguised_face',
      'sunglasses', 'nerd_face', 'monocle_face', 'confused', 'worried',
      'slightly_frowning_face', 'frowning_face', 'open_mouth', 'hushed',
      'astonished', 'flushed', 'pleading_face', 'cry', 'sob',
      'scream', 'confounded', 'persevere', 'disappointed',
      'sweat', 'weary', 'tired_face', 'yawning_face', 'triumph',
      'rage', 'angry', 'cursing_face', 'smiling_imp', 'imp',
      'skull', 'skull_and_crossbones', 'clown_face', 'japanese_ogre',
      'japanese_goblin', 'ghost', 'alien', 'space_invader', 'robot',
      'poop', 'see_no_evil', 'hear_no_evil', 'speak_no_evil',
    ],
  ),
  EmojiCategory(
    name: 'Gestures & Body',
    icon: Icons.back_hand_outlined,
    shortcodes: [
      'wave', 'raised_back_of_hand', 'raised_hand_with_fingers_splayed',
      'hand', 'vulcan_salute', 'ok_hand', 'pinched_fingers',
      'pinching_hand', 'v', 'crossed_fingers', 'love_you_gesture',
      'metal', 'call_me_hand', 'point_left', 'point_right',
      'point_up_2', 'middle_finger', 'point_down', 'point_up',
      '+1', '-1', 'fist_raised', 'fist_oncoming', 'fist_left',
      'fist_right', 'clap', 'raised_hands', 'open_hands',
      'palms_up_together', 'handshake', 'pray', 'writing_hand',
      'nail_care', 'selfie', 'muscle', 'mechanical_arm',
      'mechanical_leg', 'leg', 'foot', 'ear', 'nose',
      'brain', 'anatomical_heart', 'lungs', 'tooth', 'bone',
      'eyes', 'eye', 'tongue', 'lips',
    ],
  ),
  EmojiCategory(
    name: 'Hearts & Symbols',
    icon: Icons.favorite_outline,
    shortcodes: [
      'heart', 'orange_heart', 'yellow_heart', 'green_heart',
      'blue_heart', 'purple_heart', 'black_heart', 'brown_heart',
      'white_heart', 'broken_heart', 'heart_exclamation', 'two_hearts',
      'revolving_hearts', 'heartbeat', 'heartpulse', 'sparkling_heart',
      'cupid', 'gift_heart', 'heart_decoration', 'peace_symbol',
      'cross', 'star_and_crescent', 'om', 'star_of_david',
      'six_pointed_star', 'menorah', 'yin_yang', 'orthodox_cross',
      'atom_symbol', 'infinity', 'recycle', 'fleur_de_lis',
      'beginner', 'warning', 'no_entry_sign', 'no_entry',
      'bangbang', 'interrobang', 'question', 'grey_question',
      'grey_exclamation', 'exclamation', 'heavy_check_mark', 'x',
      'sparkle', 'eight_spoked_asterisk', 'heavy_plus_sign',
      'heavy_minus_sign', 'heavy_division_sign', 'heavy_multiplication_x',
      'hash', 'keycap_star', '100', 'repeat',
    ],
  ),
  EmojiCategory(
    name: 'Animals & Nature',
    icon: Icons.pets_outlined,
    shortcodes: [
      'dog', 'cat', 'mouse', 'hamster', 'rabbit', 'fox_face',
      'bear', 'panda_face', 'koala', 'tiger', 'lion',
      'cow', 'pig', 'frog', 'monkey_face', 'gorilla',
      'orangutan', 'elephant', 'rhinoceros', 'hippopotamus',
      'giraffe', 'zebra', 'horse', 'unicorn',
      'bee', 'bug', 'butterfly', 'snail', 'lady_beetle',
      'ant', 'cricket', 'spider', 'scorpion', 'mosquito',
      'turtle', 'snake', 'lizard', 'dragon_face', 'dragon',
      'sauropod', 't_rex', 'whale', 'dolphin', 'fish',
      'tropical_fish', 'blowfish', 'shark', 'octopus', 'shell',
      'bouquet', 'cherry_blossom', 'tulip', 'rose', 'sunflower',
      'blossom', 'hibiscus', 'seedling', 'evergreen_tree',
      'deciduous_tree', 'palm_tree', 'cactus', 'fallen_leaf',
      'maple_leaf', 'leaves', 'mushroom', 'four_leaf_clover',
    ],
  ),
  EmojiCategory(
    name: 'Food & Drink',
    icon: Icons.restaurant_outlined,
    shortcodes: [
      'apple', 'green_apple', 'pear', 'tangerine', 'lemon',
      'banana', 'watermelon', 'grapes', 'strawberry', 'blueberries',
      'melon', 'cherries', 'peach', 'mango', 'pineapple',
      'coconut', 'kiwi_fruit', 'tomato', 'avocado', 'eggplant',
      'potato', 'carrot', 'corn', 'hot_pepper', 'broccoli',
      'garlic', 'onion', 'peanuts', 'bread', 'croissant',
      'baguette_bread', 'pretzel', 'bagel', 'pancakes', 'waffle',
      'cheese', 'egg', 'cooking', 'bacon', 'hamburger',
      'fries', 'pizza', 'hotdog', 'sandwich', 'taco',
      'burrito', 'popcorn', 'sushi', 'ramen', 'stew',
      'curry', 'bento', 'rice_ball', 'rice', 'spaghetti',
      'cake', 'birthday', 'pie', 'cupcake', 'ice_cream',
      'doughnut', 'cookie', 'chocolate_bar', 'candy', 'lollipop',
      'coffee', 'tea', 'beer', 'beers', 'clinking_glasses',
      'wine_glass', 'cocktail', 'tropical_drink', 'cup_with_straw',
      'bubble_tea', 'milk_glass', 'juice_box',
    ],
  ),
  EmojiCategory(
    name: 'Activities',
    icon: Icons.sports_soccer_outlined,
    shortcodes: [
      'soccer', 'basketball', 'football', 'baseball', 'softball',
      'tennis', 'volleyball', 'rugby_football', 'flying_disc',
      'golf', 'ping_pong', 'badminton', 'ice_hockey',
      'field_hockey', 'lacrosse', 'cricket_game', 'boomerang',
      'boxing_glove', 'martial_arts_uniform', 'goal_net', 'ice_skate',
      'fishing_pole_and_fish', 'diving_mask', 'running_shirt_with_sash',
      'ski', 'sled', 'curling_stone', 'dart', 'bowling',
      'video_game', 'joystick', 'chess_pawn', 'jigsaw',
      'slot_machine', 'game_die', 'performing_arts',
      'framed_picture', 'art', 'thread', 'sewing_needle', 'yarn',
      'knot', 'guitar', 'violin', 'saxophone', 'trumpet',
      'drum', 'microphone', 'headphones', 'musical_note', 'notes',
      'musical_score', 'musical_keyboard', 'banjo', 'cinema',
      'clapper', 'tv', 'camera', 'camera_flash', 'trophy',
      'medal_sports', 'medal_military', 'first_place_medal',
      'second_place_medal', 'third_place_medal',
    ],
  ),
  EmojiCategory(
    name: 'Travel & Places',
    icon: Icons.flight_outlined,
    shortcodes: [
      'car', 'taxi', 'blue_car', 'bus', 'trolleybus',
      'racing_car', 'police_car', 'ambulance', 'fire_engine',
      'minibus', 'truck', 'articulated_lorry', 'tractor',
      'kick_scooter', 'motorcycle', 'bike', 'motor_scooter',
      'rotating_light', 'helicopter', 'airplane', 'small_airplane',
      'rocket', 'flying_saucer', 'ship', 'speedboat', 'sailboat',
      'canoe', 'anchor', 'fuelpump', 'construction',
      'vertical_traffic_light', 'traffic_light', 'bus_stop',
      'railway_car', 'bullettrain_side', 'bullettrain_front',
      'train2', 'metro', 'light_rail', 'station', 'tram',
      'monorail', 'mountain_railway', 'steam_locomotive',
      'house', 'house_with_garden', 'office', 'post_office',
      'hospital', 'bank', 'hotel', 'school', 'church',
      'mosque', 'synagogue', 'stadium', 'factory',
      'japanese_castle', 'european_castle', 'wedding',
      'tokyo_tower', 'statue_of_liberty', 'sunrise_over_mountains',
      'sunrise', 'city_sunset', 'night_with_stars',
      'milky_way', 'bridge_at_night', 'rainbow', 'ocean',
      'volcano', 'earth_africa', 'earth_americas', 'earth_asia',
      'globe_with_meridians', 'world_map', 'compass',
    ],
  ),
  EmojiCategory(
    name: 'Objects',
    icon: Icons.lightbulb_outline,
    shortcodes: [
      'watch', 'mobile_phone', 'calling', 'computer', 'keyboard',
      'desktop_computer', 'printer', 'computer_mouse', 'trackball',
      'minidisc', 'floppy_disk', 'cd', 'dvd', 'battery',
      'electric_plug', 'bulb', 'flashlight', 'candle', 'fire_extinguisher',
      'wastebasket', 'money_with_wings', 'dollar', 'yen', 'euro',
      'pound', 'gem', 'ring', 'crown', 'lipstick',
      'eyeglasses', 'dark_sunglasses', 'necktie', 'shirt',
      'jeans', 'dress', 'kimono', 'bikini', 'high_heel',
      'sandal', 'boot', 'mans_shoe', 'athletic_shoe',
      'hiking_boot', 'womans_flat_shoe', 'socks', 'gloves',
      'scarf', 'tophat', 'mortar_board', 'billed_cap',
      'rescue_worker_helmet', 'prayer_beads', 'mag', 'mag_right',
      'lock', 'unlock', 'key', 'old_key', 'hammer',
      'axe', 'pick', 'hammer_and_pick', 'hammer_and_wrench',
      'dagger', 'crossed_swords', 'bomb', 'boomerang',
      'bow_and_arrow', 'shield', 'wrench', 'screwdriver',
      'nut_and_bolt', 'gear', 'clamp', 'balance_scale',
      'link', 'chains', 'hook', 'toolbox', 'magnet',
      'alembic', 'test_tube', 'petri_dish', 'dna', 'microscope',
      'telescope', 'satellite', 'syringe', 'drop_of_blood',
      'pill', 'adhesive_bandage', 'stethoscope',
    ],
  ),
  EmojiCategory(
    name: 'Flags',
    icon: Icons.flag_outlined,
    shortcodes: [
      'checkered_flag', 'triangular_flag_on_post', 'crossed_flags',
      'black_flag', 'white_flag', 'rainbow_flag', 'transgender_flag',
      'pirate_flag', 'flag_ac', 'flag_ad', 'flag_ae', 'flag_af',
      'flag_ag', 'flag_ai', 'flag_al', 'flag_am', 'flag_ao', 'flag_aq',
      'flag_ar', 'flag_as', 'flag_at', 'flag_au', 'flag_aw', 'flag_ax',
      'flag_az', 'flag_ba', 'flag_bb', 'flag_bd', 'flag_be', 'flag_bf',
      'flag_bg', 'flag_bh', 'flag_bi', 'flag_bj', 'flag_bl', 'flag_bm',
      'flag_bn', 'flag_bo', 'flag_bq', 'flag_br', 'flag_bs', 'flag_bt',
      'flag_bv', 'flag_bw', 'flag_by', 'flag_bz', 'flag_ca', 'flag_cc',
      'flag_cd', 'flag_cf', 'flag_cg', 'flag_ch', 'flag_ci', 'flag_ck',
      'flag_cl', 'flag_cm', 'flag_cn', 'us', 'flag_gb', 'flag_de',
      'flag_fr', 'flag_es', 'flag_it', 'flag_jp', 'flag_kr', 'flag_ru',
      'flag_in', 'flag_mx', 'flag_za',
    ],
  ),
];

class DiscourseEmojiPicker extends StatefulWidget {
  final String serverUrl;
  final ValueChanged<String> onEmojiSelected;
  final double height;

  const DiscourseEmojiPicker({
    super.key,
    required this.serverUrl,
    required this.onEmojiSelected,
    this.height = 300,
  });

  @override
  State<DiscourseEmojiPicker> createState() => _DiscourseEmojiPickerState();
}

class _DiscourseEmojiPickerState extends State<DiscourseEmojiPicker> {
  int _selectedCategory = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<String>? _cachedEmojis;
  int _lastCategory = -1;
  String _lastQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _filteredEmojis {
    if (_selectedCategory == _lastCategory && _searchQuery == _lastQuery && _cachedEmojis != null) {
      return _cachedEmojis!;
    }
    _lastCategory = _selectedCategory;
    _lastQuery = _searchQuery;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      _cachedEmojis = emojiCategories
          .expand((c) => c.shortcodes)
          .where((s) => s.contains(q))
          .toList();
    } else {
      _cachedEmojis = emojiCategories[_selectedCategory].shortcodes;
    }
    return _cachedEmojis!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emojis = _filteredEmojis;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search emoji…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                ),
                style: theme.textTheme.bodySmall,
                onChanged: (v) {
                  setState(() => _searchQuery = v.trim());
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(0);
                  }
                },
              ),
            ),
          ),
          if (_searchQuery.isEmpty)
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: emojiCategories.length,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, index) {
                  final cat = emojiCategories[index];
                  final isSelected = index == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: IconButton(
                      onPressed: () {
                        setState(() => _selectedCategory = index);
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(0);
                        }
                      },
                      icon: Icon(
                        cat.icon,
                        size: 18,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: isSelected
                            ? theme.colorScheme.primaryContainer
                            : null,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                      tooltip: cat.name,
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(6),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                final shortcode = emojis[index];
                final url = '${widget.serverUrl}/images/emoji/twitter/$shortcode.png';
                return _EmojiCell(
                  shortcode: shortcode,
                  url: url,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onEmojiSelected(shortcode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiCell extends StatelessWidget {
  final String shortcode;
  final String url;
  final VoidCallback onTap;

  const _EmojiCell({
    required this.shortcode,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Tooltip(
        message: ':$shortcode:',
        waitDuration: const Duration(milliseconds: 500),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 28,
            height: 28,
            memCacheWidth: 56,
            memCacheHeight: 56,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => Center(
              child: Text(
                ':$shortcode:',
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> showEmojiPickerDialog({
  required BuildContext context,
  required String serverUrl,
  Offset? anchorPosition,
}) {
  final theme = Theme.of(context);
  final screenSize = MediaQuery.of(context).size;
  const pickerWidth = 360.0;
  const pickerHeight = 340.0;

  if (anchorPosition != null) {
    double left = anchorPosition.dx;
    double top = anchorPosition.dy;

    if (left + pickerWidth > screenSize.width) {
      left = screenSize.width - pickerWidth - 8;
    }
    if (left < 8) left = 8;
    if (top + pickerHeight > screenSize.height) {
      top = anchorPosition.dy - pickerHeight;
    }
    if (top < 8) top = 8;

    return showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              color: theme.colorScheme.surface,
              child: SizedBox(
                width: pickerWidth,
                height: pickerHeight,
                child: DiscourseEmojiPicker(
                  serverUrl: serverUrl,
                  height: pickerHeight,
                  onEmojiSelected: (emoji) => Navigator.pop(ctx, emoji),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: pickerWidth,
        height: pickerHeight,
        child: DiscourseEmojiPicker(
          serverUrl: serverUrl,
          height: pickerHeight,
          onEmojiSelected: (emoji) => Navigator.pop(ctx, emoji),
        ),
      ),
    ),
  );
}
