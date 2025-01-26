import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../common/tools/flash.dart';
import '../../data/boxes.dart';
import '../../frameworks/frameworks.dart';
import '../../models/entities/product.dart';
import '../../services/services.dart';

class BulkOrderForm extends StatefulWidget {
  @override
  _BulkOrderFormState createState() => _BulkOrderFormState();
}

class _BulkOrderFormState extends State<BulkOrderForm> {
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedProducts = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  int _minQueryLength = 3;
  bool _searchPerformed = false;

  void _saveToPurchaseList() {
    // setState(() {
    //   _purchaseList.addAll(_selectedProducts);
    // });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Products saved to the Purchase List!')),
    );
  }

  Future<void> _searchProducts(String query) async {
    if (query.length < _minQueryLength || query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
        'https://negade.biz/wp-json/wc/v2/products?status=publish&skip_cache=1&page=1&per_page=50&sku=$query&consumer_key=ck_57bbbeaf937bc0edbb3cb833f385085aa5afb160&consumer_secret=cs_05ef541a0ea5a1d6b5eeb9aef3dabc804c44daa3');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
          _searchPerformed = true;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addToList(Product product) {
    int index = _selectedProducts.indexWhere((p) => p['id'] == product.id);

    if (index != -1) {
      setState(() {
        _selectedProducts[index]['quantity'] += 1;
      });
    } else {
      setState(() {
        _selectedProducts.add({
          'id': product.id,
          'sku': product.sku,
          'name': product.name,
          'price': product.price,
          'quantity': product.minQuantity,
          'moq': product.minQuantity
        });
      });
    }
  }

  void _updateQuantity(int index, int newQuantity) {
    setState(() {
      final product = _selectedProducts[index];
      final minQuantity = product['minQuantity'] ?? 1;

      if (newQuantity < minQuantity) {
        newQuantity =
            minQuantity; // Ensure quantity doesn't go below minQuantity
      }

      // Update the quantity in the selected product list
      _selectedProducts[index]['quantity'] = newQuantity;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
  }

  void _showCartOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: CartOverlay(
          key: ValueKey(_selectedProducts), // Force rebuild on state change
      selectedProducts: _selectedProducts,
      onSave: _saveToPurchaseList,
      onQuantityChange: (index, quantity) =>
          _updateQuantity(index, quantity),
      onRemove: (index) => _removeItem(index),
      onBulkAdd: () => _addBulkToCart(),  // Call the function here
    ),

    ),
    );
  }

  void _addBulkToCart([bool buyNow = false]) {
    for (var product in _selectedProducts) {
      Product parsedProduct = Product.fromJson(product);
      var quantity = product['quantity'] ?? 1;
      Services().widget.addToCart(
            context,
            parsedProduct,
            quantity,
            const AddToCartArgs(
              productVariation: null,
              mapAttribute: null,
              selectedComponents: null,
              selectedTiredPrice: null,
              tiredPrices: null,
              pwGiftCardInfo: null,
            ),
            buyNow,
            true,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bulk Order Form',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for Product',
                prefixIcon: Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _searchProducts,
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _searchResults.isNotEmpty
                    ? ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final productData = _searchResults[index];
                          final product = Product.fromJson(productData);
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(12),
                              title: Text(
                                product.name!,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                              subtitle: Text('Price: \$${product.price}'),
                              trailing: ElevatedButton(
                                onPressed: () => _addToList(product),
                                child: Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          _searchPerformed
                              ? 'No products found'
                              : 'Start searching for products',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ),
          ),
        ],
      ),
        floatingActionButton: _selectedProducts.isNotEmpty
            ? FloatingActionButton(
          onPressed: _showCartOverlay, // Call method correctly here
          backgroundColor: Colors.green,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.shopping_cart),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '${_selectedProducts.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        )
            : null,
    );
  }

  void _showMessage(String text, {bool isError = true}) {
    if (!mounted) {
      return;
    }
    FlashHelper.message(
      context,
      message: text,
      isError: isError,
    );
  }
}

class CartOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> selectedProducts;
  final VoidCallback onSave;
  final Function(int index, int quantity) onQuantityChange;
  final Function(int index) onRemove;
  final VoidCallback onBulkAdd;

  CartOverlay({
    required this.selectedProducts,
    required this.onSave,
    required this.onQuantityChange,
    required this.onRemove,
    required this.onBulkAdd,
    required ValueKey<List<Map<String, dynamic>>> key,
  });

  @override
  _CartOverlayState createState() => _CartOverlayState();
}

class _CartOverlayState extends State<CartOverlay> {
  late List<TextEditingController> _controllers;
  final _listNameController = TextEditingController(); // Controller for list name
  @override
  void initState() {
    super.initState();
    _controllers = widget.selectedProducts
        .map((product) =>
        TextEditingController(text: product['quantity'].toString()))
        .toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showMessage(String text, {bool isError = true}) {
    if (!mounted) {
      return;
    }
    FlashHelper.message(
      context,
      message: text,
      isError: isError,
    );
  }

  void _updateQuantity(int index, String newQuantity) {
    int newQ = int.tryParse(newQuantity) ?? 0;
    final moq = widget.selectedProducts[index]['moq'] ?? 1;

    if (newQ < moq) {
      newQ = moq;
    }

    setState(() {
      widget.selectedProducts[index]['quantity'] = newQ;
      _controllers[index].text = newQ.toString();
    });

    widget.onQuantityChange(index, newQ);
  }

  Future<void> _saveToPurchaseList(String listName) async {
    final userId = UserBox().userInfo?.id; // Assuming user is logged in
    final productIds = widget.selectedProducts.map((product) => product['id']).toList();

    final url = Uri.parse('https://negade.biz/wp-json/myplugin/v1/create-purchase-list');
    final body = json.encode({
      'user_id': userId,
      'list_name': listName,
      'product_ids': productIds,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 201) {
        widget.onSave();
        Navigator.pop(context);
        _showMessage('Purchase list saved successfully!', isError: false);
      } else {
        _showMessage('Failed to save purchase list. Please try again.', isError: true);
      }
    } catch (e) {
      _showMessage('Error saving purchase list: $e', isError: true);
    }
  }

  Future<void> _showListNameDialog() async {
    await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter List Name'),
          content: TextField(
            controller: _listNameController,
            decoration: const InputDecoration(hintText: 'Enter a name for the purchase list'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog without doing anything
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                String listName = _listNameController.text.trim();
                if (listName.isNotEmpty) {
                  _saveToPurchaseList(listName); // Call save with the list name
                } else {
                  _showMessage('Please enter a valid name for the list', isError: true);
                }
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 35, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 30, color: Colors.red),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text('Cart Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: widget.selectedProducts.length,
              itemBuilder: (context, index) {
                final product = widget.selectedProducts[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(product['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: Text('Price: \$${product['price']} | MOQ: ${product['moq']}'),
                    leading: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        widget.onRemove(index); // Notify the parent about the removal
                        setState(() {}); // Update the local UI immediately
                      },
                    ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.red),
                          onPressed: () {
                            int currentQuantity = widget.selectedProducts[index]['quantity'];
                            final moq = widget.selectedProducts[index]['moq'] ?? 1;
                            if (currentQuantity > moq) {
                              _updateQuantity(index, (currentQuantity - 1).toString());
                            }
                          },
                        ),
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: _controllers[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 0)),
                            onSubmitted: (value) {
                              int enteredQuantity = int.tryParse(value) ?? 0;
                              final moq = widget.selectedProducts[index]['moq'] ?? 1;
                              if (enteredQuantity < moq) {
                                enteredQuantity = moq;
                              }
                              _updateQuantity(index, enteredQuantity.toString());
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () {
                            int currentQuantity = widget.selectedProducts[index]['quantity'];
                            _updateQuantity(index, (currentQuantity + 1).toString());
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () async {
                  await _showListNameDialog();
                },
                child: const Text('Save to Purchase List'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20)),
              ),
              ElevatedButton(
                onPressed: widget.onBulkAdd,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20)),
                child: const Text('Add All to Cart'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

