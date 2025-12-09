import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_refs.dart';
import '../../models/message.dart';
import '../../models/student.dart';
import '../chat/chat_screen.dart';

/// Màn hình danh sách chat cho admin - hiển thị tất cả học viên và gia sư để chat
class AdminChatListScreen extends StatefulWidget {
  static const routeName = '/admin-chat-list';
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  String _selectedTab = 'all'; // 'all', 'students', 'tutors'

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthService>().currentUser;
    if (admin == null || admin.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hỗ trợ')),
        body: const Center(child: Text('Chỉ dành cho admin')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỗ trợ người dùng'),
      ),
      body: Column(
        children: [
          // Tab bar để lọc học viên/ gia sư
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Tất cả',
                    isSelected: _selectedTab == 'all',
                    onTap: () => setState(() => _selectedTab = 'all'),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Học viên',
                    isSelected: _selectedTab == 'students',
                    onTap: () => setState(() => _selectedTab = 'students'),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Gia sư',
                    isSelected: _selectedTab == 'tutors',
                    onTap: () => setState(() => _selectedTab = 'tutors'),
                  ),
                ),
              ],
            ),
          ),
          // Danh sách người dùng
          Expanded(
            child: _buildUsersList(admin.id),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(String adminId) {
    if (_selectedTab == 'students') {
      return _buildStudentsList(adminId);
    } else if (_selectedTab == 'tutors') {
      return _buildTutorsList(adminId);
    } else {
      // Hiển thị cả học viên và gia sư
      return ListView(
        children: [
          _SectionHeader(title: 'Học viên'),
          _buildStudentsList(adminId, shrinkWrap: true),
          _SectionHeader(title: 'Gia sư'),
          _buildTutorsList(adminId, shrinkWrap: true),
        ],
      );
    }
  }

  Widget _buildStudentsList(String adminId, {bool shrinkWrap = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreRefs.users()
          .where('role', isEqualTo: UserRole.student.name)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return shrinkWrap
              ? const SizedBox.shrink()
              : const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Lỗi: ${snapshot.error}'),
          );
        }

        final users = snapshot.data?.docs ?? [];
        if (users.isEmpty) {
          return shrinkWrap
              ? const SizedBox.shrink()
              : const Center(child: Text('Chưa có học viên nào'));
        }

        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final userId = userDoc.id;
            
            return _UserChatTile(
              userId: userId,
              userName: userData['name'] ?? 'Học viên',
              userAvatar: userData['avatarUrl'] ?? '',
              adminId: adminId,
              role: UserRole.student,
            );
          },
        );
      },
    );
  }

  Widget _buildTutorsList(String adminId, {bool shrinkWrap = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreRefs.tutors()
          .where('approved', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return shrinkWrap
              ? const SizedBox.shrink()
              : const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Lỗi: ${snapshot.error}'),
          );
        }

        final tutors = snapshot.data?.docs ?? [];
        if (tutors.isEmpty) {
          return shrinkWrap
              ? const SizedBox.shrink()
              : const Center(child: Text('Chưa có gia sư nào'));
        }

        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          itemCount: tutors.length,
          itemBuilder: (context, index) {
            final tutorDoc = tutors[index];
            final tutorData = tutorDoc.data() as Map<String, dynamic>;
            final tutorId = tutorDoc.id;
            
            return _UserChatTile(
              userId: tutorId,
              userName: tutorData['name'] ?? 'Gia sư',
              userAvatar: tutorData['avatarUrl'] ?? '',
              adminId: adminId,
              role: UserRole.tutor,
            );
          },
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _UserChatTile extends StatelessWidget {
  final String userId;
  final String userName;
  final String userAvatar;
  final String adminId;
  final UserRole role;

  const _UserChatTile({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.adminId,
    required this.role,
  });

  String _getRoomId() {
    // Format: admin-{userId} hoặc {adminId}-{userId}
    // Sắp xếp để đảm bảo room ID nhất quán
    final ids = [adminId, userId]..sort();
    return '${ids[0]}-${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final roomId = _getRoomId();
    
    return StreamBuilder<ChatMessage?>(
      stream: ChatService().streamLastMessage(roomId),
      builder: (context, messageSnap) {
        final lastMessage = messageSnap.data;
        final hasUnread = lastMessage != null && 
            !lastMessage.readBy.contains(adminId) &&
            lastMessage.senderId != adminId;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: userAvatar.isNotEmpty
                  ? NetworkImage(userAvatar)
                  : null,
              child: userAvatar.isEmpty
                  ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?')
                  : null,
            ),
            title: Row(
              children: [
                Expanded(child: Text(userName)),
                if (role == UserRole.tutor)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Gia sư',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Học viên',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: lastMessage != null
                ? Text(
                    lastMessage.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : const Text('Chưa có tin nhắn'),
            trailing: hasUnread
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    roomId: roomId,
                    title: userName,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

