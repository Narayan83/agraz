import 'package:flutter/material.dart';

class FarmerEducationPage extends StatelessWidget {
  const FarmerEducationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arecanut Farming Guide'),
        centerTitle: true,
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildCategorySection(context, 'Nursery & Planting', Icons.spa, [
              'Areca plant nursery guide',
              'How to plant arecanut',
              'How to start a new plantation',
              'Spacing and soil requirements',
            ]),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            _buildCategorySection(context, 'Pest & Disease', Icons.bug_report, [
              'Common areca pests',
              'Arecanut disease management',
              'Organic control methods',
              'Red palm weevil control',
            ]),
            const SizedBox(height: 20),
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
            color: Colors.green[200],
            alignment: Alignment.center,
            child: const Icon(Icons.eco, color: Colors.green, size: 40),
          ),
          const SizedBox(width: 16),
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
                const SizedBox(height: 4),
                const Text(
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
            const SizedBox(width: 8),
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
        const SizedBox(height: 12),
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
        title: Text(title, style: const TextStyle(fontSize: 16)),
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

class ArticleDetailPage extends StatelessWidget {
  final String title;

  const ArticleDetailPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _getArticleContent(title),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  String _getArticleContent(String title) {
    // Replace with your actual content
    switch (title) {
      case 'Areca plant nursery guide':
        return 'Nursery guide content...';
      case 'How to plant arecanut':
        return 'Planting instructions...';
      case 'How to dry areca properly':
        return 'Drying process details...';
      // Add cases for all your articles
      default:
        return 'Detailed content for $title will appear here';
    }
  }
}
