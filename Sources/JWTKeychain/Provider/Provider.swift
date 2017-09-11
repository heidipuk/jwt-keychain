import Authentication
import Core
import Fluent
import JWT
import JWTProvider
import Leaf
import LeafProvider
import SMTP
import Vapor

public typealias JWTKeychainUser =
    EmailAddressRepresentable &
    Entity &
    JSONRepresentable &
    JWTKeychainAuthenticatable &
    NodeRepresentable &
    PasswordAuthenticatable &
    PasswordUpdateable &
    PayloadAuthenticatable &
    Preparation

// TODO: make cost configurable or use global bcrypt?
private let _hasher = BCryptHasher()

/// Provider that sets up:
/// - User API routes
/// - Frontend password reset routes
/// - Password Reset Mailer
public final class Provider<U: JWTKeychainUser> {

    public static var hasher: BCryptHasher {
        return _hasher
    }

    let settings: Settings

    fileprivate let apiDelegate: APIUserControllerDelegateType
    fileprivate let frontendDelegate: FrontendUserControllerDelegateType

    public init(
        apiDelegate: APIUserControllerDelegateType,
        frontendDelegate: FrontendUserControllerDelegateType,
        settings: Settings
    ) {
        self.apiDelegate = apiDelegate
        self.frontendDelegate = frontendDelegate
        self.settings = settings
    }
}

// MARK: Vapor.Provider

extension Provider: Vapor.Provider {
    public static var repositoryName: String {
        return "jwt-keychain-provider"
    }

    public func boot(_ config: Config) throws {
        config.preparations += [U.self]
        
        try config.addProvider(JWTProvider.Provider.self)
    }

    public func boot(_ drop: Droplet) throws {
        try registerRoutes(drop)
    }

    public func beforeRun(_ drop: Droplet) throws {
        if let stem = drop.stem {
            registerTags(stem)
        }
    }
}

// MARK: Configinitializable

extension Provider: ConfigInitializable {
    public convenience init(config: Config) throws {
        try self.init(
            apiDelegate: APIUserControllerDelegate<U>(),
            frontendDelegate: FrontendUserControllerDelegate<U>(),
            settings: Settings(config: config)
        )
    }
}

// MARK: Helper

extension Provider {
    fileprivate func registerRoutes(_ drop: Droplet) throws {
        let signerMap = try drop.assertSigners()
        let viewRenderer = drop.view
        
        let frontendRoutes = try createFrontendRoutes(
            signerMap: signerMap,
            viewRenderer: viewRenderer
        )

        let mailer = try drop.config.resolveMail()
        let passwordResetMailer = PasswordResetMailer(
            settings: settings,
            mailer: mailer,
            viewRenderer: viewRenderer)
        let userRoutes = try createUserRoutes(
            passwordResetMailer: passwordResetMailer,
            signerMap: signerMap
        )
        
        try drop.collection(frontendRoutes)
        try drop.collection(userRoutes)
    }
    
    fileprivate func registerTags(_ stem: Stem) {
        stem.register(ErrorListTag())
        stem.register(ValueForFieldTag())
    }
    
    fileprivate func createFrontendRoutes(
        signerMap: SignerMap,
        viewRenderer: ViewRenderer
    ) throws -> FrontendResetPasswordRoutes {
        let kid = settings.resetPassword.kid
        guard let signer = signerMap[kid] else {
            throw JWTKeychainError.missingSigner(kid: kid)
        }
        
        let controller = FrontendUserController(
            signer: signer,
            viewRenderer: viewRenderer,
            delegate: frontendDelegate
        )
        
        return FrontendResetPasswordRoutes(
            controller: controller
        )
    }
    
    fileprivate func createUserRoutes(
        passwordResetMailer: PasswordResetMailerType,
        signerMap: SignerMap
    ) throws -> APIUserRoutes {
        let tokenGenerators = try TokenGenerators(
            settings: settings,
            signerMap: signerMap
        )
        
        let controller = APIUserController(
            delegate: apiDelegate,
            passwordResetMailer: passwordResetMailer,
            tokenGenerators: tokenGenerators
        )
        
        let apiAccessMiddleware = PayloadAuthenticationMiddleware<U>(
            tokenGenerators.apiAccess,
            [ExpirationTimeClaim()]
        )

        // Expose API Access Middleware for public usage
        Middlewares.secured.append(apiAccessMiddleware)

        let refreshMiddleware: Middleware?

        if let refresh = tokenGenerators.refresh {
            refreshMiddleware = PayloadAuthenticationMiddleware<U>(
                refresh,
                [ExpirationTimeClaim()]
            )
        } else {
            refreshMiddleware = nil
        }
        
        return APIUserRoutes(
            apiAccessMiddleware: apiAccessMiddleware,
            refreshMiddleware: refreshMiddleware,
            controller: controller
        )
    }
}

enum JWTKeychainError: Error {
    case missingSigner(kid: String)
}
