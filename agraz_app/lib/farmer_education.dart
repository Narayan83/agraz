import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'l10n/app_l10n.dart';

class FarmerEducationPage extends StatelessWidget {
  const FarmerEducationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Arecanut Farming Guide')),
        centerTitle: true,
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 20),
            _buildCategorySection(context, 'Nursery & Planting', Icons.spa, [
              'Areca plant nursery guide',
              'How to plant arecanut',
              'How to start a new plantation',
              'Spacing and soil requirements',
            ]),
            SizedBox(height: 20),
            _buildCategorySection(
              context,
              'Processing Methods',
              Icons.agriculture,
              [
                'Arecanut processing techniques',
                'How to dry areca properly',
                'How to boil areca nuts',
                'Traditional vs modern processing',
              ],
            ),
            SizedBox(height: 20),
            _buildCategorySection(context, 'Pest & Disease', Icons.bug_report, [
              'Common areca pests',
              'Arecanut disease management',
              'Organic control methods',
              'Red palm weevil control',
            ]),
            SizedBox(height: 20),
            _buildCategorySection(context, 'Harvesting', Icons.forest, [
              'When to harvest arecanut',
              'Proper harvesting techniques',
              'Yield optimization',
              'Post-harvest handling',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Image.asset(
              'assets/images/logo.jpeg',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arecanut Cultivation Guide',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete guide for areca nut cultivation, processing and marketing',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> topics,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green[700], size: 28),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...topics.map((topic) => _buildArticleCard(context, topic)),
      ],
    );
  }

  Widget _buildArticleCard(BuildContext context, String title) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.green[100]!, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(title, style: TextStyle(fontSize: 16)),
        trailing: Icon(Icons.chevron_right, color: Colors.green[700]),
        onTap: () {
          _navigateToArticle(context, title);
        },
      ),
    );
  }

  void _navigateToArticle(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ArticleDetailPage(title: title)),
    );
  }
}

class ArticleDetailPage extends StatefulWidget {
  final String title;

  const ArticleDetailPage({super.key, required this.title});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  static const Map<String, String> _videoUrls = {
    'Areca plant nursery guide':
        'https://agrazllp.com/uploads/videos/VID_20260715_134450318.mp4',
    'How to plant arecanut':
        'https://agrazllp.com/uploads/videos/VID_20260715_135523794.mp4',
    'How to start a new plantation':
        'https://agrazllp.com/uploads/videos/VID_20260716_144113160.mp4',
    'Spacing and soil requirements':
        'https://agrazllp.com/uploads/videos/VID_20260716_144048763.mp4',
  };

  String? get _videoUrl => _videoUrls[widget.title];

  @override
  void initState() {
    super.initState();
    final url = _videoUrl;
    if (url != null) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..setVolume(0)
        ..initialize().then((_) {
          if (!mounted) return;
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: false,
            allowFullScreen: true,
            allowMuting: true,
            allowPlaybackSpeedChanging: true,
            showControlsOnInitialize: false,
            hideControlsTimer: const Duration(seconds: 3),
            aspectRatio: _videoController!.value.aspectRatio,
            placeholder: Center(
              child: CircularProgressIndicator(),
            ),
          );
          setState(() {});
        }).catchError((_) {
          _videoController?.dispose();
          _videoController = null;
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_videoUrl != null) ...[
              _buildVideoSection(),
              SizedBox(height: 16),
            ],
            Text(
              _getArticleContent(widget.title),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    final chewie = _chewieController;
    if (chewie == null || _videoController == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: chewie),
    );
  }

  String _getArticleContent(String title) {
    switch (title) {
      case 'Areca plant nursery guide':
        return _nurseryGuideContent;
      case 'How to plant arecanut':
        return _plantingContent;
      case 'How to start a new plantation':
        return _newPlantationContent;
      case 'Spacing and soil requirements':
        return _spacingSoilContent;
      case 'How to dry areca properly':
        return 'Drying process details...';
      // Add cases for all your articles
      default:
        return 'Detailed content for $title will appear here';
    }
  }

  static const String _nurseryGuideContent =
      'SELECTING SEED NUTS\n\n'
      '1. Choose nuts from high-yielding, healthy palms that are 15 to 25 years old.\n'
      '2. Select fully ripe nuts that fall naturally from the tree.\n'
      '3. Pick medium-sized nuts that sink in water; floating nuts are usually low in vigour.\n'
      '4. Remove the husk (fibre) before sowing for faster and uniform germination.\n\n'
      'RAISING THE NURSERY\n\n'
      '1. Nursery beds should be made in partial shade, protected from direct sunlight and strong wind.\n'
      '2. Prepare raised beds about 1 m wide with good drainage and fill with soil mixed with sand and well-decomposed cow dung.\n'
      '3. Sow the nuts at a spacing of 15 cm x 15 cm with the germinating pore (eyebrow) facing upward.\n'
      '4. Cover the nuts with a thin layer of soil and mulch with dried leaves or paddy straw.\n'
      '5. Water regularly to keep the bed moist but not waterlogged.\n\n'
      'SECONDARY NURSERY (POLYTHENE BAG STAGE)\n\n'
      '1. After 3 to 4 months, transplant 3 to 4 leafed seedlings into poly bags (45 cm x 25 cm) filled with a mixture of topsoil, sand and compost.\n'
      '2. Keep the bags under 50% shade and water twice a day during summer.\n'
      '3. Apply a little fertilizer such as 10 g of ammonium sulphate per bag after the seedling has established.\n'
      '4. Seedlings are ready for field planting when they have 5 to 6 leaves and are 12 to 18 months old.\n\n'
      'TIPS FOR GOOD SEEDLINGS\n\n'
      '- Use seedlings from reliable nurseries or certified seed gardens.\n'
      '- Reject stunted, diseased or insect-damaged seedlings at the nursery stage itself.\n'
      '- Regular weeding, disease and pest checks keep the nursery healthy.';

