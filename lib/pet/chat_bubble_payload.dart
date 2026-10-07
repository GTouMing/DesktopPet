import '../petpack/chat_bubble_content.dart';

/// 当前正在显示的气泡：内容 + 序号。
///
/// [seq] 每次显示自增：即使重复显示同一条内容（例如连按同一个 API），宿主也能据此
/// 判定"换了一条"并重播入场动画。
class ChatBubblePayload {
  const ChatBubblePayload({required this.content, required this.seq});

  final ChatBubbleContent content;
  final int seq;
}
