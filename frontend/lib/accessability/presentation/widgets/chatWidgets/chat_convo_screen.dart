import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_convo_bubble.dart';
import 'package:AccessAbility/accessability/presentation/widgets/reusableWidgets/custom_text_field.dart';
import 'package:intl/intl.dart';

class ChatConvoScreen extends StatefulWidget {
  const ChatConvoScreen({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
  });

  final String receiverEmail;
  final String receiverID;

  @override
  State<ChatConvoScreen> createState() => _ChatConvoScreenState();
}

class _ChatConvoScreenState extends State<ChatConvoScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ChatService chatService = ChatService();
  final AuthService authService = AuthService();
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  FocusNode focusNode = FocusNode();
  bool _isRequestPending = true;

  @override
  void initState() {
    super.initState();
    _checkChatRequest();

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());
      }
    });

    // Use addPostFrameCallback instead of Future.delayed
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());
  }

  Future<void> _checkChatRequest() async {
    final senderID = authService.getCurrentUser()!.uid;
    final hasRequest = await chatService.hasChatRequest(senderID, widget.receiverID);
    setState(() {
      _isRequestPending = hasRequest;
    });
  }

  Future<void> _acceptChatRequest() async {
    await chatService.acceptChatRequest(widget.receiverID);
    setState(() {
      _isRequestPending = false;
    });
  }

  void sendMessage() async {
    if (messageController.text.isNotEmpty) {
      await chatService.sendMessage(widget.receiverID, messageController.text);
      messageController.clear();
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void scrollDown() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

@override
Widget build(BuildContext context) {
  final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

  print('Received arguments in ChatConvoScreen: $args'); // Debugging

  if (args == null) {
    return const Scaffold(
      body: Center(
        child: Text('Error: Missing arguments for ChatConvoScreen'),
      ),
    );
  }

  final String receiverEmail = args['receiverEmail'] as String;
  final String receiverID = args['receiverID'] as String;
  final String receiverProfilePicture = args['receiverProfilePicture'] as String? ?? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba'; // Default image if none

  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(receiverProfilePicture),
          ),
          const SizedBox(width: 10),
          Text(receiverEmail),
        ],
      ),
    ),
    body: _isRequestPending
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have a pending chat request'),
                ElevatedButton(
                  onPressed: _acceptChatRequest,
                  child: const Text('Accept'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await chatService.rejectChatRequest(widget.receiverID);
                    Navigator.pop(context);
                  },
                  child: const Text('Reject'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildUserInput(),
            ],
          ),
  );
}


  Widget _buildMessageList() {
    String senderID = authService.getCurrentUser()!.uid;
    return StreamBuilder(
      stream: chatService.getMessages(widget.receiverID, senderID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Widget> messageWidgets = [];
        Timestamp? lastTimestamp;

        for (var doc in snapshot.data!.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          bool isCurrentUser = data['senderID'] == senderID;

          // Check if we need to add a timestamp divider
          if (lastTimestamp != null) {
            final currentTimestamp = data['timestamp'] as Timestamp;
            final difference = currentTimestamp
                .toDate()
                .difference(lastTimestamp.toDate())
                .inMinutes;

            if (difference >= 10) {
              messageWidgets.add(
                Column(
                  children: [
                    const Divider(),
                    Text(
                      DateFormat('hh:mm a').format(currentTimestamp.toDate()),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const Divider(),
                  ],
                ),
              );
            }
          }

          // Add the message item
          messageWidgets.add(_buildMessageItem(doc));
          lastTimestamp = data['timestamp'];
        }

        // Automatically scroll down when new messages are added
        if (snapshot.hasData && messageWidgets.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollDown();
          });
        }

        return ListView(
          controller: scrollController,
          children: messageWidgets,
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderID'] == authService.getCurrentUser()!.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Users')
          .doc(data['senderID'])
          .get(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (snapshot.hasError) {
          return const Text('Error loading user data');
        }

        // Handle case where user data is not found
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ChatConvoBubble(
            isCurrentUser: isCurrentUser,
            message: data['message'],
            timestamp: data['timestamp'],
            profilePicture: 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba', // Default image
          );
        }

        // Fetch and use the user's profile picture
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final profilePicture = userData['profilePicture'] ?? 'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba'; // Default image if none

        return ChatConvoBubble(
          isCurrentUser: isCurrentUser,
          message: data['message'],
          timestamp: data['timestamp'],
          profilePicture: profilePicture,
        );
      },
    );
  }

  Widget _buildUserInput() {
    return Row(
      children: [
        Expanded(
          child: CustomTextField(
            focusNode: focusNode,
            controller: messageController,
            hintText: 'Type a message...',
            obscureText: false,
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF6750A4),
            shape: BoxShape.circle,
          ),
          margin: const EdgeInsets.only(right: 25),
          child: IconButton(
            onPressed: sendMessage,
            icon: const Icon(Icons.arrow_upward),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}