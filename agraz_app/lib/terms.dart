import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy & Terms'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.security, size: 50, color: Colors.green),
            ),
            const SizedBox(height: 20),
            const Text(
              'AgRaz Privacy Policy, Data Security & Ownership',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'At AgRaz, we value your trust and are committed to protecting your personal information and respecting your privacy. This section outlines how we collect, use, store, and protect your data when you use our mobile and web platforms.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Section 1
            _buildSectionTitle('1. Information We Collect'),
            const Text(
              'When you register and use the AgRaz app, we collect various types of information to help us deliver personalized agricultural services and improve your experience. This includes:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              'Personal information (name, phone number, location, farm size, language preference)',
            ),
            _buildBulletPoint(
              'Usage data (interactions with app features, time spent, login patterns, device type)',
            ),
            _buildBulletPoint(
              'Agricultural data (crop types, expenses, forecasts, trading records, financial inputs)',
            ),
            const SizedBox(height: 16),

            // Section 2
            _buildSectionTitle('2. How We Use Your Data'),
            const Text(
              'We use the information collected to provide and enhance AgRaz services:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              'Deliver customized features like crop forecasting and yield prediction',
            ),
            _buildBulletPoint(
              'Provide market price analysis and farming expense management',
            ),
            _buildBulletPoint(
              'Connect you with relevant buyers, sellers, vendors, or financial service providers',
            ),
            _buildBulletPoint(
              'Send personalized alerts, reminders, product suggestions, or educational content',
            ),
            const SizedBox(height: 8),
            const Text(
              'Importantly, AgRaz does not sell, trade, or rent your personal information to any third parties. We may share limited data with trusted partners only when required to deliver specific services, and always under strict confidentiality agreements.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Section 3
            _buildSectionTitle('3. Data Security and Protection Measures'),
            const Text(
              'We take data protection seriously and use industry-standard security technologies:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              'All data is encrypted using Secure Socket Layer (SSL) technology',
            ),
            _buildBulletPoint(
              'Servers hosted on Amazon Web Services (AWS) with robust cloud security',
            ),
            _buildBulletPoint(
              'Role-based access control and continuous monitoring',
            ),
            _buildBulletPoint(
              'Regular audits to identify and fix potential vulnerabilities',
            ),
            const SizedBox(height: 8),
            const Text(
              'While no digital platform can guarantee 100% security, AgRaz follows best practices to minimize risks and safeguard your data.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Section 4
            _buildSectionTitle(
              '4. Ownership of Information and Intellectual Property',
            ),
            const Text(
              'All content, features, source code, design, algorithms, and AI models used within the AgRaz app are the sole intellectual property of AgRaz. This includes:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint('Forecasts and price optimization tools'),
            _buildBulletPoint('Analytics dashboards and interfaces'),
            _buildBulletPoint('Logos and brand assets'),
            const SizedBox(height: 8),
            const Text(
              'While AgRaz retains full ownership of the platform, you retain ownership rights of your personal and farm-related data. By using our app, you grant AgRaz a non-exclusive, royalty-free license to process and analyze this data to provide services.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Section 5
            _buildSectionTitle('5. Data Retention and Deletion'),
            const Text(
              'We retain user data for as long as necessary to provide our services or as required by law. You can request data deletion by:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint('Emailing us at privacy@agraz.in'),
            _buildBulletPoint('Using the in-app support section'),
            const SizedBox(height: 16),

            // Section 6
            _buildSectionTitle('6. Use of Third-Party Services'),
            const Text(
              'AgRaz may integrate with third-party services such as payment gateways or banking APIs. These services operate under their own privacy policies. AgRaz is not responsible for the actions or data handling practices of third-party platforms outside our control.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Section 7
            _buildSectionTitle('7. Your Rights as a User'),
            const Text(
              'You have full rights over your personal information, including the right to:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildBulletPoint('Request access to your information'),
            _buildBulletPoint('Correct or update inaccurate details'),
            _buildBulletPoint('Delete your data from our system'),
            _buildBulletPoint('Object to or restrict certain data processing'),
            _buildBulletPoint('Withdraw consent at any time'),
            const SizedBox(height: 8),
            const Text(
              'To exercise these rights, contact us at agraz.solutions@gmail.com or call our support helpline.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            const Text(
              'At AgRaz, your privacy and data security are at the core of our platform. We aim to earn and maintain your trust by handling your information responsibly and transparently.',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
