import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatConvoBubble extends StatefulWidget {
  final String message;
  final bool isCurrentUser;
  final Timestamp timestamp;
  final String profilePicture; // Add profile picture
  final Function()? onEdit;
  final Function()? onDelete;
  final Function(String emoji)? onReact;

  const ChatConvoBubble({
    super.key,
    required this.isCurrentUser,
    required this.message,
    required this.timestamp,
    required this.profilePicture, // Add profile picture
    this.onEdit,
    this.onDelete,
    this.onReact,
  });

  @override
  _ChatConvoBubbleState createState() => _ChatConvoBubbleState();
}

class _ChatConvoBubbleState extends State<ChatConvoBubble> {
  bool _showTimestamp = false;

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                widget.onEdit?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions),
              title: const Text('React'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmojiPicker(
          onEmojiSelected: (category, emoji) {
            widget.onReact?.call(emoji.emoji); // Use `emoji.character`
            Navigator.pop(context);
          },
        );
      },
    );
  }

 @override
Widget build(BuildContext context) {
  bool isDarkMode =
      Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
  final DateTime messageDate = widget.timestamp.toDate();
  final DateTime now = DateTime.now();
  final bool isThisWeek = now.difference(messageDate).inDays <= 7;

  String formattedTime = isThisWeek
      ? DateFormat('E hh:mm a').format(messageDate) // Day and time for this week
      : DateFormat('MMM d, yyyy hh:mm a').format(messageDate); // Full date for older messages

  return Row(
    mainAxisAlignment: widget.isCurrentUser
        ? MainAxisAlignment.end
        : MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!widget.isCurrentUser)
        CircleAvatar(
          backgroundImage: NetworkImage(widget.profilePicture),
        ),
      const SizedBox(width: 8),
      Flexible(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showTimestamp = !_showTimestamp;
            });
          },
          onLongPress: () => _showOptionsMenu(context),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: widget.isCurrentUser
                  ? const Color(0xFF6750A4)
                  : (isDarkMode
                      ? const Color.fromARGB(255, 65, 63, 71)
                      : const Color.fromARGB(255, 145, 141, 141)),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.isCurrentUser
                        ? Colors.white
                        : (isDarkMode ? Colors.white : Colors.black),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (_showTimestamp)
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: widget.isCurrentUser
                          ? Colors.white70
                          : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
}