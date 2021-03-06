import Authentication
import FluentProvider
import Forms
import JWT
import JWTProvider
import SMTP

/// A lightweight User implementation to get started with JWTKeychain.
public final class User: Model, SoftDeletable, Timestampable {

    public struct Keys {
        public static let email = "email"
        public static let name = "name"
        internal static let hashedPassword = "hashedPassword"
        internal static let passwordVersion = "passwordVersion"

        internal static let password = "password"
        internal static let passwordRepeat = "passwordRepeat"
        internal static let oldPassword = "oldPassword"
    }

    public var email: String
    public var name: String
    public var hashedPassword: String?
    public var passwordVersion: Int = 0

    public let storage = Storage()

    public init(
        email: String,
        name: String,
        hashedPassword: String?,
        passwordVersion: Int = 0
    ) {
        self.email = email
        self.name = name
        self.hashedPassword = hashedPassword
        self.passwordVersion = passwordVersion
    }
}

// MARK: EmailAddressRepresentable

extension User: EmailAddressRepresentable {
    public var emailAddress: EmailAddress {
        return EmailAddress(name: name, address: email)
    }
}

// MARK: JSONRepresentable

extension User: JSONRepresentable {
    public func makeJSON() throws -> JSON {
        var json = JSON()

        try json.set(User.idKey, id)
        try json.set(Keys.email, email)
        try json.set(Keys.name, name)
        try json.set(Keys.passwordVersion, passwordVersion)

        return json
    }
}

// MARK: JWTKeychainAuthenticatable

extension User: JWTKeychainAuthenticatable {
    public static func make(request: Request) throws -> User {
        let form: UserForm = try request.createForm()

        try form.validate(inValidationMode: .all)

        // force unwrapping is ok because form was validated
        let email = form.email!
        let name = form.name!
        let password = form.password!

        guard try makeQuery()
            .filter(Keys.email.string, email)
            .first() == nil
        else {
            throw JWTKeychainUserError.userWithGivenEmailAlreadyExists
        }

        return User(
            email: email,
            name: name,
            hashedPassword: try hash(password: password)
        )
    }
}

// MARK: NodeRepresentable

extension User: NodeRepresentable {
    public func makeNode(in context: Context?) throws -> Node {
        var node = Node([:])

        try node.set(User.idKey, id)
        try node.set(Keys.email, email)
        try node.set(Keys.name, name)
        try node.set(Keys.passwordVersion, passwordVersion)

        return node
    }
}

// MARK: PasswordAuthenticatable

extension User: PasswordAuthenticatable {
    public static var passwordVerifier: PasswordVerifier? {
        return bCryptHasher
    }
}

// MARK: PasswordResettable

extension User: PasswordResettable {
    public static func extractPasswordResetInfo(
        from request: Request
    ) throws -> PasswordResetInfoType {
        return try request.createForm() as PasswordResetForm
    }
}

// MARK: PasswordUpdateable

extension User: PasswordUpdateable {
    public func updatePassword(to newPassword: String) throws {
        try update(password: newPassword)
    }
}

// MARK: PayloadAuthenticatable

extension User: PayloadAuthenticatable {
    public struct UserIdentifier: JSONInitializable {
        let id: Identifier

        public init(json: JSON) throws {
            id = Identifier(try json.get(SubjectClaim.name) as Node)
        }
    }

    public typealias PayloadType = UserIdentifier

    public static func authenticate(
        _ payload: PayloadType
    ) throws -> User {
        guard let user = try User.find(payload.id) else {
            throw Abort.notFound
        }

        return user
    }
}

// MARK: Preparation

extension User: Preparation {
    public static func prepare(_ database: Database) throws {
        try database.create(self) {
            $0.id()
            $0.string(Keys.email, unique: true)
            $0.string(Keys.name)
            $0.string(Keys.hashedPassword, optional: true)
            $0.int(Keys.passwordVersion)
        }
    }

    public static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

// MARK: RequestUpdateable

extension User: RequestUpdateable {
    public func update(request: Request) throws {
        let form: UserForm = try request.createForm()

        try form.validate(inValidationMode: .nonNil)

        // require old password as confirmation when updating email or password
        if form.email != nil || form.password != nil {
            try verifyOldPassword(form: form)
        }

        // when updating email address, check for uniqueness
        if
            let email = form.email,
            email != self.email,
            let id = id?.string
        {
            let existingUserWithSameEmail = try makeQuery()
                .filter(Keys.email, email)
                .filter(idKey, .notEquals, id)
                .first()

            if existingUserWithSameEmail != nil {
                throw JWTKeychainUserError.userWithGivenEmailAlreadyExists
            }
        }

        try update(
            email: form.email,
            name: form.name,
            password: extractNewPassword(form: form)
        )
    }

    private func extractNewPassword(form: UserForm) throws -> String? {
        guard let password = form.password else {
            return nil
        }

        guard password == form.passwordRepeat else {
            throw JWTKeychainUserError.passwordsDoNotMatch
        }

        return password
    }

    private func verifyOldPassword(form: UserForm) throws {
        guard
            let oldPassword = form.oldPassword,
            let hashedPassword = hashedPassword,
            let passwordVerifier = User.passwordVerifier,
            try passwordVerifier.verify(
                password: oldPassword.makeBytes(),
                matches: hashedPassword.makeBytes()
            )
            else {
                throw JWTKeychainUserError.missingOldPassword
        }
    }
}

// MARK: RowRepresentable

extension User: RowRepresentable {
    public convenience init(row: Row) throws {
        try self.init(
            email: row.get(Keys.email),
            name: row.get(Keys.name),
            hashedPassword: row.get(Keys.hashedPassword),
            passwordVersion: row.get(Keys.passwordVersion)
        )
    }

    public func makeRow() throws -> Row {
        var row = Row()

        try row.set(Keys.email, email)
        try row.set(Keys.name, name)
        try row.set(Keys.hashedPassword, hashedPassword)
        try row.set(Keys.passwordVersion, passwordVersion)

        return row
    }
}

// MARK: Helper

extension User {
    fileprivate func update(
        email: String? = nil,
        name: String? = nil,
        password: String? = nil
    ) throws {
        if let email = email {
            self.email = email
        }

        if let name = name {
            self.name = name
        }

        if let password = password {
            self.hashedPassword = try User.hash(password: password)
            self.passwordVersion += 1
        }
    }

    fileprivate static func hash(password: String) throws -> String {
        return try bCryptHasher
            .make(password)
            .makeString()
    }
}
