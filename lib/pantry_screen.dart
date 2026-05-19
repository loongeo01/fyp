import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:recipe_app/app_images.dart';
import 'package:recipe_app/ingredient_prices.dart';
import 'package:recipe_app/pantry_recipes_screen.dart';
import 'package:recipe_app/searchBar.dart';
import 'pantry_provider.dart';
import 'expiry_management_screen.dart';
import 'dart:async';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};
  Timer? _pressTimer;
  int _tickCount = 0;

  void _startContinuousUpdate(
    BuildContext context,
    String itemName,
    double baseChange, // Changed to double
  ) {
    // Initial single tap update
    context.read<PantryProvider>().updateQuantity(itemName, baseChange);
    _tickCount = 0;

    // Small delay (400ms) before rapid fire starts
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_pressTimer != null) return;
      _pressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) return;
        _tickCount++;

        // ACCELERATION LOGIC: Increases the amount added the longer they hold
        int multiplier = 1;
        if (_tickCount > 20) {
          multiplier = 10; // After 2 seconds, jump by 10s
        } else if (_tickCount > 10) {
          multiplier = 5; // After 1 second, jump by 5s
        }

        context.read<PantryProvider>().updateQuantity(
          itemName,
          baseChange * multiplier,
        );
      });
    });
  }

  void _stopContinuousUpdate() {
    _pressTimer?.cancel();
    _pressTimer = null;
    _tickCount = 0;
  }

  // --- Helper function to strip numbers from Firebase units ---
  String extractCleanUnit(String rawUnit) {
    return rawUnit.replaceAll(RegExp(r'\d+'), '').trim();
  }

  void _toggleSelection(String itemName) {
    setState(() {
      if (_selectedItems.contains(itemName)) {
        _selectedItems.remove(itemName);
        if (_selectedItems.isEmpty) _isSelectionMode = false;
      } else {
        _selectedItems.add(itemName);
      }
    });
  }

  void _deleteSelectedItems() {
    final provider = context.read<PantryProvider>();
    for (String item in _selectedItems) {
      provider.removeIngredient(item);
    }
    setState(() {
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawIngredients = context.watch<PantryProvider>().savedIngredients;
    final displayList = context.watch<PantryProvider>().filteredIngredients;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF191C1B)),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedItems.clear();
                }),
              )
            : null,
        title: Text(
          _isSelectionMode ? '${_selectedItems.length} Selected' : 'My Pantry',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isSelectionMode
                ? const Color(0xFF191C1B)
                : const Color(0xFF006E1C),
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: _isSelectionMode
            ? [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedItems.length == displayList.length) {
                        _selectedItems.clear();
                        _isSelectionMode = false;
                      } else {
                        _selectedItems.addAll(displayList.map((e) => e.key));
                      }
                    });
                  },
                  child: Text(
                    _selectedItems.length == displayList.length
                        ? "Unselect All"
                        : "Select All",
                    style: const TextStyle(
                      color: Color(0xFF006E1C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _selectedItems.isEmpty
                      ? null
                      : _deleteSelectedItems,
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: Column(
        children: [
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IngredientSearchBar(
                  hintText: "Search or add ingredients...",
                  onPlus: (String selection) {
                    context.read<PantryProvider>().addIngredient(selection);
                    context.read<PantryProvider>().updateSearch("");
                  },
                  onSearchChanged: (String typedText) {
                    context.read<PantryProvider>().updateSearch(typedText);
                  },
                ),
              ),
            ),
          Expanded(
            child: rawIngredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Your pantry is empty!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Type an ingredient above to add it.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : displayList.isEmpty
                ? Center(
                    child: Text(
                      "No matching ingredients found.",
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(
                      top: 16,
                      left: 20,
                      right: 20,
                      bottom: 100,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final entry = displayList[index];
                      final String itemName = entry.key;
                      final PantryItem pantryItem = entry.value;

                      return Dismissible(
                        key: Key(itemName),
                        direction: _isSelectionMode
                            ? DismissDirection.none
                            : DismissDirection.horizontal,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        secondaryBackground: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD78A1F),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.edit_calendar,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.endToStart) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExpiryManagementScreen(
                                  targetIngredient: itemName,
                                ),
                              ),
                            );
                            return false;
                          }
                          return true;
                        },
                        onDismissed: (direction) {
                          if (direction == DismissDirection.startToEnd) {
                            context.read<PantryProvider>().removeIngredient(
                              itemName,
                            );
                          }
                        },
                        child: _buildGridCard(context, itemName, pantryItem),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: rawIngredients.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: _isSelectionMode
                  ? (_selectedItems.isNotEmpty
                        ? const Color(0xFFD78A1F)
                        : Colors.grey)
                  : const Color(0xFF006E1C),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.menu_book, color: Colors.white, size: 28),
              onPressed: () {
                if (_isSelectionMode && _selectedItems.isEmpty) return;

                List<String> myIngredients = _isSelectionMode
                    ? _selectedItems.toList()
                    : rawIngredients.map((e) => e.key).toList();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PantryRecipesScreen(userIngredients: myIngredients),
                  ),
                );

                setState(() {
                  _isSelectionMode = false;
                  _selectedItems.clear();
                });
              },
            )
          : null,
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    String itemName,
    PantryItem pantryItem,
  ) {
    bool isSelected = _selectedItems.contains(itemName);

    DateTime? closestDate = pantryItem.expiryDates.isNotEmpty
        ? pantryItem.expiryDates.first
        : null;

    String expiryText = "";
    Color expiryColor = Colors.transparent;
    IconData expiryIcon = Icons.event_busy;

    if (closestDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiry = DateTime(
        closestDate.year,
        closestDate.month,
        closestDate.day,
      );
      final int daysLeft = expiry.difference(today).inDays;

      if (daysLeft < 0) {
        expiryText = "Expired";
        expiryColor = Colors.redAccent;
        expiryIcon = Icons.warning_amber_rounded;
      } else if (daysLeft == 0) {
        expiryText = "Today";
        expiryColor = Colors.redAccent;
        expiryIcon = Icons.error_outline;
      } else if (daysLeft <= 3) {
        expiryText = "${daysLeft}d left";
        expiryColor = Colors.redAccent;
        expiryIcon = Icons.error_outline;
      } else if (daysLeft <= 7) {
        expiryText = "${daysLeft}d left";
        expiryColor = const Color(0xFFD78A1F);
        expiryIcon = Icons.schedule;
      } else {
        expiryText = DateFormat('dd/MM').format(closestDate);
        expiryColor = const Color(0xFF006E1C);
        expiryIcon = Icons.check_circle_outline;
      }
    }

    String itemUnit = "";
    try {
      final masterList = context.read<PantryProvider>().masterIngredients;
      final match = masterList.firstWhere(
        (item) =>
            item['name'].toString().toUpperCase() == itemName.toUpperCase(),
      );
      itemUnit = match['unit']?.toString() ?? "";
    } catch (e) {
      itemUnit = "";
    }

    String displayUnit = itemUnit.isNotEmpty ? itemUnit : "pcs";

    return Stack(
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: const Color(0xFF006E1C), width: 3)
                : Border.all(color: Colors.transparent, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF142814).withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onLongPress: () {
                if (!_isSelectionMode) {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedItems.add(itemName);
                  });
                }
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(itemName);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          IngredientPrices(ingredientName: itemName),
                    ),
                  );
                }
              },
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(13),
                          ),
                          child: Builder(
                            builder: (context) {
                              String? imageUrl = context
                                  .read<PantryProvider>()
                                  .getImageUrl(itemName);
                              if (imageUrl != null && imageUrl.isNotEmpty) {
                                return CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.fitHeight,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF006E1C),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Image.asset(
                                        AppImages.getIngredientImage(itemName),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                );
                              } else {
                                return Image.asset(
                                  AppImages.getIngredientImage(itemName),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Padding(
                          // Reserve space for the taller stepper below
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 72),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF191C1B),
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (isSelected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF006E1C),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                  if (!_isSelectionMode)
                    Positioned(
                      bottom: 8,
                      left: 6,
                      right: 6,
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF006E1C).withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // --- MINUS BUTTON ---
                            Expanded(
                              child: GestureDetector(
                                onTap: () => context
                                    .read<PantryProvider>()
                                    .updateQuantity(
                                      itemName,
                                      -1.0,
                                    ), // Pass double
                                onLongPressStart: (_) => _startContinuousUpdate(
                                  context,
                                  itemName,
                                  -1.0, // Pass double
                                ),
                                onLongPressEnd: (_) => _stopContinuousUpdate(),
                                onLongPressCancel: () =>
                                    _stopContinuousUpdate(),
                                child: Container(
                                  color: Colors.transparent,
                                  child: const Center(
                                    child: Icon(
                                      Icons.remove,
                                      size: 26,
                                      color: Color(0xFF006E1C),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // --- INLINE EDITABLE QUANTITY ---
                            _InlineQuantityEditor(
                              itemName: itemName,
                              quantity: pantryItem.quantity
                                  .toDouble(), // Ensure passing a double
                              unit: extractCleanUnit(displayUnit),
                            ),

                            // --- PLUS BUTTON ---
                            Expanded(
                              child: GestureDetector(
                                onTap: () => context
                                    .read<PantryProvider>()
                                    .updateQuantity(
                                      itemName,
                                      1.0,
                                    ), // Pass double
                                onLongPressStart: (_) => _startContinuousUpdate(
                                  context,
                                  itemName,
                                  1.0, // Pass double
                                ),
                                onLongPressEnd: (_) => _stopContinuousUpdate(),
                                onLongPressCancel: () =>
                                    _stopContinuousUpdate(),
                                child: Container(
                                  color: Colors.transparent,
                                  child: const Center(
                                    child: Icon(
                                      Icons.add,
                                      size: 26,
                                      color: Color(0xFF006E1C),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        if (!isSelected && closestDate != null)
          Positioned(
            top: -10,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: expiryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: expiryColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(expiryIcon, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    expiryText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InlineQuantityEditor extends StatefulWidget {
  final String itemName;
  final double quantity; // Changed to double
  final String unit;

  const _InlineQuantityEditor({
    required this.itemName,
    required this.quantity,
    required this.unit,
  });

  @override
  State<_InlineQuantityEditor> createState() => _InlineQuantityEditorState();
}

class _InlineQuantityEditorState extends State<_InlineQuantityEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  // Helper to drop ".0" if the number is whole (e.g., 2.0 -> "2")
  String get formattedQuantity {
    return widget.quantity == widget.quantity.truncateToDouble()
        ? widget.quantity.toInt().toString()
        : widget.quantity.toString();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _commitEdit();
      }
    });
  }

  @override
  void didUpdateWidget(_InlineQuantityEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep display in sync when +/- buttons change quantity externally
    if (!_isEditing) {
      _controller.text = formattedQuantity;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = formattedQuantity;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _commitEdit() {
    // Switched to double.tryParse to allow decimals
    final double? newQty = double.tryParse(_controller.text.trim());
    if (newQty != null && newQty >= 0) {
      final double diff = newQty - widget.quantity;
      if (diff != 0) {
        context.read<PantryProvider>().updateQuantity(widget.itemName, diff);
      }
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return SizedBox(
        width: 80,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ), // Enable decimal keyboard
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF191C1B),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          onSubmitted: (_) => _commitEdit(),
        ),
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Text(
          "$formattedQuantity ${widget.unit}", // Uses the clean formatter
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF191C1B),
          ),
        ),
      ),
    );
  }
}
