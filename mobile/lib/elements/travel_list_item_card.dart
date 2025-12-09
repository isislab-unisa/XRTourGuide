import 'package:flutter/material.dart';
import '../models/app_colors.dart';
import '../services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_state_service.dart';
import 'zlib_image.dart';


class TravelListItemCard extends ConsumerWidget {
  final String imagePath; // Path to the image asset
  final String title; // The title of the item
  final String description; // A short description of the item
  final double cardWidth; // The width of the card
  final VoidCallback? onTap; // Optional callback for when the card is tapped
  final double? height; // Optional height for the card
  final double? imageHeight; // Optional height for the image
  final bool fullWidth; // Whether the card should take full width
  final String? category; // Optional category text
  final double? rating; // Optional rating value
  final int? reviewCount; // Optional review count
  // final bool isFavorite; // Whether to show as favorite
  final String? creator;
  final String? lastEdited;
  final String? totViews;
  final int? tourId;


  const TravelListItemCard({
    Key? key,
    required this.tourId,
    required this.imagePath,
    required this.title,
    required this.description,
    required this.cardWidth,
    this.onTap,
    this.height,
    this.imageHeight,
    this.fullWidth = false,
    this.category,
    this.rating,
    this.reviewCount,
    this.creator,
    this.lastEdited,
    this.totViews,
    // this.isFavorite = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localStateService = ref.read(localStateServiceProvider);

    return FutureBuilder<bool>(
      future: localStateService.isTourCompleted(tourId!),
      builder: (context, snapshot) {
        final bool isCompleted = snapshot.data ?? false;
        print("TourId: $tourId, isCompleted: $isCompleted");
        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            // Use SizedBox to control the width of the card
            width: fullWidth ? double.infinity : cardWidth,
            height: height,
            child: Card(
              elevation: 3.0, // Shadow depth for the card
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  10.0,
                ), // Rounded corners for the card
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stack for the image with potential badge and favorite icon
                  Stack(
                    children: [
                      // Image with rounded corners
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10.0),
                        ), // Rounded top corners for the image
                        // child: Image.network(
                        //   // imagePath, // Use the imagePath parameter
                        //   "${ApiService.basicUrl}/stream_minio_resource/?tour=${tourId!}",
                        //   fit:
                        //       BoxFit
                        //           .cover, // Cover the available space, potentially cropping
                        //   width:
                        //       double
                        //           .infinity, // Make the image take the full width of the card
                        //   height:
                        //       imageHeight ??
                        //       (height != null ? height! * 0.7 : null),
                        // ),
                        child: ZlibImage(
                          url:
                              "${ApiService.basicUrl}/stream_minio_resource/?tour=${tourId!}",
                          width: double.infinity,
                          height:
                              imageHeight ?? (height != null ? height! * 0.7 : null),
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (isCompleted)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
        
                  // Padding around the text content.
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category and rating row (if provided)
                        if (category != null || rating != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Category
                                if (category != null)
                                  Text(
                                    category!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
        
                                // Rating
                                if (rating != null)
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${rating!.toStringAsFixed(1).toString()}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (reviewCount != null)
                                            Text(
                                              ' ($reviewCount)',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          SizedBox(width: 8),
                                          const Icon(
                                            Icons.remove_red_eye,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                          Text(
                                            totViews ?? '0',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textSecondary,
                                            ),
                                          )
        
                                        ],
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
        
                        // Title of the list item.
                        Text(
                          title, // Use the title parameter
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
        
                        // Short description of the list item.
                        Text(
                          description, // Use the description parameter
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1, // Limit the description to one line
                          overflow:
                              TextOverflow.ellipsis, // Add "..." if text overflows
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}
