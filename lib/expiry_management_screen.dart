import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:recipe_app/app_images.dart';
import 'pantry_provider.dart';

class ExpiryManagementScreen extends StatefulWidget {
  final String? targetIngredient;
  const ExpiryManagementScreen({super.key, this.targetIngredient});

  @override
  State<ExpiryManagementScreen> createState() => _ExpiryManagementScreenState();
}

class _ExpiryManagementScreenState extends State<ExpiryManagementScreen> {
  // Keeps track of which ingredient cards are currently expanded
  final Set<String> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    // Auto-expand the item they swiped on
    if (widget.targetIngredient != null) {
      _expandedItems.add(widget.targetIngredient!);
    }
  }

  // Opens the beautiful material calendar
  void _addOrEditDate(
    BuildContext context,
    String itemName, {
    DateTime? oldDate,
  }) async {
    DateTime initialDate = oldDate ?? DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF006E1C),
              onPrimary: Colors.white,
              onSurface: Color(0xFF191C1B),
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      if (oldDate != null) {
        context.read<PantryProvider>().updateExpiryDate(
          itemName,
          oldDate,
          picked,
        );
      } else {
        context.read<PantryProvider>().addExpiryDate(itemName, picked);
      }
      setState(() {
        _expandedItems.add(itemName); // Auto-expand when a new date is added
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = context.watch<PantryProvider>().savedIngredients;

    // Sort so the ingredient they swiped on stays at the very top of the list
    List<MapEntry<String, PantryItem>> sortedList = List.from(displayList);
    if (widget.targetIngredient != null) {
      sortedList.sort((a, b) {
        if (a.key == widget.targetIngredient) return -1;
        if (b.key == widget.targetIngredient) return 1;
        return 0;
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          "Expiry Dates",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006E1C),
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF191C1B)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: sortedList.length,
        itemBuilder: (context, index) {
          final entry = sortedList[index];
          final String itemName = entry.key;
          final PantryItem pantryItem = entry.value;
          final bool isExpanded = _expandedItems.contains(itemName);

          return _buildExpiryCard(context, itemName, pantryItem, isExpanded);
        },
      ),
    );
  }

  Widget _buildExpiryCard(
    BuildContext context,
    String itemName,
    PantryItem pantryItem,
    bool isExpanded,
  ) {
    List<DateTime> dates = pantryItem.expiryDates;
    // Dates are pre-sorted by the provider, so index 0 is always the closest!
    DateTime? closestDate = dates.isNotEmpty ? dates.first : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF142814).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF006E1C).withOpacity(0.3)
              : Colors.grey.shade100,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedItems.remove(itemName);
            } else {
              _expandedItems.add(itemName);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TOP ROW: Image, Name, Add Button ---
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Builder(
                        builder: (context) {
                          String? imageUrl = context
                              .read<PantryProvider>()
                              .getImageUrl(itemName);
                          if (imageUrl != null && imageUrl.isNotEmpty) {
                            return CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Image.asset(
                                AppImages.getIngredientImage(itemName),
                                fit: BoxFit.cover,
                              ),
                            );
                          }
                          return Image.asset(
                            AppImages.getIngredientImage(itemName),
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFFD78A1F),
                      size: 32,
                    ), // Orange Add Button
                    onPressed: () => _addOrEditDate(context, itemName),
                  ),
                ],
              ),

              // --- BOTTOM ROW / EXPANDED SECTION ---
              if (dates.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    "No expiry dates added.",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                )
              else if (!isExpanded && closestDate != null)
                // Collapsed State: Just show the closest date
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 16,
                        color: Color(0xFFD78A1F),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Closest Expiry: ${DateFormat('dd MMM yyyy').format(closestDate)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD78A1F),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.expand_more, color: Colors.grey),
                    ],
                  ),
                )
              else if (isExpanded)
                // Expanded State: Show all dates with edit/delete actions
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: dates.map((date) {
                      bool isClosest = date == closestDate;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isClosest
                              ? const Color(0xFFD78A1F).withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isClosest
                                ? const Color(0xFFD78A1F).withOpacity(0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: isClosest
                                  ? const Color(0xFFD78A1F)
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM yyyy').format(date),
                              style: TextStyle(
                                fontWeight: isClosest
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isClosest
                                    ? const Color(0xFFD78A1F)
                                    : const Color(0xFF191C1B),
                              ),
                            ),
                            if (isClosest)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Text(
                                  "(Closest)",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFD78A1F),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            // Edit
                            InkWell(
                              onTap: () => _addOrEditDate(
                                context,
                                itemName,
                                oldDate: date,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Delete
                            InkWell(
                              onTap: () => context
                                  .read<PantryProvider>()
                                  .removeExpiryDate(itemName, date),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
