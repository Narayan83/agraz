import 'package:flutter/material.dart';

class ServiceListingPage extends StatefulWidget {
  const ServiceListingPage({super.key});

  @override
  _ServiceListingPageState createState() => _ServiceListingPageState();
}

class _ServiceListingPageState extends State<ServiceListingPage> {
  final List<ServiceCategory> categories = [
    ServiceCategory(
      name: "Agri Services",
      subCategories: [
        ServiceSubCategory(
          name: "Tractor",
          businesses: [
            Business(
              name: "Tractor (Hourly Basis) ",
              image: "assets/images/1Agri.jpg",
              phone: "+919886756985",
              rating: 4.5,
            ),
            Business(
              name: "Harvesting Areca",
              image: "assets/images/2Agri.jpg",
              phone: "+949886756985",
              rating: 4.2,
            ),
          ],
        ),
        ServiceSubCategory(
          name: "Areca Fiber Doti Labours",
          businesses: [
            Business(
              name: "Areca Fiber Doti Labours",
              image: "assets/images/4Agri.jpg",
              phone: "+919886756885",
              rating: 4.7,
            ),
          ],
        ),
      ],
    ),
    ServiceCategory(
      name: "Areca Bidders",
      subCategories: [
        ServiceSubCategory(
          name: "Areca Bidders",
          businesses: [
            Business(
              name: "Areca Bidders",
              image: "assets/images/5Agri.jpg",
              phone: "+9195865895",
              rating: 4.8,
            ),
            Business(
              name: "Financial Services",
              image: "assets/images/6Agri.jpg",
              phone: "+91958658958",
              rating: 4.9,
            ),
          ],
        ),
      ],
    ),
    ServiceCategory(
      name: "Paddy Cutting Labour",
      subCategories: [
        ServiceSubCategory(
          name: "Paddy Cutting Labour",
          businesses: [
            Business(
              name: "Paddy Cutting Labour",
              image: "assets/images/8Agri.jpg",
              phone: "+91958658958",
              rating: 4.9,
            ),
            Business(
              name: "Coconut Labour",
              image: "assets/images/7Agri.jpg",
              phone: "+9195865895",
              rating: 4.8,
            ),
          ],
        ),
      ],
    ),
  ];

  final List<String> ads = [
    "assets/ad1.jpg",
    "assets/ad2.jpg",
    "assets/ad3.jpg",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Service Providers'),
        actions: [IconButton(icon: Icon(Icons.search), onPressed: () {})],
      ),
      body: ListView.builder(
        itemCount: categories.length * 2 - 1,
        itemBuilder: (context, index) {
          if (index.isOdd) {
            // Return ad between categories
            return AdBanner(adImage: ads[(index ~/ 2) % ads.length]);
          }
          final categoryIndex = index ~/ 2;
          return ServiceCategorySection(category: categories[categoryIndex]);
        },
      ),
    );
  }
}

class ServiceCategory {
  final String name;
  final List<ServiceSubCategory> subCategories;

  ServiceCategory({required this.name, required this.subCategories});
}

class ServiceSubCategory {
  final String name;
  final List<Business> businesses;

  ServiceSubCategory({required this.name, required this.businesses});
}

class Business {
  final String name;
  final String image;
  final String phone;
  final double rating;

  Business({
    required this.name,
    required this.image,
    required this.phone,
    required this.rating,
  });
}

class ServiceCategorySection extends StatelessWidget {
  final ServiceCategory category;

  const ServiceCategorySection({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            category.name,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        ...category.subCategories.expand((subCategory) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                subCategory.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
              ),
            ),
            ...subCategory.businesses.map(
              (business) => BusinessCard(business: business),
            ),
          ];
        }),
      ],
    );
  }
}

class BusinessCard extends StatelessWidget {
  final Business business;

  const BusinessCard({super.key, required this.business});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 2,
      child: Column(
        children: [
          // Business Image (placeholder with color)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              image: DecorationImage(
                image: AssetImage(business.image),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      business.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        Text(
                          business.rating.toString(),
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(business.phone, style: TextStyle(fontSize: 16)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        // Implement call functionality
                      },
                      child: Text('CALL'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Implement booking functionality
                      },
                      child: Text('BOOK NOW'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdBanner extends StatelessWidget {
  final String adImage;

  const AdBanner({super.key, required this.adImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(image: AssetImage(adImage), fit: BoxFit.cover),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(8),
          color: Colors.black54,
          child: Text(
            'Special Offer Today Only!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
