class AppConfig {
  static const environmentLabel =
      String.fromEnvironment('SHITI_ENV_LABEL', defaultValue: 'WORKSPACE');
  static const apiBaseUrl =
      String.fromEnvironment('SHITI_API_BASE_URL', defaultValue: 'http://localhost:3000');
  static const useMockData =
      bool.fromEnvironment('SHITI_USE_MOCK_DATA', defaultValue: true);

  static String get dataModeLabel => useMockData ? 'MOCK' : 'REMOTE';
}
