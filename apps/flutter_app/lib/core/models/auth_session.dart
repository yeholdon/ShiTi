class AuthSession {
  const AuthSession({
    required this.userId,
    required this.username,
    required this.accessLevel,
    required this.accessToken,
    required this.tokenPreview,
  });

  final String userId;
  final String username;
  final String accessLevel;
  final String accessToken;
  final String tokenPreview;
}
