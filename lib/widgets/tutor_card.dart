import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tutor.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../screens/chat/chat_screen.dart';
import 'rating_stars.dart';

class TutorCard extends StatelessWidget {
  final Tutor tutor;
  final VoidCallback? onTap;
  final bool showChatButton;

  const TutorCard({
    super.key, 
    required this.tutor, 
    this.onTap,
    this.showChatButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(tutor.avatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tutor.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(tutor.subject, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    RatingStars(rating: tutor.rating, count: tutor.reviewCount),
                  ],
                ),
              ),
              Consumer<AuthService>(
                builder: (context, authService, _) {
                  final user = authService.currentUser;
                  final isStudent = user?.role == UserRole.student;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${tutor.hourlyRate.toStringAsFixed(0)} đ/giờ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF1E88E5))),
                      const SizedBox(height: 6),
                      if (showChatButton && isStudent)
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 20),
                          color: Colors.blue,
                          tooltip: 'Nhắn tin với gia sư',
                          onPressed: () {
                            // Tạo room ID nhất quán bằng cách sắp xếp IDs
                            final ids = [tutor.id, user!.id]..sort();
                            final roomId = '${ids[0]}-${ids[1]}';
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  roomId: roomId,
                                  title: 'Chat với ${tutor.name}',
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

