/// The fields of the login and register forms.
enum AuthField {
  email,
  password,
  fullName,
  phone,
  shopName,
  shopType,
  shopPhone,
  shopGovernorate,
  shopAddress,
}

/// Why a field was rejected before anything was sent.
enum AuthFieldIssue { required, invalidEmail, weakPassword, tooLong }
