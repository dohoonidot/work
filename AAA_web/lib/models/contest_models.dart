class ContestSubmission {
  final int contestId;
  final String title;
  final String summary;
  final int votes;
  final int viewCount;
  final int likeCount;
  final bool isCanceled;

  ContestSubmission({
    required this.contestId,
    required this.title,
    required this.summary,
    required this.votes,
    required this.viewCount,
    required this.likeCount,
    required this.isCanceled,
  });

  factory ContestSubmission.fromJson(Map<String, dynamic> json) {
    return ContestSubmission(
      contestId: json['contest_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      votes: json['votes'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      isCanceled: (json['is_canceled'] as int? ?? 0) == 1,
    );
  }
}
