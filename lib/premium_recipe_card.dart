import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:recipe_app/app_images.dart';
import 'package:recipe_app/recipe_detail_screen.dart';

class PremiumRecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const PremiumRecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    // 1. Smart Detection: Does this recipe have matching stats?
    bool hasMatchData =
        recipe.containsKey("matchCount") && recipe.containsKey("totalNeeded");
    bool isPerfectMatch = hasMatchData && recipe["missingCount"] == 0;
    double matchPercentage = hasMatchData
        ? (recipe["matchCount"] / recipe["totalNeeded"])
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPerfectMatch
              ? const Color(0xFF006E1C).withOpacity(0.3)
              : Colors.grey.shade100,
          width: isPerfectMatch ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPerfectMatch
                ? const Color(0xFF006E1C).withOpacity(0.05)
                : const Color(0xFF142814).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                // Note: If RecipeDetailScreen is in its own file, import it at the top instead!
                builder: (context) => RecipeDetailScreen(recipe: recipe),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: hasMatchData
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                // --- IMAGE AREA ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child:
                      (recipe["image_url"] != null &&
                          recipe["image_url"].toString().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: recipe["image_url"],
                          width: 90,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 90,
                            height: 100,
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
                          errorWidget: (context, url, error) => Image.asset(
                            AppImages.getRecipeImage(recipe["name"] ?? ""),
                            width: 90,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          AppImages.getRecipeImage(recipe["name"] ?? ""),
                          width: 90,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 16),

                // --- CONTENT AREA ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe["name"] ?? "Unknown Recipe",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1B),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Time & Difficulty
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Color(0xFF6F7A6B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe["time"] ?? "--",
                            style: const TextStyle(
                              color: Color(0xFF6F7A6B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: CircleAvatar(
                              radius: 2,
                              backgroundColor: Color(0xFFBECAB9),
                            ),
                          ),
                          Text(
                            recipe["difficulty"] ?? "N/A",
                            style: const TextStyle(
                              color: Color(0xFF6F7A6B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // --- DYNAMIC BOTTOM SECTION: Progress Bar OR Nothing ---
                      if (hasMatchData) ...[
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isPerfectMatch
                                      ? "Ready to Cook"
                                      : "You have ${recipe["matchCount"]}/${recipe["totalNeeded"]}",
                                  style: TextStyle(
                                    color: isPerfectMatch
                                        ? const Color(0xFF006E1C)
                                        : const Color(0xFFD78A1F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!isPerfectMatch)
                                  Text(
                                    "Missing ${recipe["missingCount"]}",
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: matchPercentage,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isPerfectMatch
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFFFB866),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // --- DYNAMIC CHEVRON: Only show if there's no progress bar ---
                if (!hasMatchData)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.chevron_right, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
