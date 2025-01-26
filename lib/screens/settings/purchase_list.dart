import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../data/boxes.dart';
import '../../frameworks/frameworks.dart';
import '../../models/entities/product.dart';
import '../../services/services.dart';
class PurchaseListPage extends StatefulWidget {
  @override
  _PurchaseListPageState createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends State<PurchaseListPage> {
  List<Map<String, dynamic>> purchaseList = [];
  bool isLoading = false;
  late final List<Map<String, dynamic>> selectedProducts;
  @override
  void initState() {
    super.initState();
    fetchPurchaseLists();
  }

  // Fetch data from the API
  Future<void> fetchPurchaseLists() async {
    setState(() {
      isLoading=true;
    });
    print("Fetching purchase lists...");
    var user_id=UserBox().userInfo?.id??'';
    final response = await http.get(Uri.parse('https://negade.biz/wp-json/myplugin/v1/purchase-lists/${user_id}'));

    if (response.statusCode == 200) {
      // Parse the response body and update the purchaseList
      List<dynamic> data = json.decode(response.body);
      if(data.isEmpty){
        return;
      } 
      print("Purchase lists fetched successfully: ${data}");
      setState(() {
        isLoading = false;
        purchaseList = data.map((item) {
          return {
            'list_id': item['list_id'],
            'name': item['name'],
            'created_at': item['created_at'],
            'updated_at': item['updated_at'],
          };
        }).toList();
      });
    } else {
      print("Failed to fetch purchase lists: ${response.statusCode}");
      // Handle errors if the request fails
      setState(() {
        isLoading = false;
      });
      throw Exception('Failed to load purchase lists');
    }
  }

  // Fetch items for a specific purchase list
  Future<List<Map<String, dynamic>>> fetchPurchaseListItems(int listId) async {
    print("Fetching items for purchase list ID: $listId");

    // Make the API request
    final response = await http.get(Uri.parse('https://negade.biz/wp-json/myplugin/v1/purchase-list-items/$listId'));

    // Check if the response status code is 200 (OK)
    if (response.statusCode == 200) {
      print("Response received: ${response.body}");
      try {
        // Parse the response body as JSON
        List<dynamic> data = json.decode(response.body);
        print("Product items fetched successfully: $data");

        // Return the data as is, using the original API response fields
        return data.map((item) {
          return {
            'id': item['id'],  // Keep the 'id' as it is
            'name': item['name'],  // Keep the 'name' as it is
            'slug': item['slug'],  // Keep the 'slug' as it is
            'permalink': item['permalink'],  // Keep the 'permalink' as it is
            'sku': item['sku'],  // Keep the 'sku' as it is
            'price': item['price'],  // Keep the 'price' as it is
            'regular_price': item['regular_price'],  // Keep the 'regular_price' as it is
            'sale_price': item['sale_price'],  // Keep the 'sale_price' as it is
            'stock_status': item['stock_status'],  // Keep the 'stock_status' as it is
            'categories': item['categories'],  // Keep the 'categories' as it is
            'images': item['images'],  // Keep the 'images' as it is
            'quantity': item['quantity'],  // Keep the 'quantity' as it is
            'description': item['description'],  // Keep the 'description' as it is
            'short_description': item['short_description'],  // Keep the 'short_description' as it is
            'created_at': item['created_at'],  // Keep the 'created_at' as it is
            'status': item['status'],  // Keep the 'status' as it is
          };
        }).toList();

      } catch (e) {
        print("Error parsing response: $e");
        throw Exception('Failed to parse product data');
      }
    } else {
      print("Failed to fetch product items: ${response.statusCode}");
      throw Exception('Failed to load purchase list items');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase List', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child:
            isLoading? Center(child: CircularProgressIndicator()) // Show loading spinner
            : purchaseList.isEmpty
            ? Center(
          child: Text(
            'No purchase list found.',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        )
            : ListView.builder(
          itemCount: purchaseList.length,
          itemBuilder: (context, index) {
            var order = purchaseList[index];
            return PurchaseCard(
              order: order,
              fetchItems: fetchPurchaseListItems, // Pass fetchItems function
            );
          },
        ),
      ),
    );
  }
}

class PurchaseCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final Future<List<Map<String, dynamic>>> Function(int) fetchItems; // Function to fetch items

  const PurchaseCard({Key? key, required this.order, required this.fetchItems}) : super(key: key);

  @override
  _PurchaseCardState createState() => _PurchaseCardState();
}

class _PurchaseCardState extends State<PurchaseCard> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];

  // Method to fetch and show the product details
  void _showProductDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      int listId = int.parse(widget.order['list_id'].toString());  // Explicitly parse list_id to int
      print("Calling fetchItems with list_id: $listId");
      // Fetch the items for the clicked purchase list using the correct list_id
      List<Map<String, dynamic>> products = await widget.fetchItems(listId);
      setState(() {
        _products = products;
        _isLoading = false;
      });

      // Show the product details dialog
      showDialog(
        context: context,
        builder: (context) => ProductDetailDialog(products: _products, isLoading: _isLoading),
      );
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print("Error fetching product details: $error");
      // Handle error (e.g., show a message to the user)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load product details')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 20.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 5,
      child: InkWell(
        onTap: _showProductDetails, // Trigger product details on tap
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.order['name'],
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 20.0,
                color: Colors.blueAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailDialog extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool isLoading;

  const ProductDetailDialog({Key? key, required this.products, required this.isLoading}) : super(key: key);

  // Function to add products to cart
  void _addToCart(BuildContext context) {
    // Iterate over the products and add them to the cart
    for (var product in products) {
      // Convert API product data into Product object
      Product parsedProduct = Product.fromJson(product);
      var quantity = int.parse(product['quantity'].toString());  // Default quantity is 1 if not provided

      // Call the addToCart service or method here
      Services().widget.addToCart(
        context,
        parsedProduct,  // Pass the parsed Product object
        quantity,  // Pass the quantity of the product
        const AddToCartArgs(
          productVariation: null,
          mapAttribute: null,
          selectedComponents: null,
          selectedTiredPrice: null,
          tiredPrices: null,
          pwGiftCardInfo: null,
        ),
        false,
        true,
      );
    }

    // Show a confirmation message after adding products to cart
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('All products from the purchase list have been added to the cart!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Product Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isLoading
              ? [Center(child: CircularProgressIndicator())]
              : products.map((product) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product['name'],
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Quantity: ${product['quantity']}',
                    style: TextStyle(fontSize: 14.0, color: Colors.grey),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
        // Add to Cart button
        TextButton(
          onPressed: () => _addToCart(context),  // Trigger add to cart functionality
          child: Text('Add to Cart'),
        ),
      ],
    );
  }
}

