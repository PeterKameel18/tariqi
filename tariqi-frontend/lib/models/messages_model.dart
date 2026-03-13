class MessagesModel {
  String? sender;
  String? senderType;
  String? content;
  String? timestamp;
  String? sId;

  MessagesModel(
      {this.sender, this.senderType, this.content, this.timestamp, this.sId});

  MessagesModel.fromJson(Map<String, dynamic> json) {
    sender = json['sender'];
    senderType = json['senderType'];
    content = json['content'];
    timestamp = json['timestamp'];
    sId = json['_id'];
  }
}
