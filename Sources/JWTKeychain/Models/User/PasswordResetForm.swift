import Forms
import JSON
import Sugar
import Validation

internal struct PasswordResetForm {
    fileprivate let emailField: FormField<String>
    fileprivate let passwordField: FormField<String>
    fileprivate let passwordRepeatField: FormField<String>

    internal init(
        email: String?,
        password: String?,
        passwordRepeat: String?
    ) {
        emailField = FormField(
            key: User.Keys.email,
            label: "Email",
            value: email,
            validator: OptionalValidator(
                errorOnNil: JWTKeychainUserError.missingEmail
            )
        )
        passwordField = FormField(
            key: User.Keys.password,
            label: "Password",
            value: password,
            validator: OptionalValidator(
                errorOnNil: JWTKeychainUserError.missingPassword
            ) {
                do {
                    try StrongPassword().validate($0)
                } catch {
                    throw JWTKeychainUserError.passwordTooWeak
                }
            }
        )
        passwordRepeatField = FormField(
            key: User.Keys.passwordRepeat,
            label: "Repeat Password",
            value: passwordRepeat) {
                if $0 != password {
                    throw JWTKeychainUserError.passwordsDoNotMatch
                }
        }
    }
}

// MARK: Form

extension PasswordResetForm: Form {
    var fields: [FieldsetEntryRepresentable & ValidationModeValidatable] {
        return [emailField, passwordField, passwordRepeatField]
    }
}

// MARK: JSONInitializable

extension PasswordResetForm: JSONInitializable {
    internal init(json: JSON) throws {
        try self.init(
            email: json.get(User.Keys.email),
            password: json.get(User.Keys.password),
            passwordRepeat: json.get(User.Keys.passwordRepeat)
        )
    }
}

// MARK: PasswordResetInfoType

extension PasswordResetForm: PasswordResetInfoType {
    internal var email: String? {
        return emailField.value
    }

    internal var password: String? {
        return passwordField.value
    }
}
