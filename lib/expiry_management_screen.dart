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
  final Set<String> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    if (widget.targetIngredient != null) {
      _expandedItems.add(widget.targetIngredient!);
    }
  }

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
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
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
        _expandedItems.add(itemName);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = context.watch<PantryProvider>().savedIngredients;

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
          "Freshness Tracker",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006E1C),
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF191C1B)),
      ),
      body: displayList.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              // We add 1 to the item count to make room for the header at the top
              itemCount: sortedList.length + 1,
              itemBuilder: (context, index) {
                // --- INDEX 0: THE HEADER (NOW SCROLLS AWAY!) ---
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF006E1C), Color(0xFF0A4F1A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF006E1C).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.kitchen,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Pantry Health",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Keep track of your ingredients so nothing goes to waste.",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // --- INDEX 1+: THE INGREDIENT LIST ---
                // We subtract 1 from the index so the list data matches up perfectly
                final entry = sortedList[index - 1];
                return _buildExpiryCard(
                  context,
                  entry.key,
                  entry.value,
                  _expandedItems.contains(entry.key),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.event_busy,
              size: 64,
              color: Color(0xFFBECAB9),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No items to track",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191C1B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add ingredients to your pantry first\nto start tracking their expiry dates.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6F7A6B),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
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
    DateTime? closestDate = dates.isNotEmpty ? dates.first : null;

    // Smart UI Data calculation
    String statusText = "No dates tracked";
    Color statusColor = Colors.grey.shade400;
    IconData statusIcon = Icons.help_outline;

    if (closestDate != null) {
      // Calculate midnight-to-midnight difference
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiry = DateTime(
        closestDate.year,
        closestDate.month,
        closestDate.day,
      );
      final int daysLeft = expiry.difference(today).inDays;

      if (daysLeft < 0) {
        statusText = "Expired";
        statusColor = Colors.redAccent;
        statusIcon = Icons.warning_amber_rounded;
      } else if (daysLeft == 0) {
        statusText = "Expires Today!";
        statusColor = Colors.redAccent;
        statusIcon = Icons.error_outline;
      } else if (daysLeft <= 3) {
        statusText = "Expires in $daysLeft days";
        statusColor = Colors.redAccent;
        statusIcon = Icons.error_outline;
      } else if (daysLeft <= 7) {
        statusText = "Expires in $daysLeft days";
        statusColor = const Color(0xFFD78A1F);
        statusIcon = Icons.schedule;
      } else {
        statusText = "Expires in $daysLeft days";
        statusColor = const Color(0xFF006E1C);
        statusIcon = Icons.check_circle_outline;
      }
    }

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
              ? statusColor.withOpacity(0.3)
              : Colors.grey.shade100,
          width: isExpanded ? 2 : 1,
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
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 56,
                      height: 56,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF191C1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // --- UPGRADED SMART BADGE ---
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sleek Action Button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF006E1C).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Color(0xFF006E1C),
                        size: 24,
                      ),
                      onPressed: () => _addOrEditDate(context, itemName),
                    ),
                  ),
                ],
              ),

              if (isExpanded && dates.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF2F4F2), thickness: 1.5),
                const SizedBox(height: 8),
                Column(
                  children: dates.map((date) {
                    bool isClosest = date == closestDate;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isClosest
                            ? statusColor.withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isClosest
                              ? statusColor.withOpacity(0.3)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isClosest
                                  ? statusColor.withOpacity(0.1)
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event,
                              size: 16,
                              color: isClosest
                                  ? statusColor
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(date),
                                style: TextStyle(
                                  fontWeight: isClosest
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 15,
                                  color: const Color(0xFF191C1B),
                                ),
                              ),
                              if (isClosest)
                                Text(
                                  "Tracking next expiry",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_calendar,
                              size: 20,
                              color: Color(0xFF6F7A6B),
                            ),
                            onPressed: () => _addOrEditDate(
                              context,
                              itemName,
                              oldDate: date,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => context
                                .read<PantryProvider>()
                                .removeExpiryDate(itemName, date),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
