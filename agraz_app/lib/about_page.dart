import 'package:flutter/material.dart';

class AboutTeamPage extends StatelessWidget {
  const AboutTeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('About Our Team'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Meet Our Team',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildTeamMember(
                context,
                'assets/images/vinayak.jpeg',
                'Vinayak Hegde',
                'A Data Science graduate with an MBA, has 21 years of experience in data science, the retail industry, and farmer engagement.',
              ),
              const SizedBox(height: 30),
              _buildTeamMember(
                context,
                'assets/images/sudir.jpeg',
                'Seetaram Hegde',
                'Masters in Economics, MBA. Having 17 years of experience as a Data Scientist, Proficient in AI / ML Modeling.',
              ),
              const SizedBox(height: 30),
              _buildTeamMember(
                context,
                'assets/images/narayan.jpg',
                'Narayan Bhat',
                'Masters in Data science, Having 19 years of experience as a Data Scientist, Software development',
              ),
              const SizedBox(height: 20),
              const Text(
                'We work together to bring you the best experience!',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMember(
    BuildContext context,
    String imagePath,
    String name,
    String description,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                imagePath,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
