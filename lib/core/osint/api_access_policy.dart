/// User-provided API credentials are supported only after an independent
/// provider review confirms that a key is available without payment.
/// Do not infer this from a free web site or from a provider's API existence.
enum ApiAccessClass { publicNoKey, verifiedFreeKey, paidOrUnverified }

class ApiAccessPolicy {
  const ApiAccessPolicy({
    required this.id,
    required this.name,
    required this.access,
    this.registrationUri,
  });

  final String id;
  final String name;
  final ApiAccessClass access;
  final Uri? registrationUri;

  /// Only approved free-key sources may request credentials. Actual key
  /// persistence requires OS-secure storage (not plaintext app settings).
  bool get allowsUserKey =>
      access == ApiAccessClass.verifiedFreeKey &&
      registrationUri != null &&
      registrationUri!.scheme == 'https' &&
      registrationUri!.hasAuthority;
}

class OfficialAirspaceApis {
  static final bazlUas = ApiAccessPolicy(
    id: 'bazl-uas',
    name: 'BAZL UAS GeoJSON',
    access: ApiAccessClass.publicNoKey,
  );
  static final skyguideNotam = ApiAccessPolicy(
    id: 'skyguide-notam',
    name: 'Skyguide NOTAM database',
    access: ApiAccessClass.paidOrUnverified,
  );
  static final skyguideDabs = ApiAccessPolicy(
    id: 'skyguide-dabs',
    name: 'Skyguide DABS',
    access: ApiAccessClass.paidOrUnverified,
  );
  static final sources = [bazlUas, skyguideNotam, skyguideDabs];
}