  static const String _plantingContent =
      'BEST TIME TO PLANT\n\n'
      'The ideal planting season is from May to July, just before or during the monsoon, so that the young plants get enough moisture to establish. In areas with assured irrigation, planting can also be done during September to October.\n\n'
      'PIT PREPARATION\n\n'
      '1. Dig pits of 90 cm x 90 cm x 90 cm (about 3 ft x 3 ft x 3 ft) one to two months before planting.\n'
      '2. Leave the pits open so that sunlight and rain can disinfect the soil.\n'
      '3. At the time of planting, refill the pits with topsoil mixed with 10 to 15 kg of well-decomposed farmyard manure and 1 kg of neem cake.\n'
      '4. Add 250 g of rock phosphate and a little bone meal for root development.\n\n'
      'PLANTING THE SEEDLING\n\n'
      '1. Remove the seedling from the poly bag carefully without disturbing the root ball.\n'
      '2. Place it in the centre of the pit at the same depth it was growing in the bag.\n'
      '3. Press the soil gently around the base to remove air pockets.\n'
      '4. Irrigate immediately after planting, and repeat watering every 4 to 5 days during dry periods.\n'
      '5. Provide shade and protect young plants from direct sunlight and wind.\n\n'
      'AFTER CARE\n\n'
      '1. Mulch the base of each plant with dried leaves or straw to conserve moisture.\n'
      '2. Plant shade trees or catch crops like banana and pineapple between rows in the first few years.\n'
      '3. Stake the plants if needed and keep the area weed-free.\n'
      '4. Apply fertilizer in two split doses - one at the beginning and one at the end of the monsoon.';

  static const String _newPlantationContent =
      'SELECTING THE LAND\n\n'
      'Arecanut grows best in deep, well-drained soils with a pH of 5.0 to 7.5. The plantation should have a good water source, be protected from strong winds, and have proper drainage to avoid waterlogging during heavy rain.\n\n'
      'LAYOUT AND MARKING\n\n'
      '1. Clear the land of weeds, bushes and stumps well before planting.\n'
      '2. Plough and level the field and mark the planting points using the recommended spacing (usually 2.7 m x 2.7 m for square planting).\n'
      '3. For hilly areas, plant along contours and make trenches to check soil erosion.\n\n'
      'PLANTING PLAN AND SHADE MANAGEMENT\n\n'
      '1. Arecanut requires partial shade in the early years. Plant tall-growing shade trees such as banana, Dadap (Erythrina), or Silver oak 2 to 3 months before transplanting areca seedlings.\n'
      '2. Arrange the planting in an east-west direction where possible for better light distribution.\n'
      '3. Remove shade gradually as the palms grow; keep about 50% shade during the first 3 to 4 years.\n\n'
      'BUDGET AND PLANNING\n\n'
      '1. Plan the number of palms per acre: about 500 palms per acre at 2.7 m x 2.7 m spacing.\n'
      '2. Include the cost of seedlings, manure, labour, fencing and irrigation in your budget.\n'
      '3. Arecanut starts bearing from the 5th to 7th year and reaches full bearing by the 10th to 12th year, so plan your inter-crops and income sources for the early years.\n\n'
      'IRRIGATION PLANNING\n\n'
      'Drip irrigation is highly recommended as it saves water and gives uniform growth. Basin irrigation every 5 to 7 days in summer is also suitable where water is sufficient.';

  static const String _spacingSoilContent =
      'SOIL REQUIREMENTS\n\n'
      '1. Arecanut prefers deep, well-drained, laterite or alluvial soils rich in organic matter.\n'
      '2. Ideal soil pH is 5.0 to 7.5; slightly acidic soil is best.\n'
      '3. Avoid shallow, gravelly, sandy or waterlogged soils.\n'
      '4. Soils should be well supplied with potassium; adequate organic matter improves root growth and yield.\n'
      '5. Conduct a soil test before planting and correct the pH and nutrient deficiencies accordingly.\n\n'
      'SPACING STANDARDS\n\n'
      '1. Square system: 2.7 m x 2.7 m - about 545 palms per acre (1350 per hectare).\n'
      '2. Triangle (hexagonal) system: 2.7 m x 2.7 m with staggered rows - about 625 palms per acre.\n'
      '3. For closely planted gardens in fertile soil, a spacing of 2.4 m x 2.4 m can be used but growth and yield per palm will be lower.\n'
      '4. Wider spacing (3 m x 3 m) is used in dry areas where irrigation is limited.\n\n'
      'WHY CORRECT SPACING MATTERS\n\n'
      '1. Correct spacing gives each palm enough sunlight, water and nutrients.\n'
      '2. Overcrowded palms compete with each other and produce smaller bunches and lower quality nuts.\n'
      '3. Wide spacing allows better air circulation, reducing the spread of leaf diseases.\n'
      '4. Proper spacing also makes harvesting, spraying and fertilizer application easier.\n\n'
      'SOIL MANAGEMENT\n\n'
      '1. Mulch the palm basins with dry leaves during summer to conserve moisture.\n'
      '2. Grow green manure crops or legume cover crops between rows.\n'
      '3. Apply 10 to 12 kg of farmyard manure or compost per palm every year.\n'
      '4. In heavy soils, ensure good drainage; in light soils, improve water-holding capacity with organic matter.';
}
