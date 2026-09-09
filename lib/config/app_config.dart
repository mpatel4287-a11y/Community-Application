class AppConfig {
  /// The base URL for the web version of the community app.
  static const String webBaseUrl = 'https://com-app-project.web.app';

  /// The domain host for deep linking.
  static const String deepLinkHost = 'com-app-project.web.app';

  /// The scheme for deep linking (usually https).
  static const String deepLinkScheme = 'https';
  
  /// Helper to generate a member profile URL
  static String getMemberUrl(
    String memberId, {
    String? familyDocId,
    String? mid,
    String? fullName,
    String? surname,
    String? familyName,
    String? phone,
    String? bloodGroup,
    String? birthDate,
    String? photoUrl,
    String? nativeHome,
    String? education,
    String? address,
    String? fatherName,
    String? motherName,
  }) {
    final Map<String, String> queryParams = {
      'id': memberId,
    };
    if (familyDocId != null && familyDocId.isNotEmpty) queryParams['family'] = familyDocId;
    if (mid != null && mid.isNotEmpty) queryParams['mid'] = mid;
    if (fullName != null && fullName.isNotEmpty) queryParams['name'] = fullName;
    if (surname != null && surname.isNotEmpty) queryParams['sur'] = surname;
    if (familyName != null && familyName.isNotEmpty) queryParams['fn'] = familyName;
    if (phone != null && phone.isNotEmpty) queryParams['ph'] = phone;
    if (bloodGroup != null && bloodGroup.isNotEmpty) queryParams['bg'] = bloodGroup;
    if (birthDate != null && birthDate.isNotEmpty) queryParams['dob'] = birthDate;
    if (photoUrl != null && photoUrl.isNotEmpty) queryParams['img'] = photoUrl;
    if (nativeHome != null && nativeHome.isNotEmpty) queryParams['native'] = nativeHome;
    if (education != null && education.isNotEmpty) queryParams['edu'] = education;
    if (address != null && address.isNotEmpty) queryParams['addr'] = address;
    if (fatherName != null && fatherName.isNotEmpty) queryParams['fath'] = fatherName;
    if (motherName != null && motherName.isNotEmpty) queryParams['moth'] = motherName;

    final Uri uri = Uri.parse('$webBaseUrl/member').replace(queryParameters: queryParams);
    return uri.toString();
  }
}
